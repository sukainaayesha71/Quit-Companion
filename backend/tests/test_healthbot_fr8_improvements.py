"""FR8 Health-Bot improvements: topic-specific sources, the 2-second response
budget, curated fallback on slow/failed Gemini, and unchanged safety rules."""
from __future__ import annotations

import asyncio
import json
import time
from urllib.parse import urlparse

import httpx
import pytest
from fastapi.testclient import TestClient

from app.fake_firebase_identity import FakeFirebaseIdentityProvider
from app.healthbot import router as healthbot_router
from app.healthbot import service as healthbot
from app.healthbot import sources as hb_sources
from app.healthbot.review import content_digest
from app.healthbot.service import (
    EMERGENCY_RESPONSE_TEXT,
    KNOWLEDGE_BASE,
    UNMATCHED_FALLBACK_TEXT,
    AnswerType,
    HealthBotAnswer,
)

TOKEN = "fr8-token"
TRUSTED_DOMAINS = {"www.cdc.gov", "www.cancer.gov", "smokefree.gov", "www.nhs.uk"}


def _headers(identity: FakeFirebaseIdentityProvider) -> dict[str, str]:
    identity.valid_tokens[TOKEN] = "fr8-uid"
    return {"Authorization": f"Bearer {TOKEN}"}


def _post(client: TestClient, identity: FakeFirebaseIdentityProvider, query: str):
    return client.post("/healthbot/query", json={"query": query}, headers=_headers(identity))


# --- Source catalogue -------------------------------------------------------


def test_every_curated_topic_has_trusted_sources() -> None:
    topics = {topic for topic, _keywords, _text in KNOWLEDGE_BASE}
    assert set(hb_sources.TOPIC_SOURCES) == topics
    for topic, group in hb_sources.TOPIC_SOURCES.items():
        assert group, topic
        for source in group:
            parsed = urlparse(source.url)
            assert parsed.scheme == "https", source.url
            assert parsed.netloc in TRUSTED_DOMAINS, source.url
            assert source.title.strip()


@pytest.mark.parametrize(
    ("query", "expected"),
    [
        ("I have a terrible headache", hb_sources.SMOKEFREE_WITHDRAWAL),
        ("how do I avoid triggers at work", hb_sources.SMOKEFREE_TRIGGERS),
        ("I smoked again yesterday, I relapsed", hb_sources.SMOKEFREE_SETBACK),
        ("is secondhand smoke bad for my kids", hb_sources.CDC_SECONDHAND),
        ("I'm quitting vaping and feel awful", hb_sources.SMOKEFREE_VAPING_WITHDRAWAL),
        ("will food taste better soon", hb_sources.CDC_BENEFITS),
    ],
)
def test_sources_are_topic_specific(query: str, expected: hb_sources.TrustedSource) -> None:
    assert expected in hb_sources.sources_for_query(query)


def test_in_scope_question_without_a_curated_topic_gets_general_sources() -> None:
    assert hb_sources.sources_for_query("tips for my first week") == hb_sources.GENERAL_SOURCES


def test_router_returns_topic_sources_with_titles(client, firebase_identity, monkeypatch) -> None:
    async def generate(query: str, **_: object) -> HealthBotAnswer:
        return HealthBotAnswer(AnswerType.MATCHED, "Tailored advice about secondhand smoke.")

    monkeypatch.setattr(healthbot_router, "answer_query_with_gemini", generate)
    body = _post(client, firebase_identity, "secondhand smoke around kids").json()

    assert body["source_urls"] == [hb_sources.CDC_SECONDHAND.url]
    assert body["sources"] == [
        {"title": hb_sources.CDC_SECONDHAND.title, "url": hb_sources.CDC_SECONDHAND.url}
    ]


@pytest.mark.parametrize(
    "query",
    ["I feel suicidal", "chest pain and my heart is racing", "severe anxiety right now"],
)
def test_emergency_answers_carry_no_sources_and_keep_fixed_text(client, firebase_identity, query) -> None:
    body = _post(client, firebase_identity, query).json()
    assert body["answer_type"] == "emergency"
    assert body["response_text"] == EMERGENCY_RESPONSE_TEXT
    assert body["sources"] == [] and body["source_urls"] == []


def test_medication_refusal_carries_no_sources(client, firebase_identity, monkeypatch) -> None:
    from app.config import settings

    monkeypatch.setattr(settings, "gemini_api_key", "server-key")
    body = _post(client, firebase_identity, "what dosage of varenicline for a headache").json()
    assert body["answer_type"] == "unmatched"
    assert "cannot recommend medications" in body["response_text"]
    assert body["sources"] == []


def test_unmatched_fallback_carries_no_sources(client, firebase_identity, monkeypatch) -> None:
    from app.config import settings

    monkeypatch.setattr(settings, "gemini_api_key", None)
    body = _post(client, firebase_identity, "what time is it").json()
    assert body["answer_type"] == "unmatched"
    assert UNMATCHED_FALLBACK_TEXT in body["response_text"]
    assert body["sources"] == []


@pytest.mark.asyncio
async def test_gemini_grounding_cites_the_topic_sources(monkeypatch) -> None:
    captured: dict[str, object] = {}

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict[str, object]:
            text = json.dumps({"answer_type": "matched", "response_text": "ok"})
            return {"candidates": [{"content": {"parts": [{"text": text}]}}]}

    class FakeAsyncClient:
        def __init__(self, timeout: float) -> None:
            captured["timeout"] = timeout

        async def __aenter__(self) -> "FakeAsyncClient":
            return self

        async def __aexit__(self, *args: object) -> None:
            return None

        async def post(self, url: str, *, headers: dict[str, str], json: dict[str, object]) -> FakeResponse:
            captured["body"] = json
            return FakeResponse()

    monkeypatch.setattr(healthbot.httpx, "AsyncClient", FakeAsyncClient)
    await healthbot._request_gemini_answer(
        "is secondhand smoke harmful", api_key="k", model="m", timeout_seconds=1.25
    )

    system_text = captured["body"]["systemInstruction"]["parts"][0]["text"]  # type: ignore[index]
    assert hb_sources.CDC_SECONDHAND.url in system_text
    assert hb_sources.SMOKEFREE_VAPING_WITHDRAWAL.url not in system_text
    assert captured["timeout"] == 1.25


def test_review_digest_covers_sources(monkeypatch) -> None:
    before = content_digest()
    monkeypatch.setitem(
        hb_sources.TOPIC_SOURCES,
        "headaches",
        (hb_sources.TrustedSource("changed", "https://www.cdc.gov/changed"),),
    )
    assert content_digest() != before


# --- 2-second budget and curated fallback ----------------------------------


@pytest.mark.asyncio
async def test_slow_gemini_is_abandoned_within_budget_for_curated_answer(monkeypatch) -> None:
    async def hang(*_: object, **__: object) -> HealthBotAnswer:
        await asyncio.sleep(10)
        raise AssertionError("should have been cancelled")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", hang)
    started = time.perf_counter()
    answer = await healthbot.answer_query_with_gemini(
        "I can't sleep at night", api_key="k", timeout_seconds=0.2
    )
    elapsed = time.perf_counter() - started

    assert elapsed < 0.6
    assert answer.type == AnswerType.MATCHED
    # Clean curated text (no technical prefix), honestly labelled.
    assert answer.response_text == healthbot.answer_query("I can't sleep at night").response_text
    assert answer.source == healthbot.AnswerSource.CURATED
    assert answer.fallback_reason == healthbot.FallbackReason.TIMEOUT


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "failure",
    [
        httpx.HTTPStatusError(
            "boom",
            request=httpx.Request("POST", "https://x"),
            response=httpx.Response(503, request=httpx.Request("POST", "https://x")),
        ),
        httpx.ConnectError("offline"),
        ValueError("invalid shape"),
        KeyError("candidates"),
    ],
)
async def test_gemini_failures_return_labeled_curated_answer(monkeypatch, failure: Exception) -> None:
    async def fail(*_: object, **__: object) -> HealthBotAnswer:
        raise failure

    monkeypatch.setattr(healthbot, "_request_gemini_answer", fail)
    answer = await healthbot.answer_query_with_gemini("I have a headache", api_key="k")
    assert answer.type == AnswerType.MATCHED
    assert answer.response_text == healthbot.answer_query("I have a headache").response_text
    assert answer.source == healthbot.AnswerSource.CURATED
    assert answer.fallback_reason == healthbot.FallbackReason.UNAVAILABLE


@pytest.mark.asyncio
async def test_crisis_detection_never_waits_for_gemini(monkeypatch) -> None:
    async def must_not_run(*_: object, **__: object) -> HealthBotAnswer:
        raise AssertionError("emergency must short-circuit before Gemini")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", must_not_run)
    for query in ["I want to end my life", "I can't breathe", "I might hurt myself"]:
        answer = await healthbot.answer_query_with_gemini(query, api_key="k")
        assert answer == HealthBotAnswer(AnswerType.EMERGENCY, EMERGENCY_RESPONSE_TEXT,
                                         source=healthbot.AnswerSource.SAFETY)


@pytest.mark.asyncio
async def test_generated_dosage_advice_is_still_blocked(monkeypatch) -> None:
    async def unsafe(*_: object, **__: object) -> HealthBotAnswer:
        return HealthBotAnswer(AnswerType.MATCHED, "You should take 2 mg every hour.")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", unsafe)
    answer = await healthbot.answer_query_with_gemini("cravings are bad", api_key="k")
    assert answer.type == AnswerType.UNMATCHED
    assert "cannot recommend medications" in answer.response_text


def test_router_passes_configured_budget(client, firebase_identity, monkeypatch) -> None:
    from app.config import settings

    seen: dict[str, object] = {}

    async def generate(query: str, **kwargs: object) -> HealthBotAnswer:
        seen.update(kwargs)
        return HealthBotAnswer(AnswerType.MATCHED, "ok")

    monkeypatch.setattr(settings, "healthbot_gemini_timeout_seconds", 1.1)
    monkeypatch.setattr(healthbot_router, "answer_query_with_gemini", generate)
    _post(client, firebase_identity, "headache")
    assert seen["timeout_seconds"] == 1.1


def test_end_to_end_response_stays_under_two_seconds_when_gemini_hangs(
    client, firebase_identity, monkeypatch
) -> None:
    """Measured in-process (no network): auth + routing + budget + fallback.

    The production budget is 10 s (Gemini needs 2-9 s for a conversational
    reply); this checks the mechanism with the original FR8 1.5 s budget.
    """
    from app.config import settings

    async def hang(*_: object, **__: object) -> HealthBotAnswer:
        await asyncio.sleep(30)
        raise AssertionError("unreachable")

    monkeypatch.setattr(settings, "healthbot_gemini_timeout_seconds", 1.5)
    monkeypatch.setattr(settings, "gemini_api_key", "server-key")
    monkeypatch.setattr(healthbot, "_request_gemini_answer", hang)
    started = time.perf_counter()
    response = _post(client, firebase_identity, "I feel irritable all day")
    elapsed = time.perf_counter() - started

    assert response.status_code == 200
    assert elapsed < 2.0, f"took {elapsed:.2f}s"
    body = response.json()
    assert "took too long" not in body["response_text"]
    assert body["answer_source"] == "curated"
    assert body["fallback_reason"] == "timeout"
    assert body["sources"], "curated fallback for a known topic still cites sources"

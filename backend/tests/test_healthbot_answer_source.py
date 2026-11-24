"""Health-Bot answer source and clean fallbacks (2026-11-23 phone-test fix).

A curated fallback used to start with a technical label ("The AI assistant
took too long to reply. General guidance: ..."). The text is now clean, and
`answer_source` / `fallback_reason` tell the app how to label it honestly,
so curated or rule-based text is never presented as AI-generated.
"""
from __future__ import annotations

import asyncio
import inspect

import httpx
import pytest
from fastapi.testclient import TestClient

from app.fake_firebase_identity import FakeFirebaseIdentityProvider
from app.healthbot import service as healthbot
from app.healthbot.service import (
    EMERGENCY_RESPONSE_TEXT,
    UNMATCHED_FALLBACK_TEXT,
    AnswerSource,
    AnswerType,
    FallbackReason,
    HealthBotAnswer,
)

TOKEN = "answer-source-token"
TECHNICAL_LABELS = ("took too long", "AI responses are unavailable", "General guidance:")


@pytest.fixture
def post(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider, monkeypatch):
    from app.config import settings

    firebase_identity.valid_tokens[TOKEN] = "u1"
    monkeypatch.setattr(settings, "gemini_api_key", "server-key")
    monkeypatch.setattr(settings, "require_clinical_review", False)
    monkeypatch.setattr(settings, "healthbot_gemini_timeout_seconds", 0.2)

    def _post(query: str):
        response = client.post("/healthbot/query", json={"query": query},
                               headers={"Authorization": f"Bearer {TOKEN}"})
        assert response.status_code == 200, response.text
        return response.json()

    return _post


def _gemini_returns(monkeypatch, text: str, answer_type: AnswerType = AnswerType.MATCHED) -> None:
    async def ok(*_: object, **__: object) -> HealthBotAnswer:
        return HealthBotAnswer(answer_type, text, source=AnswerSource.AI)

    monkeypatch.setattr(healthbot, "_request_gemini_answer", ok)


def _gemini_hangs(monkeypatch) -> None:
    async def hang(*_: object, **__: object) -> HealthBotAnswer:
        await asyncio.sleep(10)
        raise AssertionError("should have been cancelled")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", hang)


def _gemini_fails(monkeypatch, error: Exception) -> None:
    async def fail(*_: object, **__: object) -> HealthBotAnswer:
        raise error

    monkeypatch.setattr(healthbot, "_request_gemini_answer", fail)


def test_gemini_answer_is_labelled_ai_with_sources(post, monkeypatch) -> None:
    _gemini_returns(monkeypatch, "Headaches often ease within a couple of weeks of quitting.")
    body = post("I have a headache")
    assert body["answer_source"] == "ai"
    assert body["fallback_reason"] is None
    assert body["response_text"] == "Headaches often ease within a couple of weeks of quitting."
    assert body["sources"]


def test_timeout_returns_clean_curated_text_labelled_timeout(post, monkeypatch) -> None:
    _gemini_hangs(monkeypatch)
    body = post("I have a headache")
    assert body["answer_type"] == "matched"
    assert body["answer_source"] == "curated"
    assert body["fallback_reason"] == "timeout"
    assert body["response_text"] == healthbot.answer_query("I have a headache").response_text
    assert not any(label in body["response_text"] for label in TECHNICAL_LABELS)
    assert body["sources"], "curated fallback keeps its reviewed sources"


@pytest.mark.parametrize("error", [
    httpx.ConnectError("offline"),
    httpx.HTTPStatusError("boom", request=httpx.Request("POST", "https://x"),
                          response=httpx.Response(503, request=httpx.Request("POST", "https://x"))),
    ValueError("invalid shape"),
])
def test_gemini_failure_returns_clean_curated_text_labelled_unavailable(post, monkeypatch, error) -> None:
    _gemini_fails(monkeypatch, error)
    body = post("I can't sleep at night")
    assert body["answer_source"] == "curated"
    assert body["fallback_reason"] == "unavailable"
    assert not any(label in body["response_text"] for label in TECHNICAL_LABELS)
    assert body["sources"]


def test_unmatched_question_on_timeout_is_curated_unmatched_without_label(post, monkeypatch) -> None:
    """The app shows its 'couldn't get an answer' message + Try again for this."""
    _gemini_hangs(monkeypatch)
    body = post("what is the capital of peru")
    assert body["answer_type"] == "unmatched"
    assert body["answer_source"] == "curated"
    assert body["fallback_reason"] == "timeout"
    assert body["response_text"] == UNMATCHED_FALLBACK_TEXT


def test_emergency_is_safety_and_never_calls_gemini(post, monkeypatch) -> None:
    _gemini_fails(monkeypatch, AssertionError("emergency must not reach Gemini"))
    body = post("I want to end my life")
    assert body["answer_type"] == "emergency"
    assert body["answer_source"] == "safety"
    assert body["fallback_reason"] is None
    assert body["response_text"] == EMERGENCY_RESPONSE_TEXT
    assert body["sources"] == []


def test_medication_question_is_safety_refusal(post, monkeypatch) -> None:
    _gemini_fails(monkeypatch, AssertionError("medication guard must run before Gemini"))
    body = post("what dosage of varenicline should I take")
    assert body["answer_source"] == "safety"
    assert "clinician or pharmacist" in body["response_text"]


def test_medication_advice_in_gemini_output_is_replaced_and_labelled_safety(post, monkeypatch) -> None:
    _gemini_returns(monkeypatch, "You should take 2 mg every hour.")
    body = post("how do I cope with cravings")
    assert body["answer_source"] == "safety"
    assert "2 mg" not in body["response_text"]


def test_emergency_detected_in_gemini_output_is_labelled_safety(post, monkeypatch) -> None:
    _gemini_returns(monkeypatch, "anything", AnswerType.EMERGENCY)
    body = post("I feel strange")
    assert body["answer_source"] == "safety"
    assert body["response_text"] == EMERGENCY_RESPONSE_TEXT


def test_curated_answers_default_to_curated_never_ai() -> None:
    assert healthbot.answer_query("I have a headache").source == AnswerSource.CURATED
    assert healthbot.answer_query("unrelated question").source == AnswerSource.CURATED
    assert healthbot.answer_query("I want to end my life").source == AnswerSource.SAFETY
    assert HealthBotAnswer(AnswerType.MATCHED, "x").source == AnswerSource.CURATED


def test_no_technical_label_strings_remain_in_the_service() -> None:
    source = inspect.getsource(healthbot)
    assert "took too long to reply" not in source
    assert "AI responses are unavailable" not in source
    assert {reason.value for reason in FallbackReason} == {"timeout", "unavailable"}

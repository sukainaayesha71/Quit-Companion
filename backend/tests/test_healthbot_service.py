import json

import httpx
import pytest

from app.healthbot import service as healthbot
from app.healthbot.service import AnswerType, HealthBotAnswer, answer_query

TOPIC_CASES = [
    ("I have a headache", "Headaches are a common withdrawal symptom"),
    ("my head hurts so much", "Headaches are a common withdrawal symptom"),
    ("why am I so irritable", "Irritability and mood swings are very common"),
    ("I keep snapping at people", "Irritability and mood swings are very common"),
    ("I can't sleep at night", "Trouble sleeping is common"),
    ("having insomnia lately", "Trouble sleeping is common"),
    ("I feel so anxious", "Anxiety and restlessness are common"),
    ("feeling nervous and on edge", "Anxiety and restlessness are common"),
    ("this craving is so intense", "Craving intensity is usually strongest"),
    ("I really want to smoke right now", "Craving intensity is usually strongest"),
    ("I'm always hungry now", "Increased appetite is a normal"),
    ("gaining weight since I quit", "Increased appetite is a normal"),
    ("I can't focus at work", "Trouble concentrating"),
    ("feeling so foggy today", "Trouble concentrating"),
    ("is this normal?", "Most withdrawal symptoms"),
    ("should I worry about this", "Most withdrawal symptoms"),
    ("I have a bad cough", "A temporary increase in coughing"),
    ("bringing up phlegm", "A temporary increase in coughing"),
    ("I feel dizzy", "Mild dizziness or light-headedness"),
    ("lightheaded since I quit", "Mild dizziness or light-headedness"),
    ("I'm constipated", "Digestive changes such as constipation"),
    ("really upset stomach today", "Digestive changes such as constipation"),
    ("I have mouth sores", "Mouth sores or gum sensitivity"),
    ("I have sore gums", "Mouth sores or gum sensitivity"),
    ("I relapsed last night", "A slip doesn't erase the progress"),
    ("I smoked again", "A slip doesn't erase the progress"),
    ("I'm losing motivation", "Dips in motivation are a completely normal"),
    ("thinking about giving up", "Dips in motivation are a completely normal"),
    ("how do I avoid triggers", "Common triggers include stress"),
    ("what are my triggers", "Common triggers include stress"),
    ("can I exercise while quitting", "Light to moderate exercise is generally encouraged"),
    ("going to the gym today", "Light to moderate exercise is generally encouraged"),
    ("is drinking alcohol okay", "Alcohol is a well-known trigger"),
    ("drinking beer tonight", "Alcohol is a well-known trigger"),
    ("does coffee affect me now", "Nicotine changes how your body processes caffeine"),
    ("too much caffeine lately", "Nicotine changes how your body processes caffeine"),
    ("when will food taste better", "Many people notice food tasting"),
    ("will my sense of smell come back", "Many people notice food tasting"),
    ("is my breathing better now", "Breathing capacity typically starts improving"),
    ("I feel short of breath", "Breathing capacity typically starts improving"),
    ("how long do cravings last", "Most physical withdrawal symptoms peak"),
    ("when does it get easier", "Most physical withdrawal symptoms peak"),
    ("worried about secondhand smoke", "Secondhand smoke poses real health risks"),
    ("I smoke around my family", "Secondhand smoke poses real health risks"),
    ("vaping withdrawal symptoms", "Withdrawal from vaping follows a similar pattern"),
    ("trying to quit vaping", "Withdrawal from vaping follows a similar pattern"),
    ("my skin looks different", "Some people notice temporary skin changes"),
    ("getting acne since quitting", "Some people notice temporary skin changes"),
    ("I'm sweating a lot more", "Increased sweating"),
    ("having night sweats", "Increased sweating"),
    ("I feel so exhausted", "Low energy or fatigue"),
    ("no energy at all today", "Low energy or fatigue"),
    ("how do I stay on track", "Noticing and celebrating milestones"),
    ("want to celebrate progress", "Noticing and celebrating milestones"),
    ("all my friends smoke", "Being around others who smoke or vape"),
    ("someone offered a cigarette", "Being around others who smoke or vape"),
    ("I'm so stressed out", "Stress is one of the most common craving triggers"),
    ("need stress relief", "Stress is one of the most common craving triggers"),
    ("I miss having something in my mouth", "Missing the hand-to-mouth habit"),
    ("my hands feel empty without a cigarette", "Missing the hand-to-mouth habit"),
    ("I keep catching colds", "It can take some weeks for lung function"),
    ("getting sick more often", "It can take some weeks for lung function"),
    ("I have a sore throat", "A dry or scratchy throat"),
    ("my throat feels dry", "A dry or scratchy throat"),
]


@pytest.mark.parametrize("query,expected_substring", TOPIC_CASES)
def test_matched_topics_return_fixed_response(query: str, expected_substring: str) -> None:
    result = answer_query(query)
    assert result.type == AnswerType.MATCHED
    assert expected_substring in result.response_text


EMERGENCY_CASES = [
    "I have chest pain",
    "I can't breathe",
    "difficulty breathing right now",
    "my heart is racing",
    "I think it's a heart attack",
    "I want to hurt myself",
    "thinking about ending my life",
    "feeling suicidal",
]


@pytest.mark.parametrize("query", EMERGENCY_CASES)
def test_emergency_keywords_short_circuit_to_urgent_message(query: str) -> None:
    result = answer_query(query)
    assert result.type == AnswerType.EMERGENCY
    assert result.response_text == (
        "This sounds like it could be a medical emergency. "
        "Please seek emergency medical care immediately."
    )


def test_emergency_takes_priority_even_if_topic_keyword_also_present() -> None:
    result = answer_query("I have a headache and chest pain")
    assert result.type == AnswerType.EMERGENCY


def test_unmatched_query_returns_exact_srds_fallback_text() -> None:
    result = answer_query("what's the weather like today")
    assert result.type == AnswerType.UNMATCHED
    assert result.response_text == "I cannot answer this confidently. Please consult a doctor."


def test_no_response_text_contains_medication_or_dosage_language() -> None:
    banned_terms = ["mg", "milligram", "dose", "dosage", "nicotine patch", "you should take"]
    all_texts = []
    for query, _ in TOPIC_CASES:
        all_texts.append(answer_query(query).response_text)
    for text in all_texts:
        lowered = text.lower()
        for term in banned_terms:
            assert term not in lowered, f"banned term {term!r} found in {text!r}"


@pytest.mark.asyncio
async def test_gemini_emergency_phrase_is_handled_before_generation(monkeypatch: pytest.MonkeyPatch) -> None:
    async def fail_if_called(*args: object, **kwargs: object) -> str:
        raise AssertionError("Emergency phrases must not be sent to Gemini")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", fail_if_called)
    result = await healthbot.answer_query_with_gemini("I have chest pain", api_key="server-key")

    assert result.type == AnswerType.EMERGENCY


@pytest.mark.asyncio
async def test_gemini_generated_reply_is_returned_instead_of_fixed_topic_text(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    generated_reply = "Try moving your usual after-dinner routine to a short walk while the urge passes."

    async def generate(*args: object, **kwargs: object) -> HealthBotAnswer:
        return HealthBotAnswer(type=AnswerType.MATCHED, response_text=generated_reply)

    monkeypatch.setattr(healthbot, "_request_gemini_answer", generate)
    result = await healthbot.answer_query_with_gemini(
        "I always crave nicotine after dinner; what could I change?",
        api_key="server-key",
    )

    assert result == HealthBotAnswer(type=AnswerType.MATCHED, response_text=generated_reply)


@pytest.mark.asyncio
async def test_gemini_unmatched_reply_is_returned_from_model(monkeypatch: pytest.MonkeyPatch) -> None:
    async def generate(*args: object, **kwargs: object) -> HealthBotAnswer:
        return HealthBotAnswer(type=AnswerType.UNMATCHED, response_text="I focus on support for quitting nicotine.")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", generate)
    result = await healthbot.answer_query_with_gemini("What is the capital of France?", api_key="server-key")

    assert result.type == AnswerType.UNMATCHED
    assert result.response_text == "I focus on support for quitting nicotine."


@pytest.mark.asyncio
async def test_gemini_detected_emergency_uses_fixed_escalation(monkeypatch: pytest.MonkeyPatch) -> None:
    async def generate(*args: object, **kwargs: object) -> HealthBotAnswer:
        return HealthBotAnswer(type=AnswerType.EMERGENCY, response_text="untrusted model response")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", generate)
    result = await healthbot.answer_query_with_gemini("I feel dangerously unwell", api_key="server-key")

    assert result.type == AnswerType.EMERGENCY
    assert result.response_text == healthbot.EMERGENCY_RESPONSE_TEXT


@pytest.mark.asyncio
async def test_gemini_generation_request_parses_model_response(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict[str, object]:
            return {
                "candidates": [{
                    "content": {
                        "parts": [{
                            "text": json.dumps({
                                "answer_type": "matched",
                                "response_text": "A generated response tailored to this question.",
                            })
                        }]
                    }
                }]
            }

    class FakeAsyncClient:
        def __init__(self, timeout: float) -> None:
            assert timeout > 0

        async def __aenter__(self) -> "FakeAsyncClient":
            return self

        async def __aexit__(self, *args: object) -> None:
            return None

        async def post(self, url: str, *, headers: dict[str, str], json: dict[str, object]) -> FakeResponse:
            captured.update(url=url, headers=headers, body=json)
            return FakeResponse()

    monkeypatch.setattr(healthbot.httpx, "AsyncClient", FakeAsyncClient)
    result = await healthbot._request_gemini_answer(
        "A question with no matching canned topic",
        api_key="server-key",
        model="test-model",
    )

    assert result == HealthBotAnswer(
        type=AnswerType.MATCHED,
        response_text="A generated response tailored to this question.",
        source=healthbot.AnswerSource.AI,
    )
    assert captured["url"].endswith("/test-model:generateContent")
    assert captured["headers"] == {"x-goog-api-key": "server-key"}
    request_body = captured["body"]
    assert isinstance(request_body, dict)
    assert request_body["contents"] == [
        {"role": "user", "parts": [{"text": "A question with no matching canned topic"}]}
    ]


@pytest.mark.asyncio
async def test_gemini_missing_configuration_is_reported(caplog: pytest.LogCaptureFixture) -> None:
    answer = await healthbot.answer_query_with_gemini("headache", api_key=None)
    assert answer.type == AnswerType.MATCHED
    assert answer.response_text == healthbot.answer_query("headache").response_text
    assert answer.source == healthbot.AnswerSource.CURATED
    assert answer.fallback_reason == healthbot.FallbackReason.UNAVAILABLE

    assert "not configured" in caplog.text


@pytest.mark.asyncio
async def test_gemini_failure_returns_labeled_rule_based_fallback(
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    async def network_failure(*args: object, **kwargs: object) -> str:
        raise httpx.TimeoutException("request timed out")

    monkeypatch.setattr(healthbot, "_request_gemini_answer", network_failure)
    answer = await healthbot.answer_query_with_gemini("question", api_key="server-key")
    assert answer.type == AnswerType.UNMATCHED
    assert healthbot.UNMATCHED_FALLBACK_TEXT in answer.response_text

    assert "timed out" in caplog.text

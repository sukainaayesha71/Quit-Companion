from fastapi.testclient import TestClient

from app.fake_firebase_identity import FakeFirebaseIdentityProvider
from app.healthbot.service import AnswerType, HealthBotAnswer
from app.healthbot import router as healthbot_router

VALID_TOKEN = "valid-test-token"


def _authed_headers(firebase_identity: FakeFirebaseIdentityProvider) -> dict[str, str]:
    firebase_identity.valid_tokens[VALID_TOKEN] = "test-uid-1"
    return {"Authorization": f"Bearer {VALID_TOKEN}"}


def test_matched_query_returns_matched_answer(
    client: TestClient,
    firebase_identity: FakeFirebaseIdentityProvider,
    monkeypatch,
):
    async def generate(query: str, **kwargs: object) -> HealthBotAnswer:
        return HealthBotAnswer(
            type=AnswerType.MATCHED,
            response_text="A tailored answer based on your situation.",
        )

    monkeypatch.setattr(healthbot_router, "answer_query_with_gemini", generate)
    response = client.post(
        "/healthbot/query",
        json={"query": "I have a headache"},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["answer_type"] == "matched"
    assert body["response_text"] == "A tailored answer based on your situation."


def test_emergency_query_returns_emergency_answer(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post(
        "/healthbot/query",
        json={"query": "I have chest pain"},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 200
    assert response.json()["answer_type"] == "emergency"


def test_missing_gemini_configuration_returns_labeled_rule_based_fallback(
    client: TestClient,
    firebase_identity: FakeFirebaseIdentityProvider,
    monkeypatch,
):
    from app.config import settings

    monkeypatch.setattr(settings, "gemini_api_key", None)
    response = client.post(
        "/healthbot/query",
        json={"query": "what time is it"},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["answer_type"] == "unmatched"
    assert body["response_text"] == "I cannot answer this confidently. Please consult a doctor."
    assert body["answer_source"] == "curated"
    assert body["fallback_reason"] == "unavailable"


def test_missing_query_field_is_rejected(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post("/healthbot/query", json={}, headers=_authed_headers(firebase_identity))

    assert response.status_code == 422


def test_request_without_auth_header_is_rejected(client: TestClient):
    response = client.post("/healthbot/query", json={"query": "headache"})

    assert response.status_code == 401


def test_request_with_unverifiable_token_is_rejected(client: TestClient):
    # Token never registered in firebase_identity.valid_tokens.
    response = client.post(
        "/healthbot/query",
        json={"query": "headache"},
        headers={"Authorization": "Bearer some-unknown-token"},
    )

    assert response.status_code == 401

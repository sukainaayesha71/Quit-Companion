from fastapi.testclient import TestClient

from app.dependencies import get_relapse_predictor
from app.fake_firebase_identity import FakeFirebaseIdentityProvider
from app.main import app
from app.relapse.predictor import ModelPredictor
from app.relapse.service import RiskLevel

VALID_TOKEN = "valid-test-token"

FULL_SLIDERS = {
    "mood_happy": 5,
    "mood_excited": 5,
    "mood_enthusiastic": 5,
    "mood_contented": 5,
    "mood_calm": 5,
    "mood_irritable": 5,
    "mood_anxious": 5,
    "mood_stressed": 5,
    "mood_sad": 5,
    "mood_bored": 5,
}


def _authed_headers(firebase_identity: FakeFirebaseIdentityProvider) -> dict[str, str]:
    firebase_identity.valid_tokens[VALID_TOKEN] = "test-uid-1"
    return {"Authorization": f"Bearer {VALID_TOKEN}"}


def test_predict_relapse_returns_risk_level(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post(
        "/predict/relapse",
        json={"intensity": 9, "mood": "happy", "trigger_category": "other", "last_24h_count": 1},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 200
    assert response.json()["risk_level"] == "high"
    assert response.json()["clinically_validated"] is False


def test_predict_relapse_low_risk(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post(
        "/predict/relapse",
        json={"intensity": 1, "mood": "happy", "trigger_category": "other", "last_24h_count": 1},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 200
    assert response.json()["risk_level"] == "low"


def test_predict_relapse_rejects_intensity_out_of_range(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post(
        "/predict/relapse",
        json={"intensity": 11, "mood": "happy", "trigger_category": "other", "last_24h_count": 1},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 422


def test_predict_relapse_rejects_unknown_mood(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post(
        "/predict/relapse",
        json={"intensity": 5, "mood": "anxious", "trigger_category": "other", "last_24h_count": 1},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 422


def test_predict_relapse_rejects_negative_last_24h_count(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post(
        "/predict/relapse",
        json={"intensity": 5, "mood": "happy", "trigger_category": "other", "last_24h_count": -1},
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 422


def test_predict_relapse_rejects_missing_authorization_header(client: TestClient):
    response = client.post(
        "/predict/relapse",
        json={"intensity": 5, "mood": "happy", "trigger_category": "other", "last_24h_count": 1},
    )

    assert response.status_code == 401


def test_predict_relapse_rejects_malformed_authorization_header(client: TestClient):
    response = client.post(
        "/predict/relapse",
        json={"intensity": 5, "mood": "happy", "trigger_category": "other", "last_24h_count": 1},
        headers={"Authorization": "not-a-bearer-token"},
    )

    assert response.status_code == 401


def test_predict_relapse_rejects_unverifiable_token(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    # Token never registered in firebase_identity.valid_tokens.
    response = client.post(
        "/predict/relapse",
        json={"intensity": 5, "mood": "happy", "trigger_category": "other", "last_24h_count": 1},
        headers={"Authorization": "Bearer some-unknown-token"},
    )

    assert response.status_code == 401


def test_predict_relapse_default_predictor_is_rule_based_and_silently_ignores_mood_sliders(
    client: TestClient, firebase_identity: FakeFirebaseIdentityProvider
):
    """Confirms normal app traffic (no dependency override, i.e. the real
    production wiring) never reaches the research-preview model, even if a
    client happened to send the optional mood-slider fields."""
    response = client.post(
        "/predict/relapse",
        json={
            "intensity": 9,
            "mood": "stressed",
            "trigger_category": "socialPressure",
            "last_24h_count": 1,
            **FULL_SLIDERS,
        },
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 200
    assert response.json()["risk_level"] == "high"  # the rule-based table's answer, not the model's


def test_predict_relapse_research_preview_model_mode_returns_a_real_risk_level(
    client: TestClient, firebase_identity: FakeFirebaseIdentityProvider
):
    """Only reachable when an operator explicitly overrides the predictor
    dependency (equivalent to RELAPSE_PREDICTOR_MODE=model) - never how a
    normal app request is served."""
    app.dependency_overrides[get_relapse_predictor] = lambda: ModelPredictor()
    try:
        response = client.post(
            "/predict/relapse",
            json={
                "intensity": 5,
                "mood": "happy",
                "trigger_category": "other",
                "last_24h_count": 1,
                **FULL_SLIDERS,
            },
            headers=_authed_headers(firebase_identity),
        )
    finally:
        del app.dependency_overrides[get_relapse_predictor]

    assert response.status_code == 200
    assert response.json()["risk_level"] in [level.value for level in RiskLevel]


def test_predict_relapse_research_preview_model_mode_rejects_missing_mood_sliders_as_400(
    client: TestClient, firebase_identity: FakeFirebaseIdentityProvider
):
    app.dependency_overrides[get_relapse_predictor] = lambda: ModelPredictor()
    try:
        response = client.post(
            "/predict/relapse",
            json={"intensity": 5, "mood": "happy", "trigger_category": "other", "last_24h_count": 1},
            headers=_authed_headers(firebase_identity),
        )
    finally:
        del app.dependency_overrides[get_relapse_predictor]

    assert response.status_code == 400


def test_predict_relapse_rejects_mood_slider_out_of_range(client: TestClient, firebase_identity: FakeFirebaseIdentityProvider):
    response = client.post(
        "/predict/relapse",
        json={
            "intensity": 5,
            "mood": "happy",
            "trigger_category": "other",
            "last_24h_count": 1,
            **{**FULL_SLIDERS, "mood_happy": 11},
        },
        headers=_authed_headers(firebase_identity),
    )

    assert response.status_code == 422

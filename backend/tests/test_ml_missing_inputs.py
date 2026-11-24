"""ML integration fixes (2026-11-23): the app now sends only answered mood
sliders and only answered check-in items. These tests send that exact payload
shape through the real endpoint and the real packaged model."""
from __future__ import annotations

import pytest

from app.dependencies import get_relapse_predictor
from app.main import app
from app.relapse.predictor import CandidatePredictor, RuleBasedPredictor
from app.relapse.service import predict_relapse_risk

TOKEN = "ml-missing-token"
ALL_SLIDERS = ("happy", "excited", "enthusiastic", "contented", "calm",
               "irritable", "anxious", "stressed", "sad", "bored")
RECOVERY = ("motivation_imp", "confidence_imp", "pain_imp", "cigarette_availability_imp")


def _headers(identity):
    identity.valid_tokens[TOKEN] = "u"
    return {"Authorization": f"Bearer {TOKEN}"}


@pytest.fixture(scope="module")
def model():
    return CandidatePredictor()


def test_only_unanswered_inputs_are_imputed(client, firebase_identity, model):
    app.dependency_overrides[get_relapse_predictor] = lambda: model
    # Exactly what the app sends when the user rated two moods and skipped the check-in.
    body = {"intensity": 8, "mood": "stressed", "trigger_category": "stress",
            "last_24h_count": 2, "mood_stressed": 9, "mood_anxious": 8}
    data = client.post("/predict/relapse", json=body, headers=_headers(firebase_identity)).json()

    assert data["assessment_source"] == "machine_learning"
    expected_missing = [f"{s}_imp" for s in ALL_SLIDERS if s not in ("stressed", "anxious")] + list(RECOVERY)
    assert sorted(data["imputed_features"]) == sorted(expected_missing)
    assert "stressed_imp" not in data["imputed_features"]
    assert data["risk_level"] in {"low", "medium", "high"}


def test_missing_values_go_through_the_fitted_imputer_not_a_default(model):
    """Missing sliders must equal the model's own training medians, never 5."""
    missing = model.predict_probability(intensity=6, mood="sad", trigger_category="other",
                                        last_24h_count=1, recovery_context={})
    medians = dict(zip(model.bundle["columns"],
                       model.bundle["estimator"].steps[0][1].statistics_))
    explicit_medians = model.predict_probability(
        intensity=6, mood="sad", trigger_category="other", last_24h_count=1,
        recovery_context={k: medians[k] for k in RECOVERY},
        **{f"mood_{s}": medians[f"{s}_imp"] for s in ALL_SLIDERS})
    as_fives = model.predict_probability(
        intensity=6, mood="sad", trigger_category="other", last_24h_count=1,
        recovery_context={}, **{f"mood_{s}": 5.0 for s in ALL_SLIDERS})
    assert missing == pytest.approx(explicit_medians)
    assert missing != pytest.approx(as_fives)


def test_answered_check_in_is_used_and_not_imputed(client, firebase_identity, model):
    app.dependency_overrides[get_relapse_predictor] = lambda: model
    body = {"intensity": 6, "mood": "stressed", "trigger_category": "stress", "last_24h_count": 1,
            "recovery_context": {"motivation_imp": 2, "confidence_imp": 2,
                                 "pain_imp": 6, "cigarette_availability_imp": 3}}
    data = client.post("/predict/relapse", json=body, headers=_headers(firebase_identity)).json()
    assert not set(RECOVERY) & set(data["imputed_features"])


def test_rule_based_mode_reports_its_source_and_ignores_missing_sliders(client, firebase_identity):
    app.dependency_overrides[get_relapse_predictor] = lambda: RuleBasedPredictor()
    body = {"intensity": 9, "mood": "stressed", "trigger_category": "stress", "last_24h_count": 3}
    data = client.post("/predict/relapse", json=body, headers=_headers(firebase_identity)).json()
    assert data["assessment_source"] == "RuleBasedPredictor"
    assert data["model_version"] is None and data["imputed_features"] == []
    assert data["risk_level"] == predict_relapse_risk(
        intensity=9, mood="stressed", trigger_category="stress", last_24h_count=3).value


def test_model_fault_with_partial_inputs_falls_back_and_is_labelled(client, firebase_identity):
    broken = CandidatePredictor()

    class Boom:
        def predict_proba(self, row):
            raise RuntimeError("fault")

    broken.bundle = {**broken.bundle, "estimator": Boom()}
    app.dependency_overrides[get_relapse_predictor] = lambda: broken
    body = {"intensity": 4, "mood": "bored", "trigger_category": "boredom",
            "last_24h_count": 1, "mood_bored": 7}
    data = client.post("/predict/relapse", json=body, headers=_headers(firebase_identity)).json()
    assert data["assessment_source"] == "rule_based_fallback"
    assert data["risk_level"] == predict_relapse_risk(
        intensity=4, mood="bored", trigger_category="boredom", last_24h_count=1).value

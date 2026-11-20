import shutil

import numpy as np
import pytest

from app.config import Settings
from app.dependencies import get_relapse_predictor
from app.main import app
from app.relapse.predictor import CandidatePredictor
from app.relapse.service import RiskLevel


@pytest.fixture(scope="module")
def predictor():
    return CandidatePredictor()


def checkin():
    return dict(
        intensity=6, mood="stressed", trigger_category="stress", last_24h_count=1,
        **{"mood_" + mood: 5 for mood in (
            "happy", "excited", "enthusiastic", "contented", "calm",
            "irritable", "anxious", "stressed", "sad", "bored")},
        recovery_context=dict(motivation_imp=8, confidence_imp=8, pain_imp=2,
                              cigarette_availability_imp=1),
    )


def test_default_mode_is_ml():
    assert Settings(_env_file=None).relapse_predictor_mode == "ml"


def test_packaged_model_matches_actual_pipeline_probability(predictor):
    body = checkin()
    values = predictor.feature_values(**body)
    row = np.asarray([[values[name] for name in predictor.bundle["columns"]]])
    expected = predictor.bundle["estimator"].predict_proba(row)[0, 1]
    assert predictor.predict_probability(**body) == pytest.approx(expected)
    assert predictor.predict(**body) in set(RiskLevel)
    assert predictor.missing_features(**body) == []


def test_unanswered_checkin_is_imputed_without_mutating_answers(predictor):
    body = dict(intensity=5, mood="happy", trigger_category="other", last_24h_count=1,
                recovery_context={})
    assert len(predictor.missing_features(**body)) == 14
    assert np.isfinite(predictor.predict_probability(**body))
    assert body["recovery_context"] == {}


@pytest.mark.parametrize("value", [float("nan"), float("inf"), -1, 11])
def test_invalid_ratings_rejected(predictor, value):
    body = checkin()
    body["mood_happy"] = value
    with pytest.raises(ValueError, match="finite"):
        predictor.predict(**body)


def test_corrupt_model_fails_before_deserialization(tmp_path):
    from pathlib import Path
    folder = Path(__file__).parents[1] / "app/relapse/model_artifacts"
    shutil.copy(folder / "app_candidate_metadata.json", tmp_path)
    artifact = tmp_path / "app_candidate.joblib"
    artifact.write_bytes(b"corrupted")
    with pytest.raises(ValueError, match="checksum"):
        CandidatePredictor(artifact)


def test_authenticated_endpoint_uses_ml_and_reports_missing_features(client, firebase_identity, predictor):
    firebase_identity.valid_tokens["ml-test-token"] = "ml-test-user"
    app.dependency_overrides[get_relapse_predictor] = lambda: predictor
    for body, missing_count in [(checkin(), 0),
        (dict(intensity=4, mood="happy", trigger_category="other", last_24h_count=1), 14)]:
        response = client.post("/predict/relapse", json=body,
                               headers={"Authorization": "Bearer ml-test-token"})
        assert response.status_code == 200, response.text
        data = response.json()
        assert data["assessment_source"] == "machine_learning"
        assert data["model_version"] == "emasens-xgboost-v1"
        assert data["clinically_validated"] is False
        assert len(data["imputed_features"]) == missing_count
        assert data["risk_level"] in {"low", "medium", "high"}

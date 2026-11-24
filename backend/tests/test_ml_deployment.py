"""FR5 ML deployment configuration: loading, paths, missing/corrupt artifacts,
runtime model failures and API compatibility. The model itself, its features
and thresholds are unchanged; nothing here retrains anything."""
from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

import pytest

from app import dependencies
from app.config import settings
from app.dependencies import _build_relapse_predictor, get_relapse_predictor
from app.main import app
from app.relapse.predictor import (
    PACKAGED_CANDIDATE_PATH,
    CandidatePredictor,
    PredictionModelError,
    RuleBasedPredictor,
)
from app.relapse.service import RiskLevel, predict_relapse_risk
from app.worker import assessment_source

BACKEND = Path(__file__).resolve().parents[1]
ARTIFACTS = BACKEND / "app/relapse/model_artifacts"
TOKEN = "ml-deploy-token"

CHECKIN = dict(
    intensity=7, mood="stressed", trigger_category="stress", last_24h_count=2,
    mood_happy=3, mood_excited=2, mood_enthusiastic=2, mood_contented=3, mood_calm=2,
    mood_irritable=7, mood_anxious=8, mood_stressed=8, mood_sad=5, mood_bored=4,
    recovery_context={"motivation_imp": 6, "confidence_imp": 4, "pain_imp": 2,
                      "cigarette_availability_imp": 2},
)


def _headers(identity):
    identity.valid_tokens[TOKEN] = "ml-user"
    return {"Authorization": f"Bearer {TOKEN}"}


def _copy_artifacts(dest: Path) -> Path:
    for name in ("app_candidate.joblib", "app_candidate_metadata.json"):
        shutil.copy(ARTIFACTS / name, dest / name)
    return dest / "app_candidate.joblib"


@pytest.fixture
def restore_settings(monkeypatch):
    monkeypatch.setattr(settings, "relapse_predictor_mode", "ml")
    monkeypatch.setattr(settings, "relapse_model_path", None)
    monkeypatch.setattr(settings, "relapse_model_required", False)
    yield
    monkeypatch.undo()
    _build_relapse_predictor()  # leave the status describing the real wiring


# --- Loading and paths -------------------------------------------------------


def test_packaged_artifact_lives_inside_the_app_package_copied_into_docker():
    assert PACKAGED_CANDIDATE_PATH.is_absolute()
    assert PACKAGED_CANDIDATE_PATH.is_relative_to(BACKEND / "app")
    assert PACKAGED_CANDIDATE_PATH.exists()
    assert (PACKAGED_CANDIDATE_PATH.parent / "app_candidate_metadata.json").exists()
    dockerfile = (BACKEND / "Dockerfile").read_text()
    assert re.search(r"^COPY app \./app$", dockerfile, re.M)


def test_loading_does_not_depend_on_the_working_directory(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    predictor = CandidatePredictor()
    assert predictor.model_version == "emasens-xgboost-v1"
    assert predictor.predict(**CHECKIN) in set(RiskLevel)


def test_relapse_model_path_override_loads_a_mounted_copy(tmp_path, monkeypatch, restore_settings):
    mounted = _copy_artifacts(tmp_path)
    monkeypatch.setattr(settings, "relapse_model_path", str(mounted))

    predictor = _build_relapse_predictor()

    assert isinstance(predictor, CandidatePredictor)
    assert predictor.artifact_path == mounted
    assert dependencies.relapse_predictor_status["active"] == "machine_learning"


def test_packaged_and_mounted_copies_give_identical_predictions(tmp_path):
    packaged = CandidatePredictor()
    mounted = CandidatePredictor(_copy_artifacts(tmp_path))
    assert mounted.predict_probability(**CHECKIN) == packaged.predict_probability(**CHECKIN)


def test_feature_set_and_thresholds_are_the_trained_ones():
    metadata = json.loads((ARTIFACTS / "app_candidate_metadata.json").read_text())
    predictor = CandidatePredictor()
    assert predictor.bundle["columns"] == metadata["selected"]["columns"]
    assert len(predictor.bundle["columns"]) == 15
    assert predictor.bundle["thresholds"]["low_threshold"] == metadata["selected"]["thresholds"]["low_threshold"]
    assert predictor.bundle["thresholds"]["high_threshold"] == metadata["selected"]["thresholds"]["high_threshold"]


# --- Missing / corrupt / mismatched artifacts -------------------------------


@pytest.mark.parametrize("remove", ["app_candidate.joblib", "app_candidate_metadata.json"])
def test_missing_artifact_falls_back_to_rule_based_and_reports_it(tmp_path, monkeypatch, restore_settings, remove):
    mounted = _copy_artifacts(tmp_path)
    (tmp_path / remove).unlink()
    monkeypatch.setattr(settings, "relapse_model_path", str(mounted))

    predictor = _build_relapse_predictor()

    assert isinstance(predictor, RuleBasedPredictor)
    assert dependencies.relapse_predictor_status == {
        "requested_mode": "ml",
        "active": "rule_based",
        "fallback_reason": "FileNotFoundError",
    }


def test_corrupt_artifact_falls_back(tmp_path, monkeypatch, restore_settings):
    mounted = _copy_artifacts(tmp_path)
    mounted.write_bytes(b"not a model")
    monkeypatch.setattr(settings, "relapse_model_path", str(mounted))

    assert isinstance(_build_relapse_predictor(), RuleBasedPredictor)
    assert dependencies.relapse_predictor_status["fallback_reason"] == "ValueError"


def test_required_mode_refuses_to_start_without_the_model(tmp_path, monkeypatch, restore_settings):
    monkeypatch.setattr(settings, "relapse_model_path", str(tmp_path / "absent.joblib"))
    monkeypatch.setattr(settings, "relapse_model_required", True)
    with pytest.raises(FileNotFoundError):
        _build_relapse_predictor()


def test_metadata_column_mismatch_is_rejected_at_load(tmp_path):
    mounted = _copy_artifacts(tmp_path)
    meta_path = tmp_path / "app_candidate_metadata.json"
    metadata = json.loads(meta_path.read_text())
    metadata["selected"]["columns"] = list(reversed(metadata["selected"]["columns"]))
    meta_path.write_text(json.dumps(metadata))
    with pytest.raises(ValueError, match="feature columns"):
        CandidatePredictor(mounted)


# --- Prediction errors and API ----------------------------------------------


def test_estimator_failure_is_a_model_error_not_bad_input():
    predictor = CandidatePredictor()

    class Broken:
        def predict_proba(self, row):
            raise RuntimeError("native library crashed")

    predictor.bundle = {**predictor.bundle, "estimator": Broken()}
    with pytest.raises(PredictionModelError):
        predictor.predict(**CHECKIN)
    assert not issubclass(PredictionModelError, ValueError)


def test_invalid_probability_is_a_model_error():
    predictor = CandidatePredictor()

    class Nonsense:
        def predict_proba(self, row):
            import numpy as np
            return np.array([[0.0, 1.7]])

    predictor.bundle = {**predictor.bundle, "estimator": Nonsense()}
    with pytest.raises(PredictionModelError, match="invalid probability"):
        predictor.predict_probability(**CHECKIN)


def test_endpoint_answers_with_rule_based_fallback_when_the_model_fails(client, firebase_identity):
    predictor = CandidatePredictor()

    class Broken:
        def predict_proba(self, row):
            raise RuntimeError("boom")

    predictor.bundle = {**predictor.bundle, "estimator": Broken()}
    app.dependency_overrides[get_relapse_predictor] = lambda: predictor

    response = client.post("/predict/relapse", json=CHECKIN, headers=_headers(firebase_identity))

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["assessment_source"] == "rule_based_fallback"
    assert body["risk_level"] == predict_relapse_risk(
        intensity=7, mood="stressed", trigger_category="stress", last_24h_count=2
    ).value
    assert body["model_version"] is None
    assert set(body) == {"risk_level", "assessment_source", "clinically_validated",
                         "model_version", "imputed_features"}


@pytest.mark.parametrize(
    "change",
    [{"intensity": 11}, {"mood_anxious": 12}, {"mood": "angry"},
     {"recovery_context": {"unknown_imp": 3}}, {"recovery_context": {"cigarette_availability_imp": 5}}],
)
def test_invalid_input_is_still_rejected_as_a_client_error(client, firebase_identity, change):
    app.dependency_overrides[get_relapse_predictor] = lambda: CandidatePredictor()
    response = client.post("/predict/relapse", json={**CHECKIN, **change}, headers=_headers(firebase_identity))
    assert response.status_code in {400, 422}


def test_ml_endpoint_response_is_unchanged_in_shape_and_labelled(client, firebase_identity):
    predictor = CandidatePredictor()
    app.dependency_overrides[get_relapse_predictor] = lambda: predictor
    body = client.post("/predict/relapse", json=CHECKIN, headers=_headers(firebase_identity)).json()

    assert body["assessment_source"] == "machine_learning"
    assert body["model_version"] == "emasens-xgboost-v1"
    assert body["clinically_validated"] is False
    assert body["imputed_features"] == []
    assert body["risk_level"] == predictor.predict(**CHECKIN).value


def test_ready_reports_which_predictor_is_serving(client):
    _build_relapse_predictor()
    body = client.get("/ready").json()
    assert body["relapse_predictor"]["requested_mode"] == settings.relapse_predictor_mode
    assert "active" in body["relapse_predictor"]
    assert all("/" not in str(v) and "\\" not in str(v) for v in body["relapse_predictor"].values())


def test_worker_labels_what_actually_scored_the_log():
    assert assessment_source(CandidatePredictor()) == "machine_learning"
    assert assessment_source(RuleBasedPredictor()) == "rule_based"


def test_runtime_dependencies_are_pinned_to_the_training_versions():
    requirements = (BACKEND / "requirements.txt").read_text()
    for package in ("scikit-learn", "xgboost", "joblib", "numpy"):
        assert re.search(rf"^{package}==\d", requirements, re.M), package

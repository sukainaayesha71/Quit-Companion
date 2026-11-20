"""Model-loading/prediction smoke test (backend AI/ML plan, Phase 4-6).
Confirms a saved .joblib artifact actually loads and predicts without
crashing — not a model-quality check (see ml/outputs/training_metadata.json
and train.py's own printed report for that). Skips cleanly when the
artifacts aren't present: they're gitignored (see .gitignore) and only
exist locally after running `python -m ml.train`, so a fresh checkout/CI
box without the dataset must not fail this test.
"""
import json
from pathlib import Path


import joblib
import pytest

MODELS_DIR = Path(__file__).resolve().parents[1] / "ml" / "models"

_FEATURE_COLUMNS_PATH = MODELS_DIR / "feature_columns.json"

pytestmark = pytest.mark.skipif(
    not _FEATURE_COLUMNS_PATH.exists(),
    reason="Trained model artifacts not present locally (gitignored) - run `python -m ml.train` first.",
)


@pytest.fixture(scope="module")
def encoded_feature_columns() -> dict:
    with open(_FEATURE_COLUMNS_PATH) as f:
        return json.load(f)


@pytest.mark.parametrize(
    "artifact_name,feature_set_key",
    [
        ("full_ema__random_forest.joblib", "full_ema"),
        ("full_ema__xgboost.joblib", "full_ema"),
        ("cravinglog_compatible__random_forest.joblib", "cravinglog_compatible"),
        ("cravinglog_compatible__xgboost.joblib", "cravinglog_compatible"),
    ],
)
def test_saved_model_loads_and_predicts_without_crashing(artifact_name, feature_set_key, encoded_feature_columns):
    model_path = MODELS_DIR / artifact_name
    if not model_path.exists():
        pytest.skip(f"{artifact_name} not present locally (gitignored).")

    pd = pytest.importorskip("pandas")
    model = joblib.load(model_path)
    columns = encoded_feature_columns[feature_set_key]

    # All-zero single-row frame in the model's exact encoded column shape —
    # sufficient to prove the artifact deserializes and its predict/
    # predict_proba path executes; not a claim about prediction quality.
    dummy_row = pd.DataFrame([[0] * len(columns)], columns=columns)

    prediction = model.predict(dummy_row)
    probabilities = model.predict_proba(dummy_row)

    assert prediction.shape == (1,)
    assert probabilities.shape == (1, 2)
    assert 0.0 <= probabilities[0][1] <= 1.0

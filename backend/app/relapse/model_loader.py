"""Research-preview only. Loads the pre-trained cravinglog_compatible /
random_forest artifact (backend/ml/train.py, EMASENS_ML v2.0.0 dataset) and
its own derived thresholds from backend/app/relapse/model_artifacts/ - a
small, always-tracked copy kept separate from backend/ml/ (gitignored,
training-only) specifically so a fresh checkout can load this path without
depending on anything local to the machine that ran the training pipeline.

ROC-AUC on held-out data was ~0.50 (chance level) - see model_artifacts/
metadata.json and backend/ml/README.md's "Known limitations" section. This
is not a working predictor; it exists so ModelPredictor (app/relapse/
predictor.py) has something real to demonstrate behind the
RELAPSE_PREDICTOR_MODE=model flag, which is never the production default
and never reachable by end users.
"""

import json
from pathlib import Path

import joblib

from .service import RiskLevel

_ARTIFACTS_DIR = Path(__file__).resolve().parent / "model_artifacts"
_MODEL_PATH = _ARTIFACTS_DIR / "cravinglog_compatible_random_forest.joblib"
_METADATA_PATH = _ARTIFACTS_DIR / "metadata.json"


class CravingLogCompatibleModel:
    """Wraps the joblib artifact + its own metadata (feature order,
    thresholds). Raises loudly at construction time if the artifact is
    missing, rather than deferring to a confusing failure on first predict
    - consistent with this codebase's "fail loudly, never fabricate" rule
    for the relapse predictors (see RuleBasedPredictor/ModelPredictor)."""

    def __init__(self, model_path: Path = _MODEL_PATH, metadata_path: Path = _METADATA_PATH):
        if not model_path.exists() or not metadata_path.exists():
            raise FileNotFoundError(
                f"Research-preview model artifacts missing ({model_path}, {metadata_path}) "
                "- this checkout is incomplete."
            )
        self._model = joblib.load(model_path)
        with open(metadata_path) as f:
            metadata = json.load(f)
        self.feature_order: list[str] = metadata["feature_order"]
        self.low_threshold: float = metadata["thresholds"]["low_threshold"]
        self.high_threshold: float = metadata["thresholds"]["high_threshold"]

    def predict_risk_level(self, features: dict[str, float]) -> RiskLevel:
        row = [[features[name] for name in self.feature_order]]
        probability = self._model.predict_proba(row)[0][1]
        if probability >= self.high_threshold:
            return RiskLevel.HIGH
        if probability >= self.low_threshold:
            return RiskLevel.MEDIUM
        return RiskLevel.LOW

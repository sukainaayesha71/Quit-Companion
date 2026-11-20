from abc import ABC, abstractmethod

from .model_loader import CravingLogCompatibleModel
from .service import RiskLevel, predict_relapse_risk


class RelapsePredictor(ABC):
    @abstractmethod
    def predict(
        self,
        *,
        intensity: int,
        mood: str,
        trigger_category: str,
        last_24h_count: int,
        # Mood-slider ratings (0-10, Open Decision 6) - unused by
        # RuleBasedPredictor, required by ModelPredictor. Optional here so
        # both subclasses share one signature without forcing every caller
        # (including RuleBasedPredictor's own tests) to pass them.
        mood_happy: float | None = None,
        mood_excited: float | None = None,
        mood_enthusiastic: float | None = None,
        mood_contented: float | None = None,
        mood_calm: float | None = None,
        mood_irritable: float | None = None,
        mood_anxious: float | None = None,
        mood_stressed: float | None = None,
        mood_sad: float | None = None,
        mood_bored: float | None = None,
    ) -> RiskLevel: ...


class CandidatePredictor(RelapsePredictor):
    """Packaged XGBoost pipeline; experimental, not clinically validated.

    Missing answers pass through the fitted training-set median imputer.
    They are never fabricated or written back as user-provided ratings.
    """

    model_version = "emasens-xgboost-v1"

    def __init__(self, artifact_path=None):
        from pathlib import Path
        import hashlib
        import json
        import joblib

        path = Path(artifact_path) if artifact_path else Path(__file__).parent / "model_artifacts/app_candidate.joblib"
        metadata = json.loads(path.with_name("app_candidate_metadata.json").read_text())
        if hashlib.sha256(path.read_bytes()).hexdigest() != metadata["sha256"]:
            raise ValueError("ML artifact checksum does not match its metadata")
        self.bundle = joblib.load(path)
        self.model_version = metadata["model_version"]
        low = self.bundle["thresholds"]["low_threshold"]
        high = self.bundle["thresholds"]["high_threshold"]
        if not 0 <= low < high <= 1:
            raise ValueError("Invalid ML risk thresholds")

    def feature_values(self, *, intensity, recovery_context=None, **kwargs):
        import math

        if not 1 <= intensity <= 10:
            raise ValueError("Craving intensity must be from 1 to 10")
        values = dict(recovery_context or {})
        values["craving_imp"] = (intensity - 1) * 10 / 9
        for name in ("happy", "excited", "enthusiastic", "contented", "calm",
                     "irritable", "anxious", "stressed", "sad", "bored"):
            values[name + "_imp"] = kwargs.get("mood_" + name)
        for name in self.bundle["columns"]:
            value = values.get(name)
            if value is not None and (not math.isfinite(value) or not 0 <= value <= 10):
                raise ValueError("ML ratings must be finite values from 0 to 10")
            if name == "cigarette_availability_imp" and value is not None and value not in {1, 2, 3}:
                raise ValueError("Cigarette availability must be 1, 2 or 3")
        return values

    def missing_features(self, **kwargs):
        values = self.feature_values(**kwargs)
        return [name for name in self.bundle["columns"] if values.get(name) is None]

    def predict_probability(self, **kwargs):
        import math
        import numpy as np

        values = self.feature_values(**kwargs)
        row = np.asarray([[values.get(name) if values.get(name) is not None else np.nan
                           for name in self.bundle["columns"]]], dtype=float)
        probability = float(self.bundle["estimator"].predict_proba(row)[0, 1])
        if not math.isfinite(probability) or not 0 <= probability <= 1:
            raise ValueError("ML model returned an invalid probability")
        return probability

    def predict(self, **kwargs):
        probability = self.predict_probability(**kwargs)
        thresholds = self.bundle["thresholds"]
        if probability >= thresholds["high_threshold"]:
            return RiskLevel.HIGH
        if probability >= thresholds["low_threshold"]:
            return RiskLevel.MEDIUM
        return RiskLevel.LOW


class RuleBasedPredictor(RelapsePredictor):
    """Wraps today's rule-based decision table (SRDS Sec 5.5.1) unchanged —
    behavior-identical to predict_relapse_risk, proven by
    test_relapse_predictor.py's equivalence tests. Selected explicitly with RELAPSE_PREDICTOR_MODE=rule_based."""

    def predict(
        self,
        *,
        intensity: int,
        mood: str,
        trigger_category: str,
        last_24h_count: int,
        mood_happy: float | None = None,
        mood_excited: float | None = None,
        mood_enthusiastic: float | None = None,
        mood_contented: float | None = None,
        mood_calm: float | None = None,
        mood_irritable: float | None = None,
        mood_anxious: float | None = None,
        mood_stressed: float | None = None,
        mood_sad: float | None = None,
        mood_bored: float | None = None,
    ) -> RiskLevel:
        return predict_relapse_risk(
            intensity=intensity,
            mood=mood,
            trigger_category=trigger_category,
            last_24h_count=last_24h_count,
        )


class ModelPredictor(RelapsePredictor):
    """RESEARCH PREVIEW - NOT the production default, NEVER exposed to
    normal app users, NOT clinically validated.

    Loads the existing cravinglog_compatible / random_forest artifact
    (backend/app/relapse/model_artifacts/, see model_loader.py) and its own
    derived thresholds. That model's ROC-AUC on held-out EMASENS_ML data was
    ~0.50 - chance level, not a working predictor - documented in
    model_artifacts/metadata.json and backend/ml/README.md's "Known
    limitations" section. It is wired up here purely so the
    RELAPSE_PREDICTOR_MODE=model flag (operator-only, set via environment,
    never surfaced in the app) demonstrates a real inference path rather
    than remaining an unimplemented placeholder. See the backend AI/ML
    plan's Open Decision 1 for the full history.

    Requires all 10 mood-slider ratings (Open Decision 6) - raises rather
    than substituting a guess for a feature it cannot silently invent.
    """

    def __init__(self, model: CravingLogCompatibleModel | None = None):
        self._model = model or CravingLogCompatibleModel()

    def predict(
        self,
        *,
        intensity: int,
        mood: str,
        trigger_category: str,
        last_24h_count: int,
        mood_happy: float | None = None,
        mood_excited: float | None = None,
        mood_enthusiastic: float | None = None,
        mood_contented: float | None = None,
        mood_calm: float | None = None,
        mood_irritable: float | None = None,
        mood_anxious: float | None = None,
        mood_stressed: float | None = None,
        mood_sad: float | None = None,
        mood_bored: float | None = None,
    ) -> RiskLevel:
        # Keyed by the caller-facing parameter name (not the internal
        # EMASENS feature name) so a raised error names the argument the
        # caller actually needs to fix.
        sliders_by_param_name = {
            "mood_happy": ("happy_imp", mood_happy),
            "mood_excited": ("excited_imp", mood_excited),
            "mood_enthusiastic": ("enthusiastic_imp", mood_enthusiastic),
            "mood_contented": ("contented_imp", mood_contented),
            "mood_calm": ("calm_imp", mood_calm),
            "mood_irritable": ("irritable_imp", mood_irritable),
            "mood_anxious": ("anxious_imp", mood_anxious),
            "mood_stressed": ("stressed_imp", mood_stressed),
            "mood_sad": ("sad_imp", mood_sad),
            "mood_bored": ("bored_imp", mood_bored),
        }
        missing = [param_name for param_name, (_, value) in sliders_by_param_name.items() if value is None]
        if missing:
            raise ValueError(
                f"ModelPredictor requires all 10 mood-slider ratings; missing: {missing}"
            )

        # CravingLog's 1-10 intensity -> EMASENS's native 0-10 craving_imp
        # scale (feature_mapping.py: "trivial rescale, same construct").
        # Linear map preserving both endpoints: 1 -> 0.0, 10 -> 10.0.
        craving_imp = (intensity - 1) * (10 / 9)

        features = {
            "craving_imp": craving_imp,
            **{feature_name: float(value) for feature_name, value in sliders_by_param_name.values()},
        }
        return self._model.predict_risk_level(features)

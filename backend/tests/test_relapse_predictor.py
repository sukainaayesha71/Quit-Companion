import json
from pathlib import Path

import pytest

from app.relapse.model_loader import CravingLogCompatibleModel
from app.relapse.predictor import ModelPredictor, RuleBasedPredictor
from app.relapse.service import RiskLevel, predict_relapse_risk

_METADATA_PATH = Path(__file__).resolve().parents[1] / "app" / "relapse" / "model_artifacts" / "metadata.json"

FULL_SLIDERS = dict(
    mood_happy=5,
    mood_excited=5,
    mood_enthusiastic=5,
    mood_contented=5,
    mood_calm=5,
    mood_irritable=5,
    mood_anxious=5,
    mood_stressed=5,
    mood_sad=5,
    mood_bored=5,
)

# Same cases as test_relapse_service.py — proves RuleBasedPredictor is a
# behavior-identical wrapper around predict_relapse_risk, not a rewrite.
CASES = [
    (8, "happy", "other", 1, RiskLevel.HIGH),
    (10, "social", "afterMeal", 1, RiskLevel.HIGH),
    (2, "stressed", "socialPressure", 1, RiskLevel.HIGH),
    (1, "happy", "other", 3, RiskLevel.HIGH),
    (1, "happy", "other", 5, RiskLevel.HIGH),
    (5, "bored", "boredom", 1, RiskLevel.MEDIUM),
    (7, "bored", "other", 2, RiskLevel.MEDIUM),
    (1, "happy", "other", 1, RiskLevel.LOW),
    (4, "sad", "afterMeal", 2, RiskLevel.LOW),
    (7, "stressed", "boredom", 1, RiskLevel.LOW),
    (5, "social", "socialPressure", 1, RiskLevel.LOW),
]


@pytest.mark.parametrize("intensity,mood,trigger,last_24h_count,expected", CASES)
def test_rule_based_predictor_matches_underlying_function(intensity, mood, trigger, last_24h_count, expected):
    predictor = RuleBasedPredictor()
    assert (
        predictor.predict(intensity=intensity, mood=mood, trigger_category=trigger, last_24h_count=last_24h_count)
        == expected
    )


@pytest.mark.parametrize("intensity,mood,trigger,last_24h_count,expected", CASES)
def test_rule_based_predictor_is_identical_to_direct_function_call(intensity, mood, trigger, last_24h_count, expected):
    predictor = RuleBasedPredictor()
    direct = predict_relapse_risk(intensity=intensity, mood=mood, trigger_category=trigger, last_24h_count=last_24h_count)
    via_predictor = predictor.predict(intensity=intensity, mood=mood, trigger_category=trigger, last_24h_count=last_24h_count)
    assert direct == via_predictor == expected


def test_model_predictor_returns_a_real_risk_level():
    predictor = ModelPredictor()
    result = predictor.predict(
        intensity=5,
        mood="happy",
        trigger_category="other",
        last_24h_count=1,
        **FULL_SLIDERS,
    )
    assert isinstance(result, RiskLevel)


@pytest.mark.parametrize(
    "missing_field",
    [
        "mood_happy",
        "mood_excited",
        "mood_enthusiastic",
        "mood_contented",
        "mood_calm",
        "mood_irritable",
        "mood_anxious",
        "mood_stressed",
        "mood_sad",
        "mood_bored",
    ],
)
def test_model_predictor_requires_every_mood_slider_and_does_not_fabricate_a_missing_one(missing_field):
    predictor = ModelPredictor()
    sliders = dict(FULL_SLIDERS)
    sliders[missing_field] = None
    with pytest.raises(ValueError, match=missing_field):
        predictor.predict(intensity=5, mood="happy", trigger_category="other", last_24h_count=1, **sliders)


def test_model_predictor_uses_this_models_own_nested_thresholds_not_the_top_level_ones():
    """Regression test for the top-level-vs-nested threshold mix-up: the
    training run's top-level risk_thresholds belong to full_ema/random_forest
    (0.1704/0.1904), NOT cravinglog_compatible/random_forest (0.0113/0.0225).
    Loading the wrong ones would silently misclassify almost every score."""
    with open(_METADATA_PATH) as f:
        metadata = json.load(f)

    assert metadata["feature_set"] == "cravinglog_compatible"
    assert metadata["model"] == "random_forest"
    assert metadata["thresholds"]["low_threshold"] == 0.0113
    assert metadata["thresholds"]["high_threshold"] == 0.0225

    model = CravingLogCompatibleModel()
    assert model.low_threshold == 0.0113
    assert model.high_threshold == 0.0225


def test_model_predictor_feature_order_matches_training_time_column_order():
    with open(_METADATA_PATH) as f:
        metadata = json.load(f)

    assert metadata["feature_order"] == [
        "craving_imp",
        "happy_imp",
        "excited_imp",
        "enthusiastic_imp",
        "contented_imp",
        "calm_imp",
        "irritable_imp",
        "anxious_imp",
        "stressed_imp",
        "sad_imp",
        "bored_imp",
    ]


@pytest.mark.parametrize(
    "intensity,expected_craving_imp",
    [(1, 0.0), (10, 10.0)],
)
def test_model_predictor_rescales_intensity_onto_emasens_0_to_10_scale_at_the_endpoints(intensity, expected_craving_imp):
    """intensity=1 -> craving_imp=0.0 and intensity=10 -> craving_imp=10.0
    (linear rescale, feature_mapping.py's "trivial rescale, same construct").
    Verified via a fake model that just echoes back the feature dict it
    received, since CravingLogCompatibleModel itself has no public way to
    inspect the vector it built internally."""

    class _CapturingModel:
        feature_order = ["craving_imp"] + [
            "happy_imp",
            "excited_imp",
            "enthusiastic_imp",
            "contented_imp",
            "calm_imp",
            "irritable_imp",
            "anxious_imp",
            "stressed_imp",
            "sad_imp",
            "bored_imp",
        ]
        captured = None

        def predict_risk_level(self, features):
            self.captured = features
            return RiskLevel.LOW

    fake_model = _CapturingModel()
    predictor = ModelPredictor(model=fake_model)
    predictor.predict(intensity=intensity, mood="happy", trigger_category="other", last_24h_count=1, **FULL_SLIDERS)

    assert fake_model.captured["craving_imp"] == pytest.approx(expected_craving_imp)

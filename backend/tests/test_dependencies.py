from app.config import Settings
from app.dependencies import _build_relapse_predictor, get_relapse_predictor
from app.relapse.predictor import CandidatePredictor, RuleBasedPredictor


def test_relapse_predictor_mode_defaults_to_ml():
    assert Settings(_env_file=None).relapse_predictor_mode == "ml"


def test_normal_app_wiring_returns_packaged_ml_predictor():
    assert isinstance(get_relapse_predictor(), CandidatePredictor)


def test_rule_based_mode_remains_available(monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "relapse_predictor_mode", "rule_based")
    assert isinstance(_build_relapse_predictor(), RuleBasedPredictor)

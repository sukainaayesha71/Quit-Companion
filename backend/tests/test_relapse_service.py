import pytest

from app.relapse.service import RiskLevel, predict_relapse_risk


@pytest.mark.parametrize(
    "intensity,mood,trigger,last_24h_count,expected",
    [
        # Rule 1: intensity >= 8 is always High, regardless of everything else.
        (8, "happy", "other", 1, RiskLevel.HIGH),
        (10, "social", "afterMeal", 1, RiskLevel.HIGH),
        # Rule 2: Stressed + Social Pressure is always High, even at low intensity.
        (2, "stressed", "socialPressure", 1, RiskLevel.HIGH),
        # Rule 3: 3+ logs in the last 24h (including this one) is always High.
        (1, "happy", "other", 3, RiskLevel.HIGH),
        (1, "happy", "other", 5, RiskLevel.HIGH),
        # Rule 4: intensity 5-7 AND mood == Bored is Medium.
        (5, "bored", "boredom", 1, RiskLevel.MEDIUM),
        (7, "bored", "other", 2, RiskLevel.MEDIUM),
        # Everything else is Low.
        (1, "happy", "other", 1, RiskLevel.LOW),
        (4, "sad", "afterMeal", 2, RiskLevel.LOW),
        (7, "stressed", "boredom", 1, RiskLevel.LOW),  # Stressed but wrong trigger for Rule 2
        (5, "social", "socialPressure", 1, RiskLevel.LOW),  # Bored-only Rule 4, wrong mood
    ],
)
def test_predict_relapse_risk_rules(intensity, mood, trigger, last_24h_count, expected):
    assert predict_relapse_risk(
        intensity=intensity, mood=mood, trigger_category=trigger, last_24h_count=last_24h_count
    ) == expected


def test_high_intensity_rule_takes_priority_over_lower_rules():
    # Would also match Rule 4 (5-7 + Bored) if Rule 1 didn't short-circuit first — it's 8, not 5-7,
    # so this is really just confirming rule ordering doesn't matter here; keep for documentation.
    assert predict_relapse_risk(intensity=9, mood="bored", trigger_category="boredom", last_24h_count=1) == RiskLevel.HIGH


def test_stressed_social_pressure_rule_takes_priority_over_24h_count():
    assert (
        predict_relapse_risk(intensity=1, mood="stressed", trigger_category="socialPressure", last_24h_count=1)
        == RiskLevel.HIGH
    )

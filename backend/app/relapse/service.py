from enum import Enum


class RiskLevel(str, Enum):
    """FR5: categorical relapse-risk output only — never a numeric score."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


def predict_relapse_risk(*, intensity: int, mood: str, trigger_category: str, last_24h_count: int) -> RiskLevel:
    """Optional SRDS §5.5.1/§5.5.2 deterministic decision table.

    Selected with RELAPSE_PREDICTOR_MODE=rule_based. The active ML pipeline
    is implemented separately in CandidatePredictor.

    Mood/trigger values are the approved Module 3 plan's reconciled
    vocabulary (docs/UI_Design/log craving 6.png): mood one of
    stressed/bored/sad/happy/social, trigger one of
    stress/afterMeal/socialPressure/boredom/other — the SRDS decision
    table's Anxious/Depressed/Neutral/Positive/Motivated mood values don't
    exist in the approved UI and are intentionally not handled here.

    [last_24h_count] is the number of craving logs in the last 24 hours
    *including* the one currently being scored (caller's responsibility —
    see HttpRelapsePredictionClient on the Flutter side).
    """
    if intensity >= 8:
        return RiskLevel.HIGH
    if mood == "stressed" and trigger_category == "socialPressure":
        return RiskLevel.HIGH
    if last_24h_count >= 3:
        return RiskLevel.HIGH
    if 5 <= intensity <= 7 and mood == "bored":
        return RiskLevel.MEDIUM
    return RiskLevel.LOW

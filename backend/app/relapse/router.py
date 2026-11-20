from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator

from ..dependencies import get_relapse_predictor
from ..firebase_auth_dependency import require_firebase_uid
from .predictor import RelapsePredictor, CandidatePredictor
from .service import RiskLevel

router = APIRouter(tags=["relapse"])

Mood = Literal["stressed", "bored", "sad", "happy", "social"]
TriggerCategory = Literal["stress", "afterMeal", "socialPressure", "boredom", "other"]


class PredictRelapseRequest(BaseModel):
    intensity: int = Field(ge=1, le=10)
    mood: Mood
    trigger_category: TriggerCategory
    # Craving logs in the last 24h *including* the one being scored right
    # now — the Flutter client is responsible for that +1 (it queries prior
    # logs via CravingLogRepository before calling this endpoint).
    last_24h_count: int = Field(ge=0)

    # Optional 0-10 answers. ML uses its fitted imputer for omitted values;
    # the explicit rule-based mode ignores these additional fields.
    mood_happy: float | None = Field(default=None, ge=0, le=10)
    mood_excited: float | None = Field(default=None, ge=0, le=10)
    mood_enthusiastic: float | None = Field(default=None, ge=0, le=10)
    mood_contented: float | None = Field(default=None, ge=0, le=10)
    mood_calm: float | None = Field(default=None, ge=0, le=10)
    mood_irritable: float | None = Field(default=None, ge=0, le=10)
    mood_anxious: float | None = Field(default=None, ge=0, le=10)
    mood_stressed: float | None = Field(default=None, ge=0, le=10)
    mood_sad: float | None = Field(default=None, ge=0, le=10)
    mood_bored: float | None = Field(default=None, ge=0, le=10)
    recovery_context: dict[str, float] = Field(default_factory=dict)

    @field_validator("recovery_context")
    @classmethod
    def validate_context(cls, value):
        import math
        if set(value) - {"motivation_imp", "confidence_imp", "pain_imp", "cigarette_availability_imp"}:
            raise ValueError("Unknown recovery check-in field")
        for key, number in value.items():
            if not math.isfinite(number) or not 0 <= number <= 10:
                raise ValueError("Ratings must be finite values from 0 to 10")
            if key == "cigarette_availability_imp" and number not in {1, 2, 3}:
                raise ValueError("Cigarette availability must be 1, 2 or 3")
        return value


class PredictRelapseResponse(BaseModel):
    risk_level: RiskLevel
    assessment_source: str = "rule_based"
    clinically_validated: bool = False
    model_version: str | None = None
    imputed_features: list[str] = Field(default_factory=list)


@router.post("/predict/relapse", response_model=PredictRelapseResponse)
async def predict_relapse(
    body: PredictRelapseRequest,
    uid: str = Depends(require_firebase_uid),
    predictor: RelapsePredictor = Depends(get_relapse_predictor),
) -> PredictRelapseResponse:
    try:
        risk_level = predictor.predict(
            intensity=body.intensity,
            mood=body.mood,
            trigger_category=body.trigger_category,
            last_24h_count=body.last_24h_count,
            mood_happy=body.mood_happy,
            mood_excited=body.mood_excited,
            mood_enthusiastic=body.mood_enthusiastic,
            mood_contented=body.mood_contented,
            mood_calm=body.mood_calm,
            mood_irritable=body.mood_irritable,
            mood_anxious=body.mood_anxious,
            mood_stressed=body.mood_stressed,
            mood_sad=body.mood_sad,
            mood_bored=body.mood_bored,
            **({"recovery_context": body.recovery_context} if isinstance(predictor, CandidatePredictor) else {}),
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    is_ml = isinstance(predictor, CandidatePredictor)
    return PredictRelapseResponse(
        risk_level=risk_level,
        assessment_source="machine_learning" if is_ml else type(predictor).__name__,
        model_version=predictor.model_version if is_ml else None,
        imputed_features=predictor.missing_features(**body.model_dump()) if is_ml else [],
    )

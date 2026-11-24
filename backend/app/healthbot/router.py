from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from ..config import settings
from ..firebase_auth_dependency import require_firebase_uid
from .service import (AnswerSource, AnswerType, FallbackReason, HealthBotUnavailableError, answer_query_with_gemini,
                      EMERGENCY_KEYWORDS, EMERGENCY_RESPONSE_TEXT)
from .review import review_status
from .sources import sources_for_answer

router = APIRouter(tags=["healthbot"])


class HealthBotQueryRequest(BaseModel):
    query: str = Field(min_length=1, max_length=2000)


class HealthBotSource(BaseModel):
    title: str
    url: str


class HealthBotQueryResponse(BaseModel):
    answer_type: AnswerType
    response_text: str
    # Kept for older app builds; `sources` adds display titles.
    source_urls: list[str] = []
    sources: list[HealthBotSource] = []
    medical_review_status: str = "pending"
    # Where response_text came from ("ai", "curated", "safety") and, for a
    # curated fallback, why ("timeout", "unavailable"). The app labels
    # non-AI answers from these; response_text carries no technical prefix.
    answer_source: AnswerSource = AnswerSource.CURATED
    fallback_reason: FallbackReason | None = None


@router.post("/healthbot/query", response_model=HealthBotQueryResponse)
async def query_healthbot(
    body: HealthBotQueryRequest,
    uid: str = Depends(require_firebase_uid),
) -> HealthBotQueryResponse:
    reviewed = review_status(settings.clinical_review_record)
    if any(keyword in body.query.lower() for keyword in EMERGENCY_KEYWORDS):
        return HealthBotQueryResponse(answer_type=AnswerType.EMERGENCY, response_text=EMERGENCY_RESPONSE_TEXT,
                                      answer_source=AnswerSource.SAFETY)
    if settings.require_clinical_review and reviewed != "approved_catalogue":
        raise HTTPException(503, "Health guidance is awaiting clinical-advisor review.")
    try:
        answer = await answer_query_with_gemini(
            body.query,
            api_key=settings.gemini_api_key,
            model=settings.gemini_model,
            timeout_seconds=settings.healthbot_gemini_timeout_seconds,
        )
    except HealthBotUnavailableError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error
    # FR8: topic-specific sources for in-scope answers only (none for
    # emergencies or refusals/out-of-scope replies).
    sources = sources_for_answer(body.query, answer.type)
    return HealthBotQueryResponse(
        answer_type=answer.type,
        response_text=answer.response_text,
        source_urls=[source.url for source in sources],
        sources=[HealthBotSource(title=source.title, url=source.url) for source in sources],
        medical_review_status=reviewed,
        answer_source=answer.source,
        fallback_reason=answer.fallback_reason,
    )

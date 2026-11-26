from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from ..config import settings
from ..firebase_auth_dependency import require_firebase_uid
from .service import (AnswerSource, AnswerType, ConversationTurn, FallbackReason, HealthBotAnswer,
                      HealthBotUnavailableError, UserContext, answer_query_with_gemini,
                      EMERGENCY_KEYWORDS, EMERGENCY_RESPONSE_TEXT)
from .review import review_status
from .sources import TrustedSource, sources_for_answer

router = APIRouter(tags=["healthbot"])


class HealthBotTurn(BaseModel):
    """An earlier chat message, so follow-up questions are understood."""

    role: Literal["user", "assistant"]
    text: str = Field(min_length=1, max_length=4000)


class HealthBotUserContext(BaseModel):
    """Optional, non-identifying profile details for personalised replies."""

    # Plain strings, so a value a newer app adds never rejects the chat;
    # the service ignores values it doesn't recognise.
    product: str | None = Field(default=None, max_length=40)
    days_since_quit: int | None = None
    quit_strategy: str | None = Field(default=None, max_length=40)


class HealthBotQueryRequest(BaseModel):
    query: str = Field(min_length=1, max_length=2000)
    # Both optional: older app builds send only `query`.
    history: list[HealthBotTurn] = Field(default_factory=list, max_length=20)
    user_context: HealthBotUserContext | None = None


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


def _answer_sources(query: str, answer: HealthBotAnswer) -> tuple[TrustedSource, ...]:
    """FR8: sources for in-scope answers only (none for emergencies or
    refusals/out-of-scope replies). When the answer reports which knowledge
    notes it used, their sources are shown; a chat reply that used none
    (a greeting, a general question) shows none."""
    if answer.type != AnswerType.MATCHED:
        return ()
    if answer.source_ids is None:
        return sources_for_answer(query, answer.type)
    from .knowledge import entry_by_id

    found: dict[str, TrustedSource] = {}
    for entry_id in answer.source_ids:
        entry = entry_by_id(entry_id)
        for source in entry.sources if entry else ():
            found.setdefault(source.url, source)
    return tuple(found.values())[:4]


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
    extra: dict[str, object] = {}
    if body.history:
        extra["history"] = tuple(ConversationTurn(role=turn.role, text=turn.text) for turn in body.history)
    if body.user_context is not None:
        extra["user_context"] = UserContext(
            product=body.user_context.product,
            days_since_quit=body.user_context.days_since_quit,
            quit_strategy=body.user_context.quit_strategy,
        )
    try:
        answer = await answer_query_with_gemini(
            body.query,
            api_key=settings.gemini_api_key,
            model=settings.gemini_model,
            timeout_seconds=settings.healthbot_gemini_timeout_seconds,
            **extra,
        )
    except HealthBotUnavailableError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error
    sources = _answer_sources(body.query, answer)
    return HealthBotQueryResponse(
        answer_type=answer.type,
        response_text=answer.response_text,
        source_urls=[source.url for source in sources],
        sources=[HealthBotSource(title=source.title, url=source.url) for source in sources],
        medical_review_status=reviewed,
        answer_source=answer.source,
        fallback_reason=answer.fallback_reason,
    )

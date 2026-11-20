from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from ..config import settings
from ..firebase_auth_dependency import require_firebase_uid
from .service import AnswerType, HealthBotUnavailableError, answer_query_with_gemini, EMERGENCY_KEYWORDS, EMERGENCY_RESPONSE_TEXT
from .review import review_status

router = APIRouter(tags=["healthbot"])


class HealthBotQueryRequest(BaseModel):
    query: str = Field(min_length=1, max_length=2000)


class HealthBotQueryResponse(BaseModel):
    answer_type: AnswerType
    response_text: str
    source_urls: list[str] = []
    medical_review_status: str = "pending"


@router.post("/healthbot/query", response_model=HealthBotQueryResponse)
async def query_healthbot(
    body: HealthBotQueryRequest,
    uid: str = Depends(require_firebase_uid),
) -> HealthBotQueryResponse:
    reviewed = review_status(settings.clinical_review_record)
    if any(keyword in body.query.lower() for keyword in EMERGENCY_KEYWORDS):
        return HealthBotQueryResponse(answer_type=AnswerType.EMERGENCY, response_text=EMERGENCY_RESPONSE_TEXT)
    if settings.require_clinical_review and reviewed != "approved_catalogue":
        raise HTTPException(503, "Health guidance is awaiting clinical-advisor review.")
    try:
        answer = await answer_query_with_gemini(
            body.query,
            api_key=settings.gemini_api_key,
            model=settings.gemini_model,
        )
    except HealthBotUnavailableError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error
    return HealthBotQueryResponse(answer_type=answer.type, response_text=answer.response_text,
        source_urls=[] if answer.type == AnswerType.EMERGENCY else [
            "https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/tips-for-quitting/index.html",
            "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet"],
        medical_review_status=reviewed)

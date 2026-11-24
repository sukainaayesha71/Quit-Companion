from typing import Literal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

from ..config import settings
from ..firebase_auth_dependency import require_firebase_uid
from ..dependencies import get_firebase_identity_provider
from .service import generate_plan, rank_actions
from ..healthbot.review import review_status

router = APIRouter(tags=["coaching"])


class CoachingContext:
    def database(self):
        from firebase_admin import firestore
        provider = get_firebase_identity_provider()
        return firestore.client(app=provider._ensure_app())

    def read(self, uid: str) -> dict:
        user = self.database().collection("nicotineUsers").document(uid)
        return {"profile": user.get().to_dict() or {},
                "attempts": [doc.to_dict() for doc in user.collection("habitAlternativeAttempts").order_by("attemptedAt", direction="DESCENDING").limit(500).stream()],
                "cravings": [doc.to_dict() for doc in user.collection("cravingLogs").order_by("timestamp", direction="DESCENDING").limit(100).stream()],
                "usage": [doc.to_dict() for doc in user.collection("usageLogs").order_by("date", direction="DESCENDING").limit(100).stream()]}

    def read_attempts(self, uid: str) -> list[dict]:
        """Step 13: /recommend/alternative ranks attempts only, so it reads just
        that one collection instead of all four datasets read() loads."""
        user = self.database().collection("nicotineUsers").document(uid)
        return [doc.to_dict() for doc in user.collection("habitAlternativeAttempts")
                .order_by("attemptedAt", direction="DESCENDING").limit(500).stream()]

    def save_plan(self, uid: str, kind: str, plan: dict):
        self.database().collection("nicotineUsers").document(uid).collection("generatedPlans").document(kind).set(plan)


def get_coaching_context() -> CoachingContext:
    return CoachingContext()


class CoachingRequest(BaseModel):
    trigger_category: Literal["stress", "afterMeal", "socialPressure", "boredom", "other"] = "other"
    mood: Literal["stressed", "bored", "sad", "happy", "social"] = "happy"


@router.post("/recommend/alternative")
async def recommend(body: CoachingRequest, uid: str = Depends(require_firebase_uid), context: CoachingContext = Depends(get_coaching_context)):
    if settings.require_clinical_review and review_status(settings.clinical_review_record) != "approved_catalogue":
        raise HTTPException(503, "Coaching content is awaiting clinical-advisor review.")
    try:
        read_attempts = getattr(context, "read_attempts", None)
        attempts = (await run_in_threadpool(read_attempts, uid) if read_attempts
                    else (await run_in_threadpool(context.read, uid))["attempts"])
    except Exception as exc:
        raise HTTPException(503, "Could not load your coaching history.") from exc
    return {"recommendations": rank_actions(attempts, body.trigger_category, body.mood)[:5],
            "model": "contextual_beta_bernoulli", "medical_review_status": "pending"}


@router.post("/plans/{kind}")
async def plan(kind: Literal["initial", "weekly", "restart"], body: CoachingRequest,
               uid: str = Depends(require_firebase_uid), context: CoachingContext = Depends(get_coaching_context)):
    reviewed = review_status(settings.clinical_review_record)
    if settings.require_clinical_review and reviewed != "approved_catalogue":
        raise HTTPException(503, "Coaching content is awaiting clinical-advisor review.")
    try:
        data = await run_in_threadpool(context.read, uid)
        result = await generate_plan(data, kind, body.trigger_category, body.mood,
                                     api_key=settings.gemini_api_key, model=settings.gemini_model)
        result["medical_review_status"] = reviewed
        await run_in_threadpool(context.save_plan, uid, kind, result)
        return result
    except Exception as exc:
        raise HTTPException(503, "Could not generate and save your plan. Please try again.") from exc

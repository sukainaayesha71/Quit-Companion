import hmac
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field, model_validator
from starlette.concurrency import run_in_threadpool
from ..coaching.router import get_coaching_context, CoachingContext

from ..firebase_auth_dependency import require_firebase_uid
from ..config import settings
from ..dependencies import get_fcm_notification_service
from .service import (
    FcmNotificationService,
    NotificationDeliveryError,
    NotificationEventType,
    ScheduledNotificationType,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])


class NotificationDeliveryResponse(BaseModel):
    targeted: int
    succeeded: int
    removed_invalid_tokens: int


class ReminderScheduleRequest(BaseModel):
    enabled: bool
    timezone: str = Field(min_length=1, max_length=80)
    dailyTimes: list[str] = Field(default_factory=list, max_length=5)
    habitEnabled: bool = False
    recoveryEnabled: bool = False

    @model_validator(mode="after")
    def validate_schedule(self):
        from zoneinfo import ZoneInfo
        import re
        try: ZoneInfo(self.timezone)
        except Exception as exc: raise ValueError("Use a valid IANA timezone") from exc
        if self.enabled and not 3 <= len(self.dailyTimes) <= 5:
            raise ValueError("Choose 3 to 5 daily prompts")
        if len(set(self.dailyTimes)) != len(self.dailyTimes): raise ValueError("Duplicate reminder times")
        if any(not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", value) for value in self.dailyTimes):
            raise ValueError("Use valid HH:MM reminder times")
        return self


@router.put("/schedule")
async def save_reminder_schedule(body: ReminderScheduleRequest, uid: str = Depends(require_firebase_uid),
                                 context: CoachingContext = Depends(get_coaching_context)):
    from datetime import datetime, timezone
    try:
        def save():
            context.database().collection("nicotineUsers").document(uid).collection("reminderSchedules").document("daily").set(
                {**body.model_dump(), "updatedAt": datetime.now(timezone.utc)})
        await run_in_threadpool(save)
    except Exception as exc:
        raise HTTPException(503, "Could not save your push reminder schedule.") from exc
    return {"saved": True}


@router.post("/send/{notification_type}", response_model=NotificationDeliveryResponse)
def send_notification(
    notification_type: ScheduledNotificationType,
    scheduler_token: Annotated[str | None, Header(alias="X-Scheduler-Token")] = None,
    service: FcmNotificationService = Depends(get_fcm_notification_service),
) -> NotificationDeliveryResponse:
    expected_token = settings.fcm_scheduler_token
    if not expected_token:
        raise HTTPException(status_code=503, detail="Notification sender is not configured.")
    if scheduler_token is None or not hmac.compare_digest(scheduler_token, expected_token):
        raise HTTPException(status_code=401, detail="Not authorized.")
    try:
        result = service.send(notification_type)
    except NotificationDeliveryError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return NotificationDeliveryResponse(
        targeted=result.targeted,
        succeeded=result.succeeded,
        removed_invalid_tokens=result.removed_invalid_tokens,
    )


@router.post("/events/{notification_type}", response_model=NotificationDeliveryResponse)
def send_user_event_notification(
    notification_type: NotificationEventType,
    user_id: str = Depends(require_firebase_uid),
    service: FcmNotificationService = Depends(get_fcm_notification_service),
) -> NotificationDeliveryResponse:
    if not settings.firebase_service_account_json:
        raise HTTPException(
            status_code=503, detail="Firebase Admin authentication is not configured."
        )
    try:
        result = service.send_to_user(user_id, notification_type)
    except NotificationDeliveryError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return NotificationDeliveryResponse(
        targeted=result.targeted,
        succeeded=result.succeeded,
        removed_invalid_tokens=result.removed_invalid_tokens,
    )

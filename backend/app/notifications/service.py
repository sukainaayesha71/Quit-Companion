from dataclasses import dataclass
from typing import Literal

from ..config import Settings

NotificationType = Literal[
    "daily_checkin",
    "habit_reminder",
    "recovery_motivation",
    "badge_earned",
    "restart_plan",
    "alternative_feedback",
]
NotificationEventType = Literal["badge_earned", "restart_plan", "alternative_feedback"]
ScheduledNotificationType = Literal[
    "daily_checkin",
    "habit_reminder",
    "recovery_motivation",
]

_MESSAGES: dict[NotificationType, tuple[str, str]] = {
    "alternative_feedback": ("How did your activity go?", "Open your activity history and record whether it helped with the craving."),
    "daily_checkin": (
        "How are you feeling?",
        "Take a moment to log your craving, mood, or context.",
    ),
    "habit_reminder": (
        "Try a healthy alternative",
        "A short walk or breathing exercise can help you ride out an urge.",
    ),
    "recovery_motivation": (
        "Your recovery is worth celebrating",
        "Every nicotine-free day is progress. Notice how far you have come.",
    ),
    "badge_earned": (
        "You earned a new milestone",
        "Open Quit Companion to celebrate your progress.",
    ),
    "restart_plan": (
        "Your restart plan is ready",
        "Recovery is not linear. Open the app to review your next steps.",
    ),
}


class NotificationDeliveryError(Exception):
    pass


@dataclass(frozen=True)
class NotificationDeliveryResult:
    targeted: int
    succeeded: int
    removed_invalid_tokens: int


class FcmNotificationService:
    """Sends only fixed, reviewed notification copy to opted-in FCM tokens."""

    def __init__(self, settings: Settings):
        self._settings = settings
        self._app = None

    def send(self, notification_type: NotificationType) -> NotificationDeliveryResult:
        if notification_type not in _MESSAGES:
            raise ValueError(f"Unsupported notification type: {notification_type}")
        if notification_type in {"badge_earned", "restart_plan", "alternative_feedback"}:
            raise ValueError("Event notifications must be sent to a single user.")

        firebase_admin, credentials, firestore, messaging = self._firebase_modules()
        app = self._firebase_app(firebase_admin, credentials)
        try:
            db = firestore.client(app=app)
            docs = list(
                db.collection_group("fcmTokens")
                .where("notificationTypes", "array_contains", notification_type)
                .stream()
            )
        except Exception as exc:
            raise NotificationDeliveryError("Could not read opted-in notification tokens.") from exc

        return self._deliver_docs(docs, notification_type, messaging, app)

    def send_to_user(
        self, user_id: str, notification_type: NotificationEventType
    ) -> NotificationDeliveryResult:
        if notification_type not in {"badge_earned", "restart_plan", "alternative_feedback"}:
            raise ValueError("Only event notifications can be sent to a user.")

        return self._send_user(user_id, notification_type)

    def send_scheduled_to_user(self, user_id: str, notification_type: ScheduledNotificationType) -> NotificationDeliveryResult:
        if notification_type not in {"daily_checkin", "habit_reminder", "recovery_motivation"}:
            raise ValueError("Unsupported scheduled notification")
        return self._send_user(user_id, notification_type)

    def _send_user(self, user_id: str, notification_type: NotificationType) -> NotificationDeliveryResult:
        firebase_admin, credentials, firestore, messaging = self._firebase_modules()
        app = self._firebase_app(firebase_admin, credentials)
        category = notification_type if notification_type in {"habit_reminder", "recovery_motivation"} else "daily_checkin"
        try:
            db = firestore.client(app=app)
            docs = list(
                db.collection("nicotineUsers")
                .document(user_id)
                .collection("fcmTokens")
                .where("notificationTypes", "array_contains", category)
                .stream()
            )
        except Exception as exc:
            raise NotificationDeliveryError(
                "Could not read this user's opted-in notification tokens."
            ) from exc

        return self._deliver_docs(docs, notification_type, messaging, app)

    def _deliver_docs(self, docs, notification_type, messaging, app):
        tokens = [
            (doc, (doc.to_dict() or {}).get("token")) for doc in docs
        ]
        tokens = [(doc, token) for doc, token in tokens if isinstance(token, str) and token]
        if not tokens:
            return NotificationDeliveryResult(0, 0, 0)

        title, body = _MESSAGES[notification_type]
        succeeded = 0
        invalid_docs = []
        for offset in range(0, len(tokens), 500):
            batch = tokens[offset : offset + 500]
            message = messaging.MulticastMessage(
                tokens=[token for _, token in batch],
                notification=messaging.Notification(title=title, body=body),
                data={"type": notification_type},
            )
            try:
                response = messaging.send_each_for_multicast(message, app=app)
            except Exception as exc:
                raise NotificationDeliveryError("Firebase Cloud Messaging send failed.") from exc
            succeeded += response.success_count
            for (doc, _), result in zip(batch, response.responses):
                if not result.success and _is_unregistered(result.exception):
                    invalid_docs.append(doc)

        removed = 0
        for doc in invalid_docs:
            try:
                doc.reference.delete()
                removed += 1
            except Exception as exc:
                raise NotificationDeliveryError("Could not remove an expired FCM token.") from exc

        return NotificationDeliveryResult(len(tokens), succeeded, removed)

    def _firebase_modules(self):
        if not self._settings.firebase_service_account_json:
            raise NotificationDeliveryError("Firebase Admin SDK is not configured.")
        import firebase_admin
        from firebase_admin import credentials, firestore, messaging

        return firebase_admin, credentials, firestore, messaging

    def _firebase_app(self, firebase_admin, credentials):
        if self._app is not None:
            return self._app
        try:
            self._app = firebase_admin.get_app("quit-companion-fcm")
        except ValueError:
            try:
                credential = credentials.Certificate(
                    self._settings.firebase_service_account_json
                )
                self._app = firebase_admin.initialize_app(
                    credential, name="quit-companion-fcm"
                )
            except Exception as exc:
                raise NotificationDeliveryError(
                    "Firebase Admin SDK is not configured correctly."
                ) from exc
        return self._app


def _is_unregistered(error: Exception | None) -> bool:
    return getattr(error, "code", None) in {
        "messaging/registration-token-not-registered",
        "messaging/invalid-registration-token",
    }

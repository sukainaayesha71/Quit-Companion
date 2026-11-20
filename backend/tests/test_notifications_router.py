from fastapi.testclient import TestClient

from app.config import settings
from app.dependencies import get_fcm_notification_service
from app.notifications.service import NotificationDeliveryResult


class _FakeFcmNotificationService:
    def __init__(self):
        self.sent = []
        self.user_events = []

    def send(self, notification_type):
        self.sent.append(notification_type)
        return NotificationDeliveryResult(
            targeted=3,
            succeeded=2,
            removed_invalid_tokens=1,
        )

    def send_to_user(self, user_id, notification_type):
        self.user_events.append((user_id, notification_type))
        return NotificationDeliveryResult(
            targeted=1,
            succeeded=1,
            removed_invalid_tokens=0,
        )


def test_notification_sender_requires_scheduler_token(client: TestClient, monkeypatch):
    monkeypatch.setattr(settings, "fcm_scheduler_token", "scheduler-secret")

    response = client.post("/notifications/send/daily_checkin")

    assert response.status_code == 401


def test_notification_sender_dispatches_only_with_valid_token(
    client: TestClient, monkeypatch
):
    service = _FakeFcmNotificationService()
    monkeypatch.setattr(settings, "fcm_scheduler_token", "scheduler-secret")
    client.app.dependency_overrides[get_fcm_notification_service] = lambda: service

    response = client.post(
        "/notifications/send/daily_checkin",
        headers={"X-Scheduler-Token": "scheduler-secret"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "targeted": 3,
        "succeeded": 2,
        "removed_invalid_tokens": 1,
    }
    assert service.sent == ["daily_checkin"]


def test_event_notification_uses_authenticated_user_and_targets_only_their_tokens(
    client: TestClient, firebase_identity, monkeypatch
):
    service = _FakeFcmNotificationService()
    firebase_identity.valid_tokens["firebase-id-token"] = "user-123"
    monkeypatch.setattr(settings, "firebase_service_account_json", "configured.json")
    client.app.dependency_overrides[get_fcm_notification_service] = lambda: service

    response = client.post(
        "/notifications/events/badge_earned",
        headers={"Authorization": "Bearer firebase-id-token"},
    )

    assert response.status_code == 200
    assert response.json() == {
        "targeted": 1,
        "succeeded": 1,
        "removed_invalid_tokens": 0,
    }
    assert service.user_events == [("user-123", "badge_earned")]


def test_event_notification_rejects_missing_or_invalid_firebase_identity(
    client: TestClient, monkeypatch
):
    monkeypatch.setattr(settings, "firebase_service_account_json", "configured.json")

    response = client.post("/notifications/events/restart_plan")

    assert response.status_code == 401


def test_notification_sender_is_disabled_without_server_secret(
    client: TestClient, monkeypatch
):
    monkeypatch.setattr(settings, "fcm_scheduler_token", None)

    response = client.post(
        "/notifications/send/daily_checkin",
        headers={"X-Scheduler-Token": "anything"},
    )

    assert response.status_code == 503


def test_unknown_notification_type_is_rejected(client: TestClient, monkeypatch):
    monkeypatch.setattr(settings, "fcm_scheduler_token", "scheduler-secret")

    response = client.post(
        "/notifications/send/free_form",
        headers={"X-Scheduler-Token": "scheduler-secret"},
    )

    assert response.status_code == 422


def test_event_notification_cannot_be_broadcast_by_scheduler(client: TestClient, monkeypatch):
    monkeypatch.setattr(settings, "fcm_scheduler_token", "scheduler-secret")

    response = client.post(
        "/notifications/send/restart_plan",
        headers={"X-Scheduler-Token": "scheduler-secret"},
    )

    assert response.status_code == 422

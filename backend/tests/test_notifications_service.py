from types import SimpleNamespace

from app.notifications.service import (
    FcmNotificationService,
    NotificationDeliveryResult,
)


class _FakeQuery:
    def __init__(self, documents):
        self.documents = documents
        self.filters = []

    def where(self, field, operator, value):
        self.filters.append((field, operator, value))
        return self

    def stream(self):
        return self.documents


class _FakeDocument:
    def __init__(self, token):
        self.token = token
        self.reference = SimpleNamespace(delete=lambda: None)

    def to_dict(self):
        return {"token": self.token}


def test_event_send_queries_only_the_user_opted_in_tokens(monkeypatch):
    documents = [_FakeDocument("device-token")]
    query = _FakeQuery(documents)
    paths = []

    class _Collection:
        def __init__(self, path):
            self.path = path

        def document(self, user_id):
            paths.append(("document", self.path, user_id))
            return self

        def collection(self, name):
            paths.append(("collection", name))
            return query

    db = SimpleNamespace(collection=lambda name: _Collection(name))
    firestore = SimpleNamespace(client=lambda app: db)
    sent_messages = []

    class _Messaging:
        class Notification:
            def __init__(self, title, body):
                self.title = title
                self.body = body

        class MulticastMessage:
            def __init__(self, tokens, notification, data):
                self.tokens = tokens
                self.notification = notification
                self.data = data

        @staticmethod
        def send_each_for_multicast(message, app):
            sent_messages.append(message)
            return SimpleNamespace(
                success_count=1,
                responses=[SimpleNamespace(success=True, exception=None)],
            )

    service = FcmNotificationService(SimpleNamespace())
    app = object()
    monkeypatch.setattr(
        service,
        "_firebase_modules",
        lambda: (None, None, firestore, _Messaging),
    )
    monkeypatch.setattr(service, "_firebase_app", lambda *_: app)

    result = service.send_to_user("user-123", "badge_earned")

    assert result == NotificationDeliveryResult(1, 1, 0)
    assert paths == [
        ("document", "nicotineUsers", "user-123"),
        ("collection", "fcmTokens"),
    ]
    assert query.filters == [
        ("notificationTypes", "array_contains", "daily_checkin")
    ]
    assert sent_messages[0].tokens == ["device-token"]
    assert sent_messages[0].data == {"type": "badge_earned"}

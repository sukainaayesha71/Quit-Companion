"""Background worker (Step 12): scheduled FCM delivery, leases/receipts,
pending risk assessments, activity-feedback prompts, error isolation and the
heartbeat. Uses in-memory fakes — no Firestore, no FCM, no network."""
from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

import pytest

from app import worker as worker_module
from app.notifications.service import NotificationDeliveryResult
from app.relapse.predictor import RuleBasedPredictor
from app.worker import Worker, poll_interval_seconds, write_heartbeat


# --- in-memory Firestore fakes ---------------------------------------------


class FakeDoc:
    def __init__(self, data=None, parent_uid="u1"):
        self.data = dict(data or {})
        self.reference = FakeRef(self, parent_uid)

    def to_dict(self):
        return dict(self.data)


class FakeRef:
    def __init__(self, doc, uid):
        self._doc = doc
        self.parent = type("P", (), {"parent": type("U", (), {"id": uid})()})()
        self.subcollections: dict[str, dict[str, FakeDoc]] = {}
        self.updates: list[dict] = []

    def collection(self, name):
        return FakeSubcollection(self.subcollections.setdefault(name, {}))

    def update(self, values):
        self.updates.append(values)
        self._doc.data.update(values)


class FakeSubcollection:
    def __init__(self, store):
        self.store = store

    def document(self, doc_id):
        return FakeReceipt(self.store, doc_id)


class FakeReceipt:
    def __init__(self, store, doc_id):
        self.store, self.id = store, doc_id

    def set(self, values, merge=False):
        current = self.store.get(self.id, {}) if merge else {}
        self.store[self.id] = {**current, **values}


class FakeQuery:
    def __init__(self, docs):
        self.docs = docs

    def where(self, *args, **kwargs):
        return self

    def limit(self, n):
        return FakeQuery(self.docs[:n])

    def stream(self):
        return iter(self.docs)


class FakeDb:
    def __init__(self, groups=None, user_logs=None):
        self.groups = groups or {}
        self.user_logs = user_logs or []

    def collection_group(self, name):
        return FakeQuery(self.groups.get(name, []))

    def collection(self, name):
        db = self

        class Users:
            def document(self, uid):
                class User:
                    def collection(self, sub):
                        return FakeQuery(db.user_logs)
                return User()
        return Users()


class FakeSender:
    def __init__(self, succeeded=1, fail=False):
        self.succeeded, self.fail = succeeded, fail
        self.scheduled, self.events = [], []

    def send_scheduled_to_user(self, uid, kind):
        if self.fail:
            raise RuntimeError("FCM down")
        self.scheduled.append((uid, kind))
        return NotificationDeliveryResult(1, self.succeeded, 0)

    def send_to_user(self, uid, kind):
        if self.fail:
            raise RuntimeError("FCM down")
        self.events.append((uid, kind))
        return NotificationDeliveryResult(1, self.succeeded, 0)


@pytest.fixture
def leases(monkeypatch):
    """Replace the Firestore transaction with the same lease semantics."""
    def claim(self, reference, now):
        data = reference.store.get(reference.id, {})
        if data.get("sent") or data.get("leaseUntil", now) > now:
            return None
        reference.set({"leaseUntil": now + timedelta(minutes=3), "leaseId": "x"}, merge=True)
        return "x"
    monkeypatch.setattr(Worker, "_claim", claim)


NOW = datetime(2026, 11, 23, 10, 0, 20, tzinfo=timezone.utc)
SCHEDULE = {"enabled": True, "timezone": "UTC", "dailyTimes": ["10:00", "14:00", "19:00"],
            "habitEnabled": True, "recoveryEnabled": False}


def make_worker(db, sender=None, predictor=None, notifications=True):
    return Worker(db=db, sender=sender or FakeSender(),
                  predictor=predictor or RuleBasedPredictor(), notifications=notifications)


# --- scheduled FCM delivery --------------------------------------------------


def test_due_daily_checkin_is_sent_once_and_receipted(leases):
    schedule = FakeDoc(SCHEDULE)
    sender = FakeSender()
    worker = make_worker(FakeDb({"reminderSchedules": [schedule]}), sender)

    worker.scheduled_notifications(NOW)
    worker.scheduled_notifications(NOW + timedelta(seconds=20))  # next pass, same slot

    assert sender.scheduled == [("u1", "daily_checkin")]
    receipt = schedule.reference.subcollections["deliveryReceipts"]["2026-11-23_1000_daily_checkin"]
    assert receipt["sent"] is True


def test_nothing_is_sent_outside_a_slot_or_when_disabled(leases):
    sender = FakeSender()
    worker = make_worker(FakeDb({"reminderSchedules": [FakeDoc({**SCHEDULE, "enabled": False}),
                                                      FakeDoc(SCHEDULE)]}), sender)
    worker.scheduled_notifications(NOW.replace(minute=7))
    assert sender.scheduled == []


def test_failed_delivery_releases_the_lease_for_a_retry(leases):
    schedule = FakeDoc(SCHEDULE)
    sender = FakeSender(succeeded=0)
    worker = make_worker(FakeDb({"reminderSchedules": [schedule]}), sender)

    worker.scheduled_notifications(NOW)
    receipt = schedule.reference.subcollections["deliveryReceipts"]["2026-11-23_1000_daily_checkin"]
    assert not receipt.get("sent")
    sender.succeeded = 1
    worker.scheduled_notifications(NOW + timedelta(seconds=15))

    assert len(sender.scheduled) == 2
    receipts = schedule.reference.subcollections["deliveryReceipts"]
    assert receipts["2026-11-23_1000_daily_checkin"]["sent"] is True


def test_one_bad_schedule_does_not_stop_the_others(leases):
    bad = FakeDoc({"enabled": True, "timezone": "Not/AZone", "dailyTimes": ["10:00"] * 3})
    good = FakeDoc(SCHEDULE, parent_uid="u2")
    sender = FakeSender()
    make_worker(FakeDb({"reminderSchedules": [bad, good]}), sender).scheduled_notifications(NOW)
    assert sender.scheduled == [("u2", "daily_checkin")]


def test_fcm_outage_is_logged_with_type_not_content(leases, caplog):
    sender = FakeSender(fail=True)
    make_worker(FakeDb({"reminderSchedules": [FakeDoc(SCHEDULE)]}), sender).scheduled_notifications(NOW)
    assert "Scheduled delivery failed (RuntimeError)" in caplog.text


# --- pending risk assessments ------------------------------------------------


def _pending_log(**extra):
    return FakeDoc({"timestamp": "2026-11-23T09:00:00", "cravingIntensity": 9, "mood": "stressed",
                    "triggerCategory": "stress", "riskAssessmentPending": True,
                    "relapseRiskScore": "medium", **extra})


def test_pending_assessment_is_scored_and_labelled():
    log = _pending_log()
    db = FakeDb({"cravingLogs": [log]}, user_logs=[object(), object(), object()])
    make_worker(db).pending_assessments()

    update = log.reference.updates[-1]
    assert update["riskAssessmentPending"] is False
    assert update["assessmentSource"] == "rule_based"
    assert update["relapseRiskScore"] in {"low", "medium", "high"}


def test_unscorable_assessment_stays_pending_without_crashing(caplog):
    broken = _pending_log(cravingIntensity="not a number")
    good = _pending_log()
    make_worker(FakeDb({"cravingLogs": [broken, good]})).pending_assessments()

    assert broken.reference.updates == []
    assert good.reference.updates
    assert "Pending assessment deferred" in caplog.text


# --- activity feedback prompts ----------------------------------------------


def test_feedback_prompt_sent_once_between_5_minutes_and_24_hours(leases):
    recent = FakeDoc({"attemptedAt": (NOW - timedelta(minutes=10)).isoformat(), "outcomeHelped": None})
    too_new = FakeDoc({"attemptedAt": (NOW - timedelta(minutes=2)).isoformat(), "outcomeHelped": None})
    too_old = FakeDoc({"attemptedAt": (NOW - timedelta(days=2)).isoformat(), "outcomeHelped": None})
    sender = FakeSender()
    worker = make_worker(FakeDb({"habitAlternativeAttempts": [recent, too_new, too_old]}), sender)

    worker.feedback_prompts(NOW)
    worker.feedback_prompts(NOW + timedelta(seconds=30))

    assert sender.events == [("u1", "alternative_feedback")]
    assert "feedbackPromptedAt" in recent.data


# --- tick, modes, heartbeat --------------------------------------------------


def test_assessments_only_mode_sends_no_notifications(leases):
    sender = FakeSender()
    log = _pending_log()
    db = FakeDb({"reminderSchedules": [FakeDoc(SCHEDULE)], "cravingLogs": [log]})
    worker = make_worker(db, sender, notifications=False)
    worker.tick()
    assert sender.scheduled == [] and sender.events == []
    assert log.reference.updates


def test_poll_interval_is_clamped_below_the_60s_slot_window(monkeypatch):
    for configured, expected in [(1, 5), (30, 30), (300, 45)]:
        monkeypatch.setattr(worker_module.settings, "worker_poll_seconds", configured)
        assert poll_interval_seconds() == expected


def test_heartbeat_file_is_written(tmp_path):
    path = tmp_path / "hb"
    write_heartbeat(str(path))
    assert path.exists()
    assert datetime.fromisoformat(path.read_text()).tzinfo is not None


def test_compose_worker_healthcheck_uses_the_same_heartbeat_file():
    compose = (os.path.dirname(__file__) + "/../../deploy/compose.yaml")
    text = open(compose, encoding="utf-8").read()
    assert worker_module.HEARTBEAT_FILE in text
    assert "disable: true" not in text.split("worker:")[1].split("proxy:")[0]

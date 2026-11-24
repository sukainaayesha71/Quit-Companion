"""Trusted background jobs. Run one or more replicas; Firestore leases prevent overlap.

Daily delivery is opt-in and timezone-aware. Late daily prompts are not replayed
as a burst after downtime. FCM is at-least-once; transport latency is monitored,
not guaranteed by an application timer.
"""
from datetime import datetime, timedelta, timezone
import logging
import time
from uuid import uuid4
from zoneinfo import ZoneInfo

from .config import settings
from .coaching.router import CoachingContext
from .dependencies import get_fcm_notification_service, get_relapse_predictor
from .relapse.predictor import CandidatePredictor, RuleBasedPredictor

logger = logging.getLogger(__name__)


def assessment_source(predictor) -> str:
    """Label stored with a re-scored craving: what actually scored it, not
    what was configured (the API may have fallen back to rule-based if the
    ML artifact failed to load)."""
    if isinstance(predictor, CandidatePredictor):
        return "machine_learning"
    if isinstance(predictor, RuleBasedPredictor):
        return "rule_based"
    return settings.relapse_predictor_mode


def due_slots(schedule: dict, now: datetime) -> list[tuple[str, str]]:
    if not schedule.get("enabled"): return []
    local = now.astimezone(ZoneInfo(schedule["timezone"]))
    times = schedule.get("dailyTimes", [])
    if not 3 <= len(times) <= 5 or len(set(times)) != len(times):
        raise ValueError("Daily frequency must be 3 to 5 distinct times")
    candidates = [(value, "daily_checkin") for value in times]
    if schedule.get("habitEnabled"): candidates.append(("11:00", "habit_reminder"))
    if schedule.get("recoveryEnabled"): candidates.append(("18:00", "recovery_motivation"))
    due = []
    for value, kind in candidates:
        hour, minute = map(int, value.split(":"))
        target = local.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if 0 <= (local - target).total_seconds() < 60:
            due.append((f"{local.date()}_{hour:02}{minute:02}_{kind}", kind))
    return due


class Worker:
    def __init__(self, db=None, sender=None, predictor=None, notifications=True):
        self.db = db if db is not None else CoachingContext().database()
        self.sender = sender if sender is not None else get_fcm_notification_service()
        self.predictor = predictor if predictor is not None else get_relapse_predictor()
        self.notifications = notifications

    def _claim(self, reference, now):
        from firebase_admin import firestore
        lease_id = uuid4().hex
        @firestore.transactional
        def claim(transaction):
            data = reference.get(transaction=transaction).to_dict() or {}
            if data.get("sent") or data.get("leaseUntil", now) > now: return None
            transaction.set(reference, {"leaseUntil": now + timedelta(minutes=3), "leaseId": lease_id}, merge=True)
            return lease_id
        return claim(self.db.transaction())

    def scheduled_notifications(self, now):
        for doc in self.db.collection_group("reminderSchedules").where("enabled", "==", True).stream():
            try:
                for delivery_id, kind in due_slots(doc.to_dict(), now):
                    receipt = doc.reference.collection("deliveryReceipts").document(delivery_id)
                    lease = self._claim(receipt, now)
                    if not lease: continue
                    uid = doc.reference.parent.parent.id
                    result = self.sender.send_scheduled_to_user(uid, kind)
                    if result.succeeded:
                        receipt.set({"sent": True, "sentAt": now, "succeeded": result.succeeded}, merge=True)
                    else:
                        receipt.set({"leaseUntil": now}, merge=True)
            except Exception as error:
                logger.warning("Scheduled delivery failed (%s); no user content logged", type(error).__name__)

    def pending_assessments(self):
        for doc in self.db.collection_group("cravingLogs").where("riskAssessmentPending", "==", True).limit(100).stream():
            try:
                data = doc.to_dict()
                uid = doc.reference.parent.parent.id
                timestamp = datetime.fromisoformat(data["timestamp"])
                recent = self.db.collection("nicotineUsers").document(uid).collection("cravingLogs")
                count = sum(1 for _ in recent.where("timestamp", ">=", (timestamp - timedelta(hours=24)).isoformat())
                            .where("timestamp", "<=", data["timestamp"]).stream())
                sliders = {"mood_" + key[4:].lower(): data.get(key) for key in (
                    "moodHappy", "moodExcited", "moodEnthusiastic", "moodContented", "moodCalm",
                    "moodIrritable", "moodAnxious", "moodStressed", "moodSad", "moodBored")}
                inputs = dict(intensity=data["cravingIntensity"], mood=data["mood"],
                    trigger_category=data["triggerCategory"], last_24h_count=count, **sliders,
                    **({"recovery_context": data.get("recoveryContext", {})} if isinstance(self.predictor, CandidatePredictor) else {}))
                risk = self.predictor.predict(**inputs)
                result = {"relapseRiskScore": risk.value, "riskAssessmentPending": False,
                          "assessmentSource": assessment_source(self.predictor)}
                if isinstance(self.predictor, CandidatePredictor):
                    result.update(assessmentSource="machine_learning",
                                  modelVersion=self.predictor.model_version,
                                  imputedFeatures=self.predictor.missing_features(**inputs),
                                  clinicallyValidated=False)
                doc.reference.update(result)
            except Exception as error:
                logger.warning("Pending assessment deferred (%s); no user content logged", type(error).__name__)

    def feedback_prompts(self, now):
        for doc in self.db.collection_group("habitAlternativeAttempts").where("outcomeHelped", "==", None).limit(200).stream():
            try:
                data = doc.to_dict()
                attempted = datetime.fromisoformat(data["attemptedAt"])
                if attempted.tzinfo is None: attempted = attempted.replace(tzinfo=timezone.utc)
                age = (now - attempted).total_seconds()
                if not 300 <= age < 24 * 3600 or data.get("feedbackPromptedAt"): continue
                receipt = doc.reference.collection("deliveryReceipts").document("feedback")
                if not self._claim(receipt, now): continue
                result = self.sender.send_to_user(doc.reference.parent.parent.id, "alternative_feedback")
                if result.succeeded:
                    doc.reference.update({"feedbackPromptedAt": now})
                    receipt.set({"sent": True, "sentAt": now}, merge=True)
            except Exception as error:
                logger.warning("Activity feedback prompt deferred (%s)", type(error).__name__)

    def tick(self):
        now = datetime.now(timezone.utc)
        if self.notifications:
            self.scheduled_notifications(now)
            self.feedback_prompts(now)
        self.pending_assessments()


#: Touched after every pass; deploy/compose.yaml's worker healthcheck
#: treats a stale file as unhealthy (Step 12).
HEARTBEAT_FILE = "/tmp/quit-companion-worker.heartbeat"


def poll_interval_seconds() -> int:
    """Clamped to 5-45 s: due_slots() matches a reminder within a 60 s
    window, so passes must stay under a minute apart."""
    return max(5, min(settings.worker_poll_seconds, 45))


def write_heartbeat(path: str = HEARTBEAT_FILE) -> None:
    try:
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(datetime.now(timezone.utc).isoformat())
    except OSError as error:
        logger.warning("Could not write worker heartbeat (%s)", type(error).__name__)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--assessments-only', action='store_true')
    parser.add_argument('--heartbeat-file', default=HEARTBEAT_FILE)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    worker = Worker(notifications=not args.assessments_only)
    logger.info("Worker started (notifications=%s, poll=%ss)", worker.notifications, poll_interval_seconds())
    while True:
        started = time.monotonic()
        try:
            worker.tick()
        except Exception as error:
            logger.warning("Background job pass failed (%s); retrying", type(error).__name__)
        write_heartbeat(args.heartbeat_file)
        time.sleep(max(1, poll_interval_seconds() - (time.monotonic() - started)))


if __name__ == "__main__": main()

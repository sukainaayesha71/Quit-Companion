"""Opt-in prospective research export. Never includes contact details or free text.

Set a protected RESEARCH_PSEUDONYM_KEY (>=32 characters) and run manually.
Do not schedule exports without a documented research/data-retention protocol.
"""
import csv
import hashlib
import hmac
import os
from pathlib import Path
from app.coaching.router import CoachingContext


def main():
    key = os.environ.get("RESEARCH_PSEUDONYM_KEY", "")
    if len(key) < 32: raise ValueError("Set a protected research pseudonym key of at least 32 characters")
    db = CoachingContext().database()
    rows = []
    for user in db.collection("nicotineUsers").where("researchConsent", "==", True).stream():
        profile = user.to_dict()
        pseudonym = hmac.new(key.encode(), user.id.encode(), hashlib.sha256).hexdigest()
        logs = [doc.to_dict() for doc in user.reference.collection("cravingLogs").order_by("timestamp").stream()]
        for current, following in zip(logs, logs[1:]):
            outcome = following.get("nicotineUsedSinceLastCheckin")
            if not isinstance(outcome, bool): continue
            # Preserve the real irregular interval: no fixed-horizon label claim.
            row = {"participant_id": pseudonym, "product_type": profile.get("productType"),
                "timestamp": current["timestamp"], "outcome_observed_at": following["timestamp"],
                "next_observed_interval_nicotine_use": int(outcome), "intensity": current["cravingIntensity"]}
            for field in ["moodHappy", "moodExcited", "moodEnthusiastic", "moodContented", "moodCalm", "moodIrritable", "moodAnxious", "moodStressed", "moodSad", "moodBored"]:
                row[field] = current.get(field)
            for field in ["motivation_imp", "confidence_imp", "pain_imp", "cigarette_availability_imp"]:
                row[field] = current.get("recoveryContext", {}).get(field)
            rows.append(row)
    output = Path(__file__).parent / "data/app"
    output.mkdir(parents=True, exist_ok=True)
    if rows:
        with (output / "prospective_checkins.csv").open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    print(f"Exported {len(rows)} opted-in labeled intervals; no names, emails, chat or notes included.")


if __name__ == "__main__": main()

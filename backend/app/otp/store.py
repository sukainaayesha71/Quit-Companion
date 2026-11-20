import time
from dataclasses import dataclass, field


@dataclass
class OtpRecord:
    phone_number: str
    otp_hash: str
    salt: str
    expires_at: float
    attempts: int = 0
    created_at: float = field(default_factory=time.time)
    last_sent_at: float = field(default_factory=time.time)


class OtpStore:
    """In-memory OTP store, keyed by normalized phone number.

    Single-process only — a multi-instance deployment needs a shared store
    (Redis/Firestore) instead. Kept behind this narrow interface so that
    swap is a one-file change later; not implemented now since no such
    infra is provisioned for this project yet.
    """

    def __init__(self) -> None:
        self._records: dict[str, OtpRecord] = {}

    def get(self, phone_number: str) -> OtpRecord | None:
        return self._records.get(phone_number)

    def put(self, record: OtpRecord) -> None:
        self._records[record.phone_number] = record

    def delete(self, phone_number: str) -> None:
        self._records.pop(phone_number, None)

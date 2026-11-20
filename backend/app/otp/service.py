import hashlib
import hmac
import secrets
import time

from ..config import Settings
from .store import OtpRecord, OtpStore

_DIGITS = "0123456789"


class OtpError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def generate_otp(length: int) -> str:
    """Cryptographically secure, uniformly-distributed numeric code."""
    return "".join(secrets.choice(_DIGITS) for _ in range(length))


def _hash_otp(otp: str, salt: str) -> str:
    return hashlib.sha256((salt + otp).encode("utf-8")).hexdigest()


class OtpService:
    """Generation, storage, expiry, attempt-limiting and cooldown for phone
    OTPs. Never returns/stores the plaintext OTP once request_otp() hands
    it to the caller — only a salted hash is kept."""

    def __init__(self, store: OtpStore, settings: Settings):
        self._store = store
        self._settings = settings

    def request_otp(self, phone_number: str) -> str:
        """Generates and stores a fresh OTP, returning the plaintext value
        for the caller to deliver via WhatsApp. Raises OtpError(429) if
        called again before the resend cooldown elapses."""
        existing = self._store.get(phone_number)
        now = time.time()
        if existing is not None:
            elapsed = now - existing.last_sent_at
            if elapsed < self._settings.otp_resend_cooldown_seconds:
                wait_seconds = int(self._settings.otp_resend_cooldown_seconds - elapsed) + 1
                raise OtpError(f"Please wait {wait_seconds}s before requesting another code.", status_code=429)

        otp = generate_otp(self._settings.otp_length)
        salt = secrets.token_hex(16)
        record = OtpRecord(
            phone_number=phone_number,
            otp_hash=_hash_otp(otp, salt),
            salt=salt,
            expires_at=now + self._settings.otp_expiry_seconds,
            attempts=0,
            created_at=now,
            last_sent_at=now,
        )
        self._store.put(record)
        return otp

    def discard(self, phone_number: str) -> None:
        """Used when OTP delivery itself fails, so the user isn't stuck in
        a cooldown for a code they never received."""
        self._store.delete(phone_number)

    def verify_otp(self, phone_number: str, submitted_otp: str) -> None:
        """Raises OtpError on any failure; returns normally on success and
        consumes the OTP (single use)."""
        record = self._store.get(phone_number)
        if record is None:
            raise OtpError("Invalid or expired verification code.", status_code=400)

        now = time.time()
        if now > record.expires_at:
            self._store.delete(phone_number)
            raise OtpError("Invalid or expired verification code.", status_code=400)

        if record.attempts >= self._settings.otp_max_verify_attempts:
            self._store.delete(phone_number)
            raise OtpError("Too many incorrect attempts. Please request a new code.", status_code=429)

        expected_hash = _hash_otp(submitted_otp, record.salt)
        if not hmac.compare_digest(expected_hash, record.otp_hash):
            record.attempts += 1
            self._store.put(record)
            raise OtpError("Invalid or expired verification code.", status_code=400)

        # Success — single use.
        self._store.delete(phone_number)

import time

import pytest

from app.config import Settings
from app.otp.service import OtpError, OtpService, generate_otp
from app.otp.store import OtpStore

PHONE = "+923001234567"


def test_generate_otp_is_correct_length_and_digits_only():
    otp = generate_otp(6)
    assert len(otp) == 6
    assert otp.isdigit()


def test_generate_otp_is_not_trivially_predictable():
    # Not a rigorous randomness test — just guards against a constant/fake generator.
    samples = {generate_otp(6) for _ in range(20)}
    assert len(samples) > 1


def test_correct_otp_verifies_successfully(otp_service: OtpService):
    otp = otp_service.request_otp(PHONE)
    otp_service.verify_otp(PHONE, otp)  # must not raise


def test_otp_is_single_use(otp_service: OtpService):
    otp = otp_service.request_otp(PHONE)
    otp_service.verify_otp(PHONE, otp)

    with pytest.raises(OtpError) as exc_info:
        otp_service.verify_otp(PHONE, otp)
    assert exc_info.value.status_code == 400


def test_incorrect_otp_is_rejected(otp_service: OtpService):
    otp_service.request_otp(PHONE)

    with pytest.raises(OtpError) as exc_info:
        otp_service.verify_otp(PHONE, "000000")
    assert "Invalid or expired" in exc_info.value.message
    assert exc_info.value.status_code == 400


def test_verify_without_prior_send_is_rejected(otp_service: OtpService):
    with pytest.raises(OtpError) as exc_info:
        otp_service.verify_otp(PHONE, "123456")
    assert "Invalid or expired" in exc_info.value.message


def test_expired_otp_is_rejected():
    settings = Settings(otp_expiry_seconds=1, otp_resend_cooldown_seconds=0)
    service = OtpService(OtpStore(), settings)
    otp = service.request_otp(PHONE)

    time.sleep(1.2)

    with pytest.raises(OtpError) as exc_info:
        service.verify_otp(PHONE, otp)
    assert "Invalid or expired" in exc_info.value.message


def test_max_verification_attempts_locks_out(otp_service: OtpService):
    settings = Settings(otp_max_verify_attempts=3, otp_resend_cooldown_seconds=0)
    service = OtpService(OtpStore(), settings)
    otp = service.request_otp(PHONE)

    for _ in range(3):
        with pytest.raises(OtpError):
            service.verify_otp(PHONE, "000000")

    # Even the correct code is now rejected — record was purged after max attempts.
    with pytest.raises(OtpError) as exc_info:
        service.verify_otp(PHONE, otp)
    assert exc_info.value.status_code in (400, 429)


def test_resend_cooldown_blocks_immediate_repeat_requests():
    settings = Settings(otp_resend_cooldown_seconds=30)
    service = OtpService(OtpStore(), settings)
    service.request_otp(PHONE)

    with pytest.raises(OtpError) as exc_info:
        service.request_otp(PHONE)
    assert exc_info.value.status_code == 429


def test_resend_after_cooldown_issues_a_new_otp_and_invalidates_the_old_one():
    settings = Settings(otp_resend_cooldown_seconds=1, otp_expiry_seconds=300)
    service = OtpService(OtpStore(), settings)
    first_otp = service.request_otp(PHONE)

    time.sleep(1.2)
    second_otp = service.request_otp(PHONE)

    assert first_otp != second_otp
    with pytest.raises(OtpError):
        service.verify_otp(PHONE, first_otp)
    service.verify_otp(PHONE, second_otp)  # must not raise


def test_discard_clears_pending_otp_and_lifts_cooldown():
    settings = Settings(otp_resend_cooldown_seconds=30)
    service = OtpService(OtpStore(), settings)
    service.request_otp(PHONE)

    service.discard(PHONE)

    # No longer blocked by the cooldown from the discarded request.
    service.request_otp(PHONE)  # must not raise

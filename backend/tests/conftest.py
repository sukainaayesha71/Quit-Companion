import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.dependencies import get_firebase_identity_provider, get_otp_service, get_whatsapp_client, get_relapse_predictor
from app.fake_firebase_identity import FakeFirebaseIdentityProvider
from app.main import app
from app.otp.service import OtpService
from app.otp.store import OtpStore
from app.whatsapp.fake_client import FakeWhatsAppClient


@pytest.fixture
def fast_settings() -> Settings:
    """Short cooldown/expiry so tests don't need to sleep for real durations."""
    return Settings(
        otp_length=6,
        otp_expiry_seconds=300,
        otp_resend_cooldown_seconds=30,
        otp_max_verify_attempts=5,
    )


@pytest.fixture
def otp_service(fast_settings: Settings) -> OtpService:
    return OtpService(OtpStore(), fast_settings)


@pytest.fixture
def whatsapp_client() -> FakeWhatsAppClient:
    return FakeWhatsAppClient()


@pytest.fixture
def firebase_identity() -> FakeFirebaseIdentityProvider:
    return FakeFirebaseIdentityProvider()


@pytest.fixture
def client(otp_service, whatsapp_client, firebase_identity) -> TestClient:
    from app.relapse.predictor import RuleBasedPredictor
    app.dependency_overrides[get_relapse_predictor] = lambda: RuleBasedPredictor()
    app.dependency_overrides[get_otp_service] = lambda: otp_service
    app.dependency_overrides[get_whatsapp_client] = lambda: whatsapp_client
    app.dependency_overrides[get_firebase_identity_provider] = lambda: firebase_identity
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()

from fastapi.testclient import TestClient

from app.fake_firebase_identity import FakeFirebaseIdentityProvider
from app.whatsapp.fake_client import FakeWhatsAppClient


def test_send_otp_normalizes_and_accepts_a_valid_number(client: TestClient, whatsapp_client: FakeWhatsAppClient):
    response = client.post("/auth/phone/send-otp", json={"phone_number": "+92 335 123 4567"})

    assert response.status_code == 200
    assert whatsapp_client.sent[0][0] == "+923351234567"  # normalized before delivery


def test_send_otp_rejects_an_invalid_phone_number(client: TestClient):
    response = client.post("/auth/phone/send-otp", json={"phone_number": "not-a-number"})

    assert response.status_code == 400
    assert "valid phone number" in response.json()["detail"]


def test_send_otp_surfaces_whatsapp_failure_without_leaking_internals(
    client: TestClient, whatsapp_client: FakeWhatsAppClient
):
    whatsapp_client.should_fail = True

    response = client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})

    assert response.status_code == 502
    detail = response.json()["detail"]
    assert "try again" in detail.lower()
    assert "simulated" not in detail.lower()  # internal exception text must not leak


def test_send_otp_failure_does_not_leave_a_lingering_cooldown(
    client: TestClient, whatsapp_client: FakeWhatsAppClient
):
    whatsapp_client.should_fail = True
    client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})

    whatsapp_client.should_fail = False
    retry = client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})

    assert retry.status_code == 200


def test_duplicate_otp_requests_are_rate_limited(client: TestClient):
    first = client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})
    second = client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})

    assert first.status_code == 200
    assert second.status_code == 429


def test_full_flow_verifies_successfully_and_returns_a_firebase_token(
    client: TestClient, whatsapp_client: FakeWhatsAppClient, firebase_identity: FakeFirebaseIdentityProvider
):
    client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})
    _, otp = whatsapp_client.sent[0]

    response = client.post("/auth/phone/verify-otp", json={"phone_number": "+923001234567", "otp": otp})

    assert response.status_code == 200
    assert response.json()["firebase_token"] == "fake-custom-token-for-+923001234567"
    assert firebase_identity.minted_for == ["+923001234567"]


def test_verify_otp_rejects_incorrect_code(client: TestClient, whatsapp_client: FakeWhatsAppClient):
    client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})

    response = client.post("/auth/phone/verify-otp", json={"phone_number": "+923001234567", "otp": "000000"})

    assert response.status_code == 400


def test_verify_otp_rejects_invalid_phone_number(client: TestClient):
    response = client.post("/auth/phone/verify-otp", json={"phone_number": "bad", "otp": "123456"})

    assert response.status_code == 400
    assert "valid phone number" in response.json()["detail"]


def test_verify_otp_surfaces_firebase_admin_failure_without_leaking_internals(
    client: TestClient, whatsapp_client: FakeWhatsAppClient, firebase_identity: FakeFirebaseIdentityProvider
):
    client.post("/auth/phone/send-otp", json={"phone_number": "+923001234567"})
    _, otp = whatsapp_client.sent[0]
    firebase_identity.should_fail = True

    response = client.post("/auth/phone/verify-otp", json={"phone_number": "+923001234567", "otp": otp})

    assert response.status_code == 500
    detail = response.json()["detail"]
    assert "try again" in detail.lower()
    assert "simulated" not in detail.lower()

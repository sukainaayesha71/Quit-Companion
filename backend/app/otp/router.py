from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from ..firebase_identity import FirebaseIdentityError, FirebaseIdentityProvider
from .service import OtpError, OtpService
from ..phone import is_valid_e164, normalize_phone_number
from ..whatsapp.client import WhatsAppClient, WhatsAppSendError
from ..dependencies import get_firebase_identity_provider, get_otp_service, get_whatsapp_client

router = APIRouter(prefix="/auth/phone", tags=["phone-auth"])

_INVALID_PHONE_DETAIL = "Enter a valid phone number in international format (e.g. +14155552671)."


class SendOtpRequest(BaseModel):
    phone_number: str


class SendOtpResponse(BaseModel):
    message: str


class VerifyOtpRequest(BaseModel):
    phone_number: str
    otp: str


class VerifyOtpResponse(BaseModel):
    firebase_token: str


@router.post("/send-otp", response_model=SendOtpResponse)
async def send_otp(
    body: SendOtpRequest,
    otp_service: OtpService = Depends(get_otp_service),
    whatsapp_client: WhatsAppClient = Depends(get_whatsapp_client),
) -> SendOtpResponse:
    phone_number = normalize_phone_number(body.phone_number)
    if not is_valid_e164(phone_number):
        raise HTTPException(status_code=400, detail=_INVALID_PHONE_DETAIL)

    try:
        otp = otp_service.request_otp(phone_number)
    except OtpError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc

    try:
        await whatsapp_client.send_otp(phone_number, otp)
    except WhatsAppSendError as exc:
        # Delivery failed — don't leave the user stuck in a cooldown for a
        # code they never received.
        otp_service.discard(phone_number)
        raise HTTPException(
            status_code=502, detail="Could not send verification code. Please try again."
        ) from exc

    return SendOtpResponse(message="Verification code sent.")


@router.post("/verify-otp", response_model=VerifyOtpResponse)
async def verify_otp(
    body: VerifyOtpRequest,
    otp_service: OtpService = Depends(get_otp_service),
    firebase_identity: FirebaseIdentityProvider = Depends(get_firebase_identity_provider),
) -> VerifyOtpResponse:
    phone_number = normalize_phone_number(body.phone_number)
    if not is_valid_e164(phone_number):
        raise HTTPException(status_code=400, detail=_INVALID_PHONE_DETAIL)

    try:
        otp_service.verify_otp(phone_number, body.otp.strip())
    except OtpError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc

    try:
        token = firebase_identity.mint_custom_token_for_phone(phone_number)
    except FirebaseIdentityError as exc:
        raise HTTPException(
            status_code=500, detail="Could not complete sign-in. Please try again."
        ) from exc

    return VerifyOtpResponse(firebase_token=token)

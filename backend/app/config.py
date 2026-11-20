from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All values are read from environment variables (optionally via a local
    .env file, never committed — see .env.example). Nothing here is a
    working credential; unset WhatsApp/Firebase values simply mean those
    integrations raise a clear "not configured" error when actually used."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # WhatsApp Business Platform / Meta Cloud API
    whatsapp_access_token: str | None = None
    whatsapp_phone_number_id: str | None = None
    whatsapp_business_account_id: str | None = None
    whatsapp_api_version: str = "v27.0"
    whatsapp_otp_template_name: str = "otp_verification"
    whatsapp_otp_template_language: str = "en_US"

    # Firebase Admin SDK — path to a service account JSON key file.
    firebase_service_account_json: str | None = None

    # Server-only Gemini API credentials for AI-generated Health-Bot replies.
    # Never expose these values through the mobile app or a client response.
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-3.5-flash-lite"
    clinical_review_record: str | None = None
    require_clinical_review: bool = False
    worker_poll_seconds: int = 30

    # Cloud Scheduler-to-FastAPI shared secret for fixed-catalogue FCM sends.
    # Must be set only in the backend's secret manager/environment.
    fcm_scheduler_token: str | None = None

    # OTP policy
    otp_length: int = 6
    otp_expiry_seconds: int = 300
    otp_resend_cooldown_seconds: int = 30
    otp_max_verify_attempts: int = 5

    # "ml" runs the packaged experimental XGBoost pipeline. "rule_based"
    # remains an explicit alternative. Legacy "model" is the old research RF.
    relapse_predictor_mode: Literal["rule_based", "model", "candidate", "ml"] = "ml"


settings = Settings()

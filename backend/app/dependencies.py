import logging

from .config import settings
from .account_deletion.service import FirebaseAccountDeletionService
from .firebase_identity import AdminSdkFirebaseIdentityProvider, FirebaseIdentityProvider
from .otp.service import OtpService
from .otp.store import OtpStore
from .notifications.service import FcmNotificationService
from .relapse.predictor import CandidatePredictor, ModelPredictor, RelapsePredictor, RuleBasedPredictor
from .whatsapp.client import WhatsAppClient
from .whatsapp.meta_client import MetaWhatsAppClient

logger = logging.getLogger(__name__)


def _build_relapse_predictor() -> RelapsePredictor:
    if settings.relapse_predictor_mode in {"ml", "candidate"}:
        logger.warning("Research candidate enabled; independent clinical/app-population validation is outstanding.")
        return CandidatePredictor()
    if settings.relapse_predictor_mode == "model":
        logger.warning(
            "RELAPSE_PREDICTOR_MODE=model is active: this is a research-preview "
            "path (ROC-AUC ~0.50 on held-out data, chance level, not clinically "
            "validated - see backend/app/relapse/model_artifacts/metadata.json). "
            "It must never be enabled for real users."
        )
        return ModelPredictor()
    return RuleBasedPredictor()


# Process-wide singletons. Overridden in tests via FastAPI's
# app.dependency_overrides — see tests/conftest.py.
_otp_store = OtpStore()
_otp_service = OtpService(_otp_store, settings)
_whatsapp_client: WhatsAppClient = MetaWhatsAppClient(settings)
_firebase_identity_provider: FirebaseIdentityProvider = AdminSdkFirebaseIdentityProvider(settings)
_relapse_predictor: RelapsePredictor = _build_relapse_predictor()
_fcm_notification_service = FcmNotificationService(settings)
_account_deletion_service = FirebaseAccountDeletionService(settings)


def get_otp_service() -> OtpService:
    return _otp_service


def get_whatsapp_client() -> WhatsAppClient:
    return _whatsapp_client


def get_firebase_identity_provider() -> FirebaseIdentityProvider:
    return _firebase_identity_provider


def get_relapse_predictor() -> RelapsePredictor:
    return _relapse_predictor


def get_fcm_notification_service() -> FcmNotificationService:
    return _fcm_notification_service


def get_account_deletion_service() -> FirebaseAccountDeletionService:
    return _account_deletion_service

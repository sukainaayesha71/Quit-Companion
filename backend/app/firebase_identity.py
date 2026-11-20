from abc import ABC, abstractmethod

from .config import Settings


class FirebaseIdentityError(Exception):
    """Raised for any failure establishing/minting the Firebase identity.
    Callers must surface only a generic message — never leak Admin SDK
    internals to the HTTP client."""


class FirebaseIdentityProvider(ABC):
    @abstractmethod
    def mint_custom_token_for_phone(self, phone_number: str) -> str: ...

    @abstractmethod
    def verify_id_token(self, id_token: str) -> str:
        """Verifies a Firebase ID token (minted client-side after sign-in)
        and returns its uid. Raises FirebaseIdentityError on any invalid,
        expired, or unverifiable token."""


class AdminSdkFirebaseIdentityProvider(FirebaseIdentityProvider):
    """Wraps the Firebase Admin SDK: looks up (or creates) a *real* Firebase
    user for a WhatsApp-verified phone number, then mints a genuine signed
    custom token for that exact uid. This never fabricates a uid or a
    session — signInWithCustomToken() on the client establishes a real
    Firebase Auth session against this token, same as any other sign-in
    method in this app.
    """

    def __init__(self, settings: Settings):
        self._settings = settings
        self._app = None

    def _ensure_app(self):
        if self._app is not None:
            return self._app
        if not self._settings.firebase_service_account_json:
            raise FirebaseIdentityError("Firebase Admin SDK is not configured.")
        # Imported lazily so the firebase_admin package (and its credential
        # file requirement) is only touched when this path actually runs —
        # keeps the rest of the app importable/testable without it.
        import firebase_admin
        from firebase_admin import credentials

        try:
            cred = credentials.Certificate(self._settings.firebase_service_account_json)
            self._app = firebase_admin.initialize_app(cred, name="quit-companion-otp")
        except Exception as exc:  # bad path, malformed JSON, or other credential-load failure
            raise FirebaseIdentityError("Firebase Admin SDK is not configured correctly.") from exc
        return self._app

    def mint_custom_token_for_phone(self, phone_number: str) -> str:
        if not self._settings.firebase_service_account_json:
            raise FirebaseIdentityError("Firebase Admin SDK is not configured.")
        from firebase_admin import auth as fb_auth

        app = self._ensure_app()
        try:
            user = fb_auth.get_user_by_phone_number(phone_number, app=app)
        except fb_auth.UserNotFoundError:
            user = fb_auth.create_user(phone_number=phone_number, app=app)
        except Exception as exc:  # Admin SDK/network/credential errors
            raise FirebaseIdentityError("Could not resolve Firebase identity.") from exc

        try:
            token = fb_auth.create_custom_token(user.uid, app=app)
        except Exception as exc:
            raise FirebaseIdentityError("Could not mint Firebase sign-in token.") from exc

        return token.decode("utf-8") if isinstance(token, bytes) else token

    def verify_id_token(self, id_token: str) -> str:
        if not self._settings.firebase_service_account_json:
            raise FirebaseIdentityError("Firebase Admin SDK is not configured.")
        from firebase_admin import auth as fb_auth

        app = self._ensure_app()
        try:
            decoded = fb_auth.verify_id_token(id_token, app=app)
        except Exception as exc:  # expired/invalid/malformed token, Admin SDK/network errors
            raise FirebaseIdentityError("Could not verify Firebase ID token.") from exc
        return decoded["uid"]

from fastapi import Depends, Header, HTTPException

from .dependencies import get_firebase_identity_provider
from .firebase_identity import FirebaseIdentityError, FirebaseIdentityProvider


def require_firebase_uid(
    authorization: str | None = Header(default=None),
    provider: FirebaseIdentityProvider = Depends(get_firebase_identity_provider),
) -> str:
    """Gate for endpoints that must reject anonymous requests (e.g.
    /predict/relapse). Expects `Authorization: Bearer <Firebase ID token>`,
    the token Flutter already has from its existing FirebaseAuth session —
    no new sign-in flow. Returns the verified uid; raises 401 on a missing
    header, a malformed header, or a token that fails verification."""
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or malformed Authorization header.")

    id_token = authorization.removeprefix("Bearer ").strip()
    if not id_token:
        raise HTTPException(status_code=401, detail="Missing or malformed Authorization header.")

    try:
        return provider.verify_id_token(id_token)
    except FirebaseIdentityError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase ID token.") from exc

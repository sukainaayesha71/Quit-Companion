from fastapi import APIRouter, Depends, HTTPException, Response, status

from .service import (
    AccountDeletionError,
    FirebaseAccountDeletionService,
)
from ..dependencies import get_account_deletion_service
from ..firebase_auth_dependency import require_firebase_uid

router = APIRouter(prefix="/account", tags=["account"])


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    user_id: str = Depends(require_firebase_uid),
    service: FirebaseAccountDeletionService = Depends(
        get_account_deletion_service
    ),
) -> Response:
    try:
        service.delete_account(user_id)
    except AccountDeletionError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)

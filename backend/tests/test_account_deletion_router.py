from app.account_deletion.service import (
    AccountDeletionError,
)
from app.dependencies import get_account_deletion_service
from app.fake_firebase_identity import FakeFirebaseIdentityProvider
from app.main import app


class FakeAccountDeletionService:
    def __init__(self):
        self.deleted_user_ids = []
        self.fail = False

    def delete_account(self, user_id: str) -> None:
        if self.fail:
            raise AccountDeletionError("Could not delete the account's data.")
        self.deleted_user_ids.append(user_id)


def test_delete_account_requires_firebase_authentication(client):
    service = FakeAccountDeletionService()
    app.dependency_overrides[get_account_deletion_service] = lambda: service
    response = client.delete("/account")

    assert response.status_code == 401
    assert service.deleted_user_ids == []


def test_delete_account_deletes_only_the_authenticated_user(
    client, firebase_identity: FakeFirebaseIdentityProvider
):
    service = FakeAccountDeletionService()
    firebase_identity.valid_tokens["firebase-id-token"] = "user-123"
    app.dependency_overrides[get_account_deletion_service] = lambda: service
    response = client.delete(
        "/account", headers={"Authorization": "Bearer firebase-id-token"}
    )

    assert response.status_code == 204
    assert response.content == b""
    assert service.deleted_user_ids == ["user-123"]


def test_delete_account_surfaces_deletion_failure(
    client, firebase_identity: FakeFirebaseIdentityProvider
):
    service = FakeAccountDeletionService()
    service.fail = True
    firebase_identity.valid_tokens["firebase-id-token"] = "user-123"
    app.dependency_overrides[get_account_deletion_service] = lambda: service
    response = client.delete(
        "/account", headers={"Authorization": "Bearer firebase-id-token"}
    )

    assert response.status_code == 503
    assert response.json()["detail"] == "Could not delete the account's data."

import pytest
from app.config import Settings
from app.firebase_identity import AdminSdkFirebaseIdentityProvider, FirebaseIdentityError


@pytest.mark.parametrize("token", ["dev-token", "forged-user", "e30.eyJzdWIiOiJhZG1pbiJ9.fake"])
def test_missing_credentials_never_accept_unverified_identity(token):
    provider = AdminSdkFirebaseIdentityProvider(Settings(_env_file=None, firebase_service_account_json=None))
    with pytest.raises(FirebaseIdentityError):
        provider.verify_id_token(token)


def test_missing_credentials_never_mint_development_token():
    provider = AdminSdkFirebaseIdentityProvider(Settings(_env_file=None, firebase_service_account_json=None))
    with pytest.raises(FirebaseIdentityError):
        provider.mint_custom_token_for_phone("+923001234567")

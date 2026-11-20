from .firebase_identity import FirebaseIdentityError, FirebaseIdentityProvider


class FakeFirebaseIdentityProvider(FirebaseIdentityProvider):
    """Test double — never touches the real Firebase Admin SDK."""

    def __init__(self, should_fail: bool = False):
        self.should_fail = should_fail
        self.minted_for: list[str] = []
        # Tests populate this directly: token string -> uid it should resolve to.
        self.valid_tokens: dict[str, str] = {}

    def mint_custom_token_for_phone(self, phone_number: str) -> str:
        if self.should_fail:
            raise FirebaseIdentityError("Simulated Firebase Admin failure.")
        self.minted_for.append(phone_number)
        return f"fake-custom-token-for-{phone_number}"

    def verify_id_token(self, id_token: str) -> str:
        if self.should_fail or id_token not in self.valid_tokens:
            raise FirebaseIdentityError("Simulated invalid Firebase ID token.")
        return self.valid_tokens[id_token]

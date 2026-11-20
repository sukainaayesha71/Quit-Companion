from .client import WhatsAppClient, WhatsAppSendError


class FakeWhatsAppClient(WhatsAppClient):
    """Test double — never makes a network call. `sent` is test-only
    bookkeeping; production code must never log this kind of pairing."""

    def __init__(self, should_fail: bool = False):
        self.should_fail = should_fail
        self.sent: list[tuple[str, str]] = []

    async def send_otp(self, phone_number: str, otp: str) -> None:
        if self.should_fail:
            raise WhatsAppSendError("Simulated WhatsApp API failure.")
        self.sent.append((phone_number, otp))

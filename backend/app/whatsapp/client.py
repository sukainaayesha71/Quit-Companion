from abc import ABC, abstractmethod


class WhatsAppSendError(Exception):
    """Raised for any failure sending a WhatsApp OTP message. Callers must
    surface only a generic message to end users — never Meta's raw error
    body, which may include account/config details."""


class WhatsAppClient(ABC):
    @abstractmethod
    async def send_otp(self, phone_number: str, otp: str) -> None: ...

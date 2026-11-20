import httpx

from ..config import Settings
from .client import WhatsAppClient, WhatsAppSendError


class MetaWhatsAppClient(WhatsAppClient):
    """Sends OTPs via the official WhatsApp Business Platform (Meta Cloud
    API), using an approved authentication message template rather than a
    free-form message — Meta requires this for OTP/auth use cases.

    Configure an authentication template with a copy-code button. The same
    OTP is supplied in the message body and button parameter.
    """

    def __init__(self, settings: Settings, http_client: httpx.AsyncClient | None = None):
        self._settings = settings
        self._http_client = http_client or httpx.AsyncClient(timeout=10.0)

    async def send_otp(self, phone_number: str, otp: str) -> None:
        if not self._settings.whatsapp_access_token or not self._settings.whatsapp_phone_number_id:
            raise WhatsAppSendError("WhatsApp Business Platform is not configured.")

        url = (
            f"https://graph.facebook.com/{self._settings.whatsapp_api_version}"
            f"/{self._settings.whatsapp_phone_number_id}/messages"
        )
        # Meta's Cloud API expects the recipient as country code + number, no '+'.
        recipient = phone_number.lstrip("+")
        payload = {
            "messaging_product": "whatsapp",
            "to": recipient,
            "type": "template",
            "template": {
                "name": self._settings.whatsapp_otp_template_name,
                "language": {"code": self._settings.whatsapp_otp_template_language},
                "components": [
                    {"type": "body", "parameters": [{"type": "text", "text": otp}]},
                    {"type": "button", "sub_type": "url", "index": "0",
                     "parameters": [{"type": "text", "text": otp}]},
                ],
            },
        }
        headers = {
            "Authorization": f"Bearer {self._settings.whatsapp_access_token}",
            "Content-Type": "application/json",
        }
        try:
            response = await self._http_client.post(url, json=payload, headers=headers)
        except httpx.HTTPError as exc:
            raise WhatsAppSendError("Could not reach WhatsApp Business Platform.") from exc

        if response.status_code >= 400:
            # Deliberately not including response.text: it may echo back
            # config/account details and must never reach the client or logs.
            raise WhatsAppSendError("WhatsApp message delivery failed.")

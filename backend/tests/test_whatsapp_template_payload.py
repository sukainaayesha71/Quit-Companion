import json

import httpx
import pytest

from app.config import Settings
from app.whatsapp.meta_client import MetaWhatsAppClient


@pytest.mark.asyncio
async def test_authentication_template_supplies_code_to_body_and_copy_button():
    captured = {}
    def handle(request):
        captured['body'] = json.loads(request.content)
        captured['path'] = request.url.path
        return httpx.Response(200, json={'messages': [{'id': 'test-message'}]})
    settings = Settings(_env_file=None, whatsapp_access_token='test-token',
                        whatsapp_phone_number_id='sender-id',
                        whatsapp_api_version='v27.0',
                        whatsapp_otp_template_name='otp_verification',
                        whatsapp_otp_template_language='en_US')
    async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as http:
        await MetaWhatsAppClient(settings, http_client=http).send_otp('+14155552671', '654321')
    template = captured['body']['template']
    assert captured['body']['to'] == '14155552671'
    assert captured['path'] == '/v27.0/sender-id/messages'
    assert template['name'] == 'otp_verification'
    assert template['language']['code'] == 'en_US'
    assert template['components'] == [
        {'type': 'body', 'parameters': [{'type': 'text', 'text': '654321'}]},
        {'type': 'button', 'sub_type': 'url', 'index': '0',
         'parameters': [{'type': 'text', 'text': '654321'}]},
    ]

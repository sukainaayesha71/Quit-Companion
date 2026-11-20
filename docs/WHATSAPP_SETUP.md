# WhatsApp phone sign-in setup

Phone sign-in defaults to WhatsApp OTP. Firebase still stores the authenticated
account; the backend verifies the WhatsApp-delivered code and issues a Firebase
custom token using its Admin credentials. Firebase SMS billing is not used by
this route. Meta's own account eligibility and messaging charges still apply.

## 1. Create the Meta application

1. Open https://developers.facebook.com/apps/ and register as a developer if needed.
2. Create an app and select the WhatsApp customer-messaging use case.
3. Select or create your business portfolio and WhatsApp Business/Messaging account.
4. Open WhatsApp > API Setup (or Customize use case > Connect on WhatsApp > API Setup).
5. Select the test sender provided by Meta, or configure an authorized business sender.
6. Add and verify your receiving WhatsApp number in the permitted test recipients.
7. Send the dashboard's sample message first to confirm that the sender works.

The dashboard sample is a connectivity test. Its `hello_world` template cannot
be substituted for the application's authentication template.

## 2. Obtain the credentials

In API Setup, record the **Phone Number ID**, not the visible telephone number.
Also record the displayed WhatsApp Business Account/Messaging account ID.
Generate a temporary access token for initial setup. It expires; do not use it
as the final delivery credential.

For ongoing use, open Meta Business Settings > Users > System users. Create a
system user, assign the application and WhatsApp account assets, and generate
a token with the required `whatsapp_business_messaging` permission. Account
and template management uses `whatsapp_business_management`; Meta's onboarding
guide also lists `business_management` for its broader management workflow.
Choose an available suitable lifetime and retain the token securely. Tokens
can still be revoked even if an expiration-free option is offered.

## 3. Create the authentication template

In WhatsApp Manager, open Message templates and create a template with:

| Setting | Value expected by this project |
| --- | --- |
| Category | Authentication |
| Name | `otp_verification` (or configure the actual approved name) |
| Language | English (US), `en_US` |
| OTP delivery button | Copy code |
| Displayed expiry | If enabled, match the backend's default five-minute expiry |

Wait for Meta approval. Availability depends on the account and sender; a test
sender does not guarantee custom authentication-template approval. If the test
account cannot create/use one, complete onboarding for an eligible business
sender. Do not replace authentication with a marketing or free-form message.

The backend sends the same generated OTP in the body and first copy-code button
parameter. A different template language/button layout must be reflected in the
configuration or payload code.

## 4. Configure the backend

Open `backend/.env` locally and update these entries (do not duplicate keys):

```dotenv
WHATSAPP_ACCESS_TOKEN=PASTE_YOUR_META_ACCESS_TOKEN
WHATSAPP_PHONE_NUMBER_ID=PASTE_SENDER_PHONE_NUMBER_ID
WHATSAPP_BUSINESS_ACCOUNT_ID=PASTE_ACCOUNT_ID
WHATSAPP_API_VERSION=v27.0
WHATSAPP_OTP_TEMPLATE_NAME=otp_verification
WHATSAPP_OTP_TEMPLATE_LANGUAGE=en_US
```

Use the supported Graph API version shown in your Meta dashboard if different.
The account-ID setting is retained for setup/reference; the current send endpoint
uses the Phone Number ID. Keep the existing `FIREBASE_SERVICE_ACCOUNT_JSON`
setting and ensure its key belongs to the same project as the Android app.
Neither the Meta token nor the Firebase Admin key belongs in Flutter code.

Stop the existing backend supervisor before starting a replacement; run from
`backend/`:

```powershell
.\.venv\Scripts\python.exe tools/local_services.py --worker --notifications --usb
```

If the developer's supervisor is running hidden, ask the project maintainer to
restart that instance rather than launching a second one on port 8000.

## 5. Start the mobile app

Stop the existing Flutter run and start again from `mobile/`:

```powershell
flutter run --dart-define=OTP_BACKEND_BASE_URL=http://127.0.0.1:8000 --dart-define=PHONE_AUTH_PROVIDER=whatsapp
```

Enter your verified recipient in international format. Receive the code in
WhatsApp, copy it into the app, and submit it before the code expires. Resend
requests are subject to the application's cooldown and Meta delivery limits.

For optional Firebase SMS instead, use `PHONE_AUTH_PROVIDER=firebase`; that
provider has separate Firebase billing, test-number and app-verification setup.

## Troubleshooting

- Backend 502: missing/expired Meta credentials, inaccessible sender, unapproved
  template, language/button mismatch or recipient restrictions may be involved.
- Sample message arrives but app OTP does not: verify the authentication template;
  a working sample does not prove that template is configured.
- OTP arrives but sign-in fails: check expiry and backend Firebase Admin credentials.
- Nothing reaches the backend: check API health, the app backend URL and ADB forwarding.

Do not publish tokens or real OTPs in screenshots, logs, README files or chat.
The application intentionally hides Meta response bodies from end users.

Official references:
- https://developers.facebook.com/documentation/business-messaging/whatsapp/get-started
- https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/authentication-templates/copy-code-button-authentication-templates

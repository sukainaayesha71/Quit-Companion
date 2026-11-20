# Quit Companion — delivery and setup guide

Android nicotine recovery app built with Flutter, Firebase and a Python FastAPI
backend. This delivery includes Android source, backend source, tests, research
tools and deployment templates. iOS and public backend hosting are not included
in the current running setup.

## 1. What the recipient must configure

The delivered app currently references the developer's Firebase project,
`quit-companion`, and Android package `com.quitcompanion.quit_companion`.
Decide whether to keep that Firebase project with authorized access or use a new
project. Do not assume the developer's laptop configuration will work elsewhere.

| Item | Current setup | Required action on the recipient's setup |
| --- | --- | --- |
| Project location | Previously under the developer's Downloads folder | Extract anywhere and use that local path. Commands below start at the repository root containing this README. |
| Flutter and Android SDK | Machine-specific paths in `mobile/android/local.properties` | Regenerate this file on the new machine; do not reuse paths containing another Windows username or Flutter installation. |
| Python environment | `backend/.venv/` on the developer's machine | Create a new virtual environment and install dependencies. Do not copy the old virtual environment. |
| Firebase Android configuration | `mobile/android/app/google-services.json` | Download configuration for the selected Firebase project and exact Android package. |
| Flutter Firebase options | `mobile/lib/core/config/firebase_options.dart` | Regenerate when changing Firebase projects. Replacing only the JSON file is insufficient. |
| Firebase CLI mapping | Project references in `mobile/firebase.json` | Regenerate/review when changing projects; always pass the intended project ID when deploying rules or indexes. |
| Google sign-in fingerprint | Developer's debug signing certificate | Register the new machine's SHA-1 and SHA-256 for `com.quitcompanion.quit_companion`, then download the updated JSON and rebuild. |
| Backend Firebase credentials | Local Admin SDK private-key JSON and its path in `backend/.env` | Obtain an authorized service-account key for the selected project and set its actual local path. Do not redistribute the developer's private key. |
| Gemini | Developer's server-side key/model settings | Supply an authorized Gemini key in `backend/.env`; verify the configured model is available to that key. |
| Backend address | Local API on port 8000 | Choose USB localhost forwarding, emulator host address, or a deployed HTTPS URL. |
| Phone authentication | WhatsApp OTP by default; Firebase SMS is optional | Configure Meta sender credentials and an approved authentication template. See section 5 and docs/WHATSAPP_SETUP.md. |
| Reminder preferences | Saved per device, plus per-account remote schedules | Enable permissions and desired reminder options on the recipient's phone. Existing local preferences do not transfer with source code. |
| Push worker | Background Python process on the developer's laptop | Start a worker on the recipient's machine; old background processes do not transfer. |
| Release signing | Release build currently uses debug signing in Gradle | Configure the recipient's release keystore before distributing a production app. Never deliver the developer's signing key as a public project asset. |

Firebase client configuration identifies the project; it is different from an
Admin SDK private key. Keep Admin keys, Gemini/Meta secrets and real `.env` files
out of Git and public delivery archives. Supply credentials separately through
an authorized secure handover.

## 2. Prerequisites

- Flutter compatible with the checked-in lockfile: **Flutter 3.47.0 or newer**
  with **Dart 3.13.0 or newer**. Keep `mobile/pubspec.lock` for reproducibility.
- Android Studio/Android SDK, platform tools (`adb`), and a compatible Java
  runtime; Android compilation targets Java 17.
- Android 8.0/API 26 or newer on the test phone, with USB debugging enabled.
- Python 3.12, recommended to match the development backend environment.
- Internet access for dependency installation, Firebase, Gemini and FCM.
- Firebase project access. Node.js/npm and Firebase/FlutterFire CLIs are needed
  when configuring a new project or deploying Firebase rules/indexes.

Commands below use Windows PowerShell. On macOS/Linux, use the equivalent paths
and `.venv/bin/python` instead of `.venv\Scripts\python.exe`.

## 3. Configure Firebase

### Keep the existing project

Obtain authorized access to `quit-companion`. Existing accounts and Firestore
records remain in that project. Register the recipient's signing fingerprints
against **`com.quitcompanion.quit_companion`**, not the older
`com.example.quit_companion` registration.

Run on the recipient's laptop:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

This applies to Flutter's standard debug keystore. If it does not exist yet,
build/run the Android app once. If `keytool` is not on PATH, use the executable
inside Android Studio's `jbr/bin` directory.

In Firebase Console, open Project settings, select the exact Android package,
and add the SHA-1 and SHA-256 printed by the command. Download the updated
`google-services.json` to:

```text
mobile/android/app/google-services.json
```

### Use a different Firebase project

Create/register an Android app using the existing package name, unless you also
intend to change the Android namespace/application ID and Kotlin package.
Enable Email/Password, Google and Phone providers as required, and create the
default Firestore database.

From `mobile/`, configure the selected project:

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID --platforms=android --out=lib/core/config/firebase_options.dart
```

Replace `YOUR_FIREBASE_PROJECT_ID` with the actual ID. If `flutterfire` is not
found, add Dart's global executable directory to PATH. Confirm that the generated
Dart options, Android JSON and Firebase CLI mapping all point to the same
project. Register signing fingerprints and download the Android JSON after
Google sign-in is enabled.

For a new project, deploy the supplied rules and index definitions from
`mobile/`:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project=YOUR_FIREBASE_PROJECT_ID
```

If the CLI proposes deleting existing indexes, review the target project before
confirming. For an existing shared database, the additive alternative is
`backend/tools/ensure_indexes.py`: run it with configured Admin credentials to
preview, then use `--apply` to preserve existing single-field definitions while
adding the required group indexes.

Required ascending collection-group indexes:

| Collection group | Field |
| --- | --- |
| `cravingLogs` | `riskAssessmentPending` |
| `habitAlternativeAttempts` | `outcomeHelped` |
| `reminderSchedules` | `enabled` |

Wait until the indexes are READY. These indexes and rules were configured in
the developer's project; a new project needs its own setup. Changing Firebase
projects does not migrate existing accounts or data.

Official references:
[Flutter Firebase setup](https://firebase.google.com/docs/flutter/setup),
[FlutterFire CLI options](https://firebase.flutter.dev/docs/cli),
[Firebase configuration](https://firebase.google.com/docs/projects/learn-more).

## 4. Configure and start the backend

From the repository root:

```powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Copy the template only when creating a new environment; do not overwrite a
configured `.env`. Edit `backend/.env`:

```dotenv
FIREBASE_SERVICE_ACCOUNT_JSON=./firebase-serviceAccount.json
GEMINI_API_KEY=YOUR_SERVER_SIDE_GEMINI_KEY
GEMINI_MODEL=gemini-3.5-flash-lite
RELAPSE_PREDICTOR_MODE=ml
WORKER_POLL_SECONDS=30
REQUIRE_CLINICAL_REVIEW=false
```

Place the authorized Admin SDK key at the configured path. A relative path is
resolved from the backend working directory, so always start these commands
inside `backend/`. If you store the key elsewhere, use that machine's path
(prefer forward slashes in Windows configuration values).

The named Gemini model is the current development setting, not a guarantee of
future availability. If unavailable, choose an accessible compatible model and
update `GEMINI_MODEL`. Restart the backend after changing `.env`.

`REQUIRE_CLINICAL_REVIEW=false` is the local development setting and does not
represent medical approval. Production review gating requires a genuine review
record; see `deploy/reviews/README.md`.

Start the API, assessment recovery, scheduled push delivery and automatic phone
forwarding:

```powershell
.\.venv\Scripts\python.exe tools/local_services.py --worker --notifications --usb
```

Keep this terminal running. To run without scheduled push delivery, omit
`--notifications`. Do not launch duplicate supervisors/workers for a demo.

Check in another terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Expected response: `status: ok`. API documentation is at
`http://127.0.0.1:8000/docs`. Health only confirms the API is running;
authenticated Firebase/Gemini/FCM requests need their own verification.
Diagnostic logs/state from local supervision are under `backend/.runtime/`.

## 5. Phone OTP configuration

Phone login uses WhatsApp OTP for all numbers by default. Configure the Meta
Cloud API sender and approved authentication template as described in
[WhatsApp setup](docs/WHATSAPP_SETUP.md). The legacy test-number allowlist is
not used by the default factory.

For optional Firebase SMS instead, add
`--dart-define=PHONE_AUTH_PROVIDER=firebase` to the app run/build command.
Firebase SMS requires the applicable Firebase billing, region and app-verification
setup; Firebase test numbers can be used without sending real SMS.

Real WhatsApp OTP requires the recipient's authorized Meta configuration:

```dotenv
WHATSAPP_ACCESS_TOKEN=YOUR_META_ACCESS_TOKEN
WHATSAPP_PHONE_NUMBER_ID=YOUR_META_PHONE_NUMBER_ID
WHATSAPP_BUSINESS_ACCOUNT_ID=YOUR_META_BUSINESS_ACCOUNT_ID
WHATSAPP_API_VERSION=v27.0
WHATSAPP_OTP_TEMPLATE_NAME=otp_verification
WHATSAPP_OTP_TEMPLATE_LANGUAGE=en_US
```

Verify the API version and approved authentication template for the recipient's
Meta account. Enabling Firebase's Phone provider does not configure WhatsApp.
WhatsApp OTP requires the Python backend and its Firebase Admin key. The
optional Firebase SMS route does not require Meta credentials. Provider selection is in
`mobile/lib/features/auth/data/default_phone_auth_repository.dart`.

## 6. Run the Android app on another laptop

Open the **`mobile/` folder containing `pubspec.yaml`** in Android Studio.

In a new terminal, from the repository root:

```powershell
cd mobile
flutter doctor
flutter doctor --android-licenses
```

If the delivery archive contains `android/local.properties` from the original
machine, remove that generated file before the first build:

```powershell
Remove-Item .\android\local.properties -ErrorAction SilentlyContinue
flutter pub get
adb devices
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=OTP_BACKEND_BASE_URL=http://127.0.0.1:8000
```

Flutter regenerates local Android properties using the recipient's SDK setup.
Accept the phone's USB debugging authorization. With multiple connected devices,
select one explicitly using `adb -s DEVICE_SERIAL ...` and
`flutter run -d DEVICE_SERIAL ...`; obtain that serial from `adb devices`
instead of copying the developer's phone ID.

The backend `--usb` option restores port forwarding after reconnects while its
supervisor is running. It requires `adb` on PATH or the standard Windows Android
SDK location. The app URL must be exactly `http://127.0.0.1:8000`, without
backslashes or a trailing slash added to the command.

Alternative endpoints:

| Environment | Backend URL |
| --- | --- |
| Physical Android phone with ADB forwarding | `http://127.0.0.1:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Public deployment | The recipient's actual `https://...` API address |

The default in `mobile/lib/core/config/otp_backend_config.dart` is the emulator
address. A physical phone needs an explicit `--dart-define` as shown above.
This definition is set at build/run time. Restart `flutter run` to change it.

A phone on the same Wi-Fi can alternatively use the laptop's LAN address, but
that requires binding the API to `0.0.0.0`, allowing the port through the laptop
firewall, and setting the corresponding LAN URL. The supplied local supervisor
binds to `127.0.0.1`; the USB commands above work without changing that binding.

If package resolution stalls and packages are already cached:

```powershell
flutter --no-version-check --suppress-analytics pub get --offline
flutter --no-version-check --suppress-analytics run --no-pub --dart-define=OTP_BACKEND_BASE_URL=http://127.0.0.1:8000
```

On a new laptop, the first dependency installation normally needs internet.
Use `--no-pub` only after dependency resolution succeeds. Do not repeatedly run
`flutter clean` to fix network delays.

After Dart-only changes, uppercase **R** hot-restarts a running debug app.
After replacing Android Firebase configuration or changing native settings,
stop and rebuild the app.

## 7. Notifications and AI behavior

In the app's Notifications screen, grant Android notification permission and
choose daily reminders and push notifications independently.

- Local reminders are scheduled on the phone.
- Push notifications deliver milestone and recovery events. They require a
  registered device token, phone internet access and the running backend.
- The daily frequency determines the check-in schedule; habit and recovery
  categories are enabled separately.
- Daily reminders use the phone's timezone and continue without internet.
- Either option can be enabled alone or together. Turning one off leaves the
  other unchanged. The old remote daily schedule is disabled when enabling push
  notifications, avoiding duplicate check-ins.
- Source delivery does not preserve the developer's device token or phone
  preferences. Each recipient device must register its own token.
- Android may delay notifications. Force-stopped apps generally need to be
  reopened. Permission, battery restrictions and actual arrival require a
  physical-device test.

HealthBot and plan selection use the server-side Gemini key. If generation is
unavailable, labeled fallback guidance remains available. New users receive a
generic starter plan; accounts with activity can receive personalized goals
and AI-selected activities. Successful weekly plans are cached; saved fallback
plans retry AI selection on opening. The refresh button explicitly regenerates.

Firebase authentication and Firestore use Firebase directly. HealthBot,
server-generated plans, remote scheduling, recursive community-post deletion,
journal deletion/streak cleanup and account deletion also depend on the Python
backend. A local API running on the original developer's laptop does not become
available on the recipient's laptop automatically.

## 8. Delivery verification checklist

- [ ] Flutter/Android SDK paths belong to the recipient's machine.
- [ ] A fresh Python environment installs successfully.
- [ ] Mobile Firebase JSON, Dart options and backend Admin credentials use the same project.
- [ ] Recipient debug fingerprints are registered under the correct Android package.
- [ ] Email/password and Google login work on the recipient's phone.
- [ ] The configured phone OTP route delivers/verifies a real or explicitly configured test OTP.
- [ ] Firestore rules are deployed and required indexes are READY.
- [ ] Backend health returns OK and the phone can reach the API.
- [ ] A new HealthBot query returns a generated answer or an accurately labeled fallback.
- [ ] A new account sees a starter plan; an account with activity can refresh its personalized plan.
- [ ] Editing baseline daily usage updates today's/future reduction targets.
- [ ] Journal edit/delete, community create/delete and profile save show completion feedback.
- [ ] Turning reminders on/off finishes and reflects the saved state.
- [ ] Local reminder and real FCM arrival are verified on the target phone.
- [ ] Logout/account deletion and per-account data separation are verified.

Run automated checks from `mobile/`:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

From `backend/`:

```powershell
.\.venv\Scripts\python.exe -m pytest
```

Automated tests use test doubles and do not prove live Google, OTP, Gemini or FCM
delivery. Historical test counts in older documents are not a substitute for
running the delivered version on the recipient's environment.

## 9. Deployment, research and delivery limits

The current running setup is a **local Android development/demo setup**.
Public HTTPS backend deployment was deferred. Without it, backend features and
scheduled pushes require the recipient's machine/worker to stay running.
Release Android builds disallow cleartext HTTP, so the USB HTTP command is for
debug builds; release delivery needs an HTTPS backend and release signing.

`deploy/` contains Docker/API/worker/TLS templates. Before using them, configure
the recipient's domain, secret paths, environment and actual review record.
Their presence does not mean a public production deployment has been verified.

The default relapse-risk mode is `ml`, using the packaged experimental XGBoost
pipeline. It is not independently validated for the app population. Authorized
PATH data and genuine medical-advisor review remain external work. Research data
and bulk model outputs are excluded from source delivery; the active inference
artifact is included under `backend/app/relapse/model_artifacts/`. Training is
not required to run it. See `docs/ML_INTEGRATION.md` for evaluation limits.

For a source archive, include source, tests, assets, lockfiles, configuration
templates and documentation. Exclude real `.env` files, Admin keys, private
keystores, `.venv/`, `.runtime/`, logs, Flutter build/cache folders and temporary
tool dependencies. Transfer authorized credentials separately. A copied folder
can contain ignored files even when Git excludes them, so inspect the archive.

## 10. Project layout and supporting documentation

| Folder | Purpose |
| --- | --- |
| `mobile/lib/app/` | App composition/navigation |
| `mobile/lib/core/` | Firebase/backend configuration and theme |
| `mobile/lib/features/` | Feature controllers, repositories, models and screens |
| `mobile/lib/shared/` | Shared clients, utilities and widgets |
| `mobile/test/` | Flutter tests |
| `backend/app/` | API routes, services and worker |
| `backend/tools/` | Service supervision, indexes and benchmarking |
| `backend/ml/` | Research dataset/training/evaluation tools |
| `backend/tests/` | Backend tests |
| `deploy/` | Deployment templates |
| `docs/` | Audits, implementation history and research records |

This README is the handover setup guide. Historical audits may describe earlier
behavior. Additional references:
[mobile guide](mobile/README.md),
[backend guide](backend/README.md),
[completion record](docs/ANDROID_COMPLETION.md),
[documentation index](docs/README.md).

## ML relapse scoring

The backend now defaults to `RELAPSE_PREDICTOR_MODE=ml`, using the packaged
XGBoost pipeline in `backend/app/relapse/model_artifacts/app_candidate.joblib`.
Install `backend/requirements.txt` and restart both API and worker after changing
the mode. The artifact is included in source delivery; training data is not needed
to run inference. See [ML integration](docs/ML_INTEGRATION.md) for provenance,
missing-answer handling, evaluation limits and reproduction.

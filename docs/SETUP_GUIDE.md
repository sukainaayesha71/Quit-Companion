# Quit Companion — setup, run, deploy and verification guide

*Last updated 2026-11-23. Commands are for Windows (PowerShell) unless marked. Never commit `backend/.env`, `backend/*firebase-adminsdk*.json`, `mobile/android/key.properties` or keystores; all are git-ignored.*

## 1. Prerequisites

- Flutter SDK (the project's version), Android SDK with `platform-tools` (adb), JDK 17+.
- Python 3.12 for the backend (`backend/.venv`).
- Optional: Node 18+ and the Firebase CLI (Firestore rules tests), Docker Engine and Compose (deployment, on the server).

## 2. Firebase configuration (existing project `quit-companion`)

- The app uses `mobile/android/app/google-services.json` and `mobile/lib/core/config/firebase_options.dart`. These are client configuration, not secrets.
- The backend uses a **Firebase Admin service-account key**. Keep it outside Git: locally at `backend/<name>-firebase-adminsdk-*.json`, referenced by `FIREBASE_SERVICE_ACCOUNT_JSON` in `backend/.env`.
- **Google Sign-In needs every signing key's SHA fingerprints registered** (Firebase console → Project settings → Android app → Add fingerprint), then a re-downloaded `google-services.json`.
  - Read a fingerprint with `keytool -list -v -keystore <keystore> -alias <alias>`.
  - Debug keystore: `%USERPROFILE%\.android\debug.keystore`, alias `androiddebugkey`, password `android`.
  - On 2026-11-23, **this PC's debug SHA-1 (`02:92:F9:5C:CA:35:57:A2:04:1B:46:DC:65:F9:3E:0B:09:4D:C3:0E`) was not registered**; only `1E:DB:D2:EE:…:A1:0E` is. Until it is added, Google Sign-In from debug builds made on this PC is expected to fail (error 10 / DEVELOPER_ERROR). Email/password and phone sign-in are unaffected.

## 3. Backend environment (`backend/.env` for local; `deploy/.env` for production)

| Variable | Purpose |
| --- | --- |
| `FIREBASE_SERVICE_ACCOUNT_JSON` (local) / `FIREBASE_CREDENTIAL_FILE` (deploy) | Admin key path (auth verification, Firestore, FCM) |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | Health-Bot and plan generation. Empty = curated fallback only |
| `HEALTHBOT_GEMINI_TIMEOUT_SECONDS` | Gemini budget before the curated fallback (default 1.5) |
| `RELAPSE_PREDICTOR_MODE` | `ml` (code default) or `rule_based` (deploy template). **Owner decision** |
| `RELAPSE_MODEL_REQUIRED`, `RELAPSE_MODEL_PATH` | Fail-fast if the model can't load; optional mounted artifact |
| `REQUIRE_CLINICAL_REVIEW`, `CLINICAL_REVIEW_RECORD` | Clinical-review gate. **Owner decision**: `true` without an approved record returns 503 for non-emergency Health-Bot and coaching requests |
| `FCM_SCHEDULER_TOKEN` | Only for `POST /notifications/send` (the worker doesn't need it) |
| `WORKER_POLL_SECONDS` | Worker pass interval (clamped 5–45) |
| `WHATSAPP_*` | Optional WhatsApp OTP, see [WHATSAPP_SETUP.md](WHATSAPP_SETUP.md) |
| `SITE_DOMAIN` (deploy only) | Public domain for Caddy's automatic HTTPS |

Preflight (prints OK/WARN/FAIL only, never values): `backend\.venv\Scripts\python.exe backend\tools\check_deploy_config.py deploy\.env`

## 4. Run the demo on an Android phone (USB, backend on this PC)

This is a debug/demo setup. The phone reaches the PC's backend through USB port forwarding. No production URL is involved.

```powershell
# 1) Backend (terminal 1)
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
#    or, with the pending-assessment worker:  .\.venv\Scripts\python.exe tools\local_services.py --worker

# 2) Phone: enable Developer options + USB debugging, connect by USB, accept the prompt
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices                      # the phone must be listed as "device"
& $adb reverse tcp:8000 tcp:8000     # phone 127.0.0.1:8000 -> PC 127.0.0.1:8000 (repeat after reconnecting)

# 3) Install the prebuilt debug APK (built for http://127.0.0.1:8000)
& $adb install -r mobile\build\app\outputs\flutter-apk\app-debug.apk
#    or build + run from source:
#    cd mobile; flutter run --dart-define=OTP_BACKEND_BASE_URL=http://127.0.0.1:8000
```

Without the backend running (or without `adb reverse`), Firebase features still work: sign-in, Firestore data, community, journal, rewards, Knowledge Hub, local reminders. Backend features fall back or show errors:
- relapse risk scoring (saved as "assessment pending");
- Health-Bot (on-device curated fallback and crisis detection);
- server recommendation re-ranking (on-device ranking still shown);
- AI plans (local fallback);
- phone/WhatsApp OTP;
- push schedule (falls back to on-device reminders);
- account deletion.

## 5. Release build (needs a deployed HTTPS backend)

```powershell
# one-time: create an upload keystore (keep it and the passwords private)
keytool -genkey -v -keystore $env:USERPROFILE\quit-companion-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
# create mobile\android\key.properties:
#   storeFile=C:\\Users\\<you>\\quit-companion-upload.jks
#   storePassword=...
#   keyAlias=upload
#   keyPassword=...
cd mobile
flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=https://<SITE_DOMAIN>
# -> mobile\build\app\outputs\flutter-apk\app-release.apk
flutter build appbundle --release --dart-define=OTP_BACKEND_BASE_URL=https://<SITE_DOMAIN>
# -> mobile\build\app\outputs\bundle\release\app-release.aab
```

- Release builds **fail on purpose** without an `https://` URL (Gradle guard, Step 11).
- Without `key.properties` they're signed with the debug key and print a warning: fine for sideloading, not for publishing.
- Add the upload key's SHA-1/SHA-256 in Firebase for Google Sign-In.

## 6. Deploy backend + worker (Docker Compose + Caddy, on your Linux server)

**On AWS (free-plan credits):** follow [deploy/aws/README.md](../deploy/aws/README.md):
- `provision-cloudshell.sh` creates the EC2 server, firewall, Elastic IP and budget in `ap-south-1`;
- `deploy.sh <elastic-ip>` uploads the working tree, builds, tests in the image, then starts and verifies.

The steps below are the same deployment done by hand on any Linux server.

Needs: a Linux server with Docker Engine and Compose, a domain whose DNS points at it, ports 80/443 open, and the Admin key copied to the server outside the repo.

```bash
git clone <repo> && cd Quit-Companion
cp deploy/.env.example deploy/.env     # edit: SITE_DOMAIN, FIREBASE_CREDENTIAL_FILE, GEMINI_API_KEY, decisions in section 3
docker compose --env-file deploy/.env -f deploy/compose.yaml up -d --build
docker compose -f deploy/compose.yaml ps              # backend healthy, worker healthy (heartbeat), proxy up
docker compose -f deploy/compose.yaml logs -f worker  # "Worker started (notifications=True, poll=30s)"
curl https://<SITE_DOMAIN>/health                     # {"status":"ok"}
curl https://<SITE_DOMAIN>/ready                      # 200 + relapse_predictor details (503 if the review gate blocks)
```

Firestore (live project changes, owner only):
```bash
cd mobile && firebase deploy --only firestore:rules --project quit-companion     # Step 10 rules
cd backend && python tools/ensure_indexes.py            # dry run, then: python tools/ensure_indexes.py --apply
```

## 7. Automated tests (run on the PC)

```powershell
cd mobile;  flutter analyze;  flutter test                  # whole suite
cd backend; .\.venv\Scripts\python.exe -m pytest            # includes the worker tests
cd mobile\test\firestore_rules; npm install; npm test        # rules on the local emulator (demo project)
```

On Windows, check after the rules tests that nothing still listens on port 8080. The Firebase CLI can leave the emulator's Java process running; stop it if so.

Performance tools:
- `backend\.venv\Scripts\python.exe backend\tools\measure_local_latency.py`: local, loopback, simulated Firestore, Gemini stubbed.
- After deployment: `$env:BENCHMARK_FIREBASE_ID_TOKEN="<test-account ID token>"; python backend\tools\benchmark_api.py --url https://<SITE_DOMAIN> --samples 20`.

## 8. Delivery verification checklist

These need **your phone** (A) or **a second device** (B). None of them has been performed yet. Debug/profile builds log timings: `& $adb logcat | Select-String "\[perf\]"`.

| # | Check | Needs | Pass when |
| --- | --- | --- | --- |
| 1 | App starts, welcome → Log In / Register screens | A | No crash; screens render (verified on the Pixel_6 **emulator** on 2026-11-23, not yet on a phone) |
| 2 | Email/password sign-in with your existing account; Dashboard loads | A | Dashboard shows your data; `[perf] dashboard_load` < 3000 ms on mobile data |
| 3 | Google Sign-In | A | Works after registering this PC's SHA-1 (section 2); error 10 means the fingerprint is missing |
| 4 | Phone OTP | A + backend | Code received and accepted (WhatsApp needs Meta setup) |
| 5 | Badge pop-up: account that just earned several badges | A | **One** pop-up listing them; "Keep going" visible without scrolling |
| 6 | Largest system font size (Settings → Display → Font size max) | A | Dashboard, pop-up, Crisis Support and Community lay out without overlap |
| 7 | Account isolation: log out, log in as a second account | A | No badge or data from the first account appears |
| 8 | Dashboard: high-risk banner, first-craving prompt (new account), 7/30-day toggle | A | As described in Step 3 |
| 9 | Log a craving online | A + backend | Risk shown; `[perf] relapse_prediction` < 1500 ms |
| 10 | Airplane mode: log a craving, force-close, reopen, then go back online | A | Entry kept with "waiting to sync"; syncs once, with no duplicate in Firestore |
| 11 | Alternatives / habit recommendations | A (+ backend) | List appears immediately; `[perf] recommendations_*` < 2000 ms |
| 12 | Health-Bot: normal question, offline question, "I want to end my life" | A + backend | Answer with source links; offline curated reply; red emergency bubble + Crisis Support. **Uses Gemini quota if a key is set; only with your approval** |
| 13 | Crisis Support: Call / Text / Website buttons | A | Dialer, SMS app and browser open (nothing dials automatically) |
| 14 | Community: post, reply, like, unlike, blank and 2001-character post | A | Valid posts appear; invalid ones show a message |
| 15 | Community real-time across devices | A + B | Post on one, appears on the other within 500 ms |
| 16 | Reminders: push default and fallback | A + deployed worker | "Delivered as push notifications"; reminder arrives within 60 s of the slot; with no backend, the on-device fallback message shows |
| 17 | High-risk check-in | A | Two high-risk cravings within a week, so one notification about 2 h later; none after logging a relapse |
| 18 | Knowledge Hub videos | A | CDC videos open in YouTube or the browser |
| 19 | Account deletion | A + backend | Returns to the welcome screen; data removed |

**Physical-phone progress (2026-11-23, vivo V2022):** #1 app start: no crash. #2 sign-in/Dashboard: partially verified (no crash; owner's explicit confirmation pending; `dashboard_load` timing not measurable on this phone). #9 log a craving online: risk returned with backend 200 (ML mode); `[perf]` timing not readable because this phone doesn't show app logs in logcat. Details: `docs/superpowers/plans/2026-11-23-physical-device-ml-test-record.md`.

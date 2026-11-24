# Step 12 — Backend and worker deployment: implementation record (2026-11-23)

## Status: prepared and tested locally — NOT deployed

Per the project owner's decision ("Prepare only, I deploy later"), nothing was deployed and no live resources were created or changed. **There is no production HTTPS URL yet**, so Step 11's release build is still waiting on one.

## Existing deployment method (kept)

`deploy/compose.yaml` runs three services: **backend** (FastAPI/uvicorn on 127.0.0.1:8000), **worker** (`python -m app.worker`), and **proxy** (Caddy 2, automatic Let's Encrypt HTTPS for `SITE_DOMAIN`, ports 80/443).
- The Firebase Admin key is mounted read-only from `FIREBASE_CREDENTIAL_FILE`.
- `deploy/reviews` is mounted for the clinical-review record.
- `backend/Dockerfile`: python:3.12-slim, pinned requirements, non-root user, `/health` HEALTHCHECK, `--proxy-headers`.
- `backend/.dockerignore` excludes `.env`, `*firebase-adminsdk*.json`, `ml/`, `tests/` and `data/`. Root `.gitignore` also ignores the admin key and `.env` (verified with `git check-ignore`).

This machine has **no Docker and no cloud CLI**, so images weren't built here.

## Changes

### FCM as the default (project owner's decision, 2026-11-23)

This reverses Module 11's local-only decision. Daily check-ins are now delivered by **FCM push** by default, with **on-device reminders as the automatic fallback**.
- `ReminderSettings.defaults.remoteDelivery = true`. A never-saved preference reads as push on; a previously saved value is kept. There is a new device-local `remoteScheduleActive` flag.
- `ReminderNotificationService` adds `scheduleRemoteDailyReminders` (registers the FCM token and saves the server schedule via `PUT /notifications/schedule`) and `disableRemoteDailyReminders`. It defines typed `PushUnavailableException` and `RemoteScheduleException`.
- `LocalReminderNotificationService`:
  - implements both methods;
  - `setPushNotificationsEnabled(true)` no longer force-disables the server schedule;
  - turning push off still stops server delivery.
- `ReminderController._applyDelivery` (the single decision point):
  - reminders on + push → server schedule, and **then** local daily reminders are cancelled, so a user never gets both and never gets neither;
  - push unavailable (permission/token), or the backend unreachable on first setup → local reminders (`localFallback`);
  - a temporary outage **after** the server schedule was confirmed → keep the server schedule and add no local reminders (avoids duplicates);
  - when local takes over, the server schedule is stopped (best effort);
  - app start never shows a permission prompt; push registers silently only if permission was already granted.
- The Reminders screen shows the delivery mode ("Delivered as push notifications." / "Push isn't available right now, so reminders come from your device." / "Delivered by your device (push is off).") and has updated push-switch text.
- **Unchanged:** event pushes (badge, restart plan, activity feedback); the Step 6 high-risk check-in stays a local one-off notification; the backend and worker code paths for scheduled FCM already existed.
- **Note:** daily check-ins by push only arrive while the deployed worker is running. Until deployment, the first setup attempt fails (backend unreachable), so devices use local reminders.

### Worker
- `app/worker.py`:
  - logs include the exception type (still no user content);
  - startup log line;
  - `poll_interval_seconds()` clamps the interval to 5–45 s (unchanged rule, now testable);
  - **heartbeat file** `/tmp/quit-companion-worker.heartbeat` written after every pass.
- `deploy/compose.yaml`: the worker **healthcheck** was previously disabled. It is now unhealthy if the heartbeat is older than 180 s.

### Configuration and preflight
- New `backend/tools/check_deploy_config.py`. It checks `deploy/.env` **without printing any values**:
  - domain;
  - the credential file is a service-account key for the app's Firebase project;
  - Gemini and scheduler tokens present;
  - the relapse model loads for the chosen mode;
  - clinical-review readiness;
  - worker poll range;
  - the env file isn't tracked by git.
  Exits 1 on FAIL.
- `deploy/.env.example`: documented `RELAPSE_MODEL_REQUIRED`, `RELAPSE_MODEL_PATH`, `HEALTHBOT_GEMINI_TIMEOUT_SECONDS`, and what `REQUIRE_CLINICAL_REVIEW=true` does without a record. **Values unchanged.**

## Decisions still open for the owner (not changed)

1. **`RELAPSE_PREDICTOR_MODE`**: the template uses `rule_based`; the code default is `ml` (Step 9). Pick one deliberately.
2. **`REQUIRE_CLINICAL_REVIEW=true`**: with no approved advisor record (none exists), every non-emergency Health-Bot question returns 503. The app shows the curated fallback, and `/ready` returns 503. Either obtain a real review record or set `false` knowingly.

## Tests (local only)

- **Backend:** **298 passed, 5 skipped** (286 before + 12 new in `tests/test_worker.py`). The worker tests use in-memory fakes and cover:
  - a due check-in sent once and receipted;
  - nothing outside a slot or when disabled;
  - failed delivery releases the lease and retries;
  - one bad schedule doesn't stop the others;
  - an FCM outage logged by type;
  - pending assessment scored and labelled;
  - an unscorable log stays pending;
  - feedback prompt sent once inside 5 min–24 h;
  - assessments-only mode sends nothing;
  - poll clamp;
  - heartbeat;
  - the compose healthcheck uses the same file.
- **Mobile:** `test/features/reminders/fcm_default_delivery_test.dart` (15 new) plus 7 existing reminder tests updated from "always local" to the new push-default rule. Reminder tests: 79 passed. Full suite result in the session report.
- **Local API smoke test** (uvicorn on 127.0.0.1:8765, local dev `.env`): `/health` 200; `/ready` 200 with `relapse_predictor.active = machine_learning`; unauthenticated `/predict/relapse` 401; `X-Response-Time-Ms` and `nosniff` headers present.
- **Preflight:** on `deploy/.env.example`: FAIL for the domain and credential placeholders, as expected. On a temporary env pointing at the local admin key: "service-account key for project quit-companion"; nothing secret printed; the temp file was deleted.
- **Not run:** the real worker against the live Firestore project (it would read/update live data and could push to real users); Docker image builds (no Docker here); any FCM send; any live HTTPS check.

## Deployment instructions (owner)

Requirements:
- a Linux server with Docker Engine and the Compose plugin;
- a public domain whose DNS A/AAAA record points at it;
- ports 80 and 443 open;
- the Firebase Admin key file copied to the server, outside the repo, with permissions restricted.

```bash
git clone <repo> && cd Quit-Companion
cp deploy/.env.example deploy/.env
# edit deploy/.env: SITE_DOMAIN, FIREBASE_CREDENTIAL_FILE (absolute host path),
# GEMINI_API_KEY, FCM_SCHEDULER_TOKEN (optional), RELAPSE_PREDICTOR_MODE,
# REQUIRE_CLINICAL_REVIEW (+ CLINICAL_REVIEW_RECORD), WhatsApp vars if used
python3 backend/tools/check_deploy_config.py deploy/.env   # needs Python + backend deps, or run it inside the backend image
docker compose --env-file deploy/.env -f deploy/compose.yaml up -d --build
docker compose -f deploy/compose.yaml ps            # backend healthy, worker healthy, proxy up
docker compose -f deploy/compose.yaml logs -f worker   # expect "Worker started (notifications=True, poll=30s)"
```

Live verification (do this before recording the URL as working):
```bash
curl https://<SITE_DOMAIN>/health    # {"status":"ok"}
curl https://<SITE_DOMAIN>/ready     # 200 and relapse_predictor details (503 if the review gate blocks)
curl -I http://<SITE_DOMAIN>/health  # Caddy redirects to https
```

Firestore prerequisites (live project changes; owner only):
- Collection-group indexes for the worker queries: `cd backend && python tools/ensure_indexes.py` (dry run), then `--apply`. Or deploy `mobile/firestore.indexes.json`.
- Deploy the updated rules (Step 10): `firebase deploy --only firestore:rules --project quit-companion`.

Then, for Step 11:
```bash
cd mobile
flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=https://<SITE_DOMAIN>
```

End-to-end FCM check on a device:
1. Allow notifications and turn on Daily reminders. The screen should say "Delivered as push notifications."
2. In Firestore, `nicotineUsers/<uid>/reminderSchedules/daily` should have `enabled: true`, and `fcmTokens` should have a token.
3. At the next reminder time, a push arrives (the worker log shows no "Scheduled delivery failed"), and **no** duplicate local reminder.
4. Stop the worker or block the backend before first setup on a fresh install: the screen shows the on-device fallback and local reminders arrive.

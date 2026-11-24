# Physical-device ML test record (2026-11-23)

Manual tests of the three ML integration fixes (`2026-11-23-ml-integration-fixes-record.md`) on a real phone. The owner performed every tap. No craving was submitted by the assistant. Backend evidence and the owner's on-screen confirmation are recorded separately.

## Setup

| Item | Value |
| --- | --- |
| Device | vivo V2022 (adb serial `2881966e`), physical phone, USB debugging |
| APK | `mobile/build/app/outputs/flutter-apk/app-debug.apk`, package `com.quitcompanion.quit_companion` 1.0.0. Built 2026-11-23 20:06:26 with `--dart-define=OTP_BACKEND_BASE_URL=http://127.0.0.1:8000`; contains all three fixes (strings verified inside the APK). Installed with `adb install -r` (update; app data kept). |
| Backend | Local FastAPI (`uvicorn app.main:app --host 127.0.0.1 --port 8000`), one instance. `/ready`: `requested_mode=ml`, `active=machine_learning`, `model_version=emasens-xgboost-v1` |
| Phone → backend | `adb reverse tcp:8000 tcp:8000`; phone-side `curl http://127.0.0.1:8000/ready` returned 200 |
| Account | The owner's existing account (no new account created) |

## Blocker found and resolved: 401 on authenticated requests

- **Symptom (first Test 1 attempt):** `POST /predict/relapse`, `POST /plans/initial` and `POST /notifications/events/badge_earned` all returned **401 Unauthorized**. The app showed "Your entry is saved. The risk assessment will update when the services are reachable." That's the designed offline/pending fallback.
- **Cause:** the local `backend/.env` set `FIREBASE_SERVICE_ACCOUNT_JSON` to a file path on another computer that doesn't exist on this PC. The Firebase Admin SDK couldn't initialize (`FileNotFoundError`), so ID-token verification failed. The app, URL, tunnel and backend availability were all fine.
- **Fix (owner-approved):**
  - The owner generated a new Admin key for the existing `quit-companion` project.
  - It was copied to `C:\Users\HPP\FirebaseSecrets\` (outside the repo), and `FIREBASE_SERVICE_ACCOUNT_JSON` was updated to that path. No other setting changed.
  - The key is outside the repo; `backend/.env` is git-ignored and untracked; no Admin key file is tracked.
  - Admin SDK initialization verified OK for project `quit-companion`. The backend was restarted as a single instance.
- **Follow-ups for the owner:**
  - Delete the two key files left in Downloads.
  - Consider revoking the older (August 2026) key if it's no longer used.

## Results

### Test 1 — save a craving without touching mood sliders or the check-in: **PASS**

- **Backend evidence:** `POST /predict/relapse HTTP/1.1" 200 OK` (after the credential fix). No fallback or model error logged.
- **Owner's on-screen confirmation:** "Medium" risk, label **"Scored by: ML (Experimental)"**.
- Matches the audit expectation: with nothing rated, the model returns medium.
- **Not verified:** the stored Firestore values (mood fields empty, `recoveryContext` empty). Not inspected.

### Test 2 — rate two mood sliders and answer the recovery check-in: **PASS**

- **Backend evidence**, in order:
  - `POST /predict/relapse HTTP/1.1" 200 OK`
  - `POST /recommend/alternative HTTP/1.1" 200 OK` (the call made when the high-risk alternatives screen loads)
  - No fallback or model error, and no app crash in logcat.
- **Owner's confirmation:** POST /predict/relapse returned 200, Firebase authentication worked, the **high-risk alternatives screen opened**, and there was no fallback error or crash.
- **Not verified:** the exact risk label text and the "Scored by" text on the high-risk screen weren't reported, so they aren't claimed here. Also not checked: the exact slider and check-in values entered, and the stored Firestore values.
- For reference only: the model run locally on the suggested inputs (intensity ≈ 8, stressed ≈ 9, anxious ≈ 8, motivation ≈ 2, confidence ≈ 2, discomfort ≈ 6, "Easily available") gives high, p ≈ 0.34–0.47. That's an expectation, not an observation from the phone.

### Test 3 — prediction-source label: **PASS for the ML label (result banner and high-risk screen), physically verified with backend evidence; rule-based labels automated-only**

- **ML (Experimental) on the result banner:** owner-verified on screen in Test 1 and again in Test 4, each backed by a `/predict/relapse` 200 in the backend log.
- **High-risk screen chip, owner's confirmation (final run):**
  - the high-risk alternatives screen opened;
  - the chip under the header read exactly **"Scored by: ML (Experimental)"**;
  - the prediction and alternatives flow worked.
- **Backend evidence for that final run: not found.**
  - The backend log is live: requests made at 22:16 appeared immediately.
  - Its last `/predict/relapse` entry is from Test 4. No `/predict/relapse` or `/recommend/alternative` request arrived after the tunnel was restored (about 22:13) or during Test 5.
  - The phone was connected, the tunnel was active, and the app process was running (a new process ID compared with the start of the session).
  - So the observed screen cannot be matched to a backend request from this run. It may have been a screen from the earlier Test 2 run, or a request that went elsewhere; this is unresolved.
  - **Action:** repeat the high-risk save once while the backend log is watched.
  - **Repeat attempt (about 22:17):** the owner reported the chip "Scored by: ML (Experimental)" again, but again **no `/predict/relapse` or `/recommend/alternative` request reached the backend**. The phone was connected, the tunnel active, the phone got 200 from `/ready`, and the app was in the foreground. The label is set only from a fresh backend response (a pending/offline save shows no label), so the screen seen was most likely the earlier Test 2 result still displayed. Still open.
- **Resolved, verified run (about 22:21):**
  - The owner left the old screen, started a fresh Log Craving form and saved high-risk inputs.
  - **Backend evidence:** `POST /predict/relapse HTTP/1.1" 200 OK`, then `POST /recommend/alternative HTTP/1.1" 200 OK`. No fallback or model error, no crash.
  - **Owner's on-screen confirmation:** the high-risk alternatives screen opened, and the chip under the header read "Scored by: ML (Experimental)".
  - The two earlier reports without backend requests were most likely the Test 2 screen still displayed. They aren't counted as evidence.
- **Rule-based:** not tested on the phone (needs `RELAPSE_PREDICTOR_MODE=rule_based`, an owner decision). **Automated tests only.**
- **Rule-based (ML unavailable):** not tested on the phone (needs a model fault). **Automated tests only.**

### Test 4 — skip the check-in and confirm the craving still saves: **PASS**

- **Backend evidence:** `POST /predict/relapse HTTP/1.1" 200 OK`. No `/recommend/alternative` call followed, consistent with a non-high result. No fallback or model error, no app crash.
- **Owner's on-screen confirmation:**
  - after tapping **Skip check-in**, "Skipped — nothing will be sent for these questions" appeared;
  - the craving saved;
  - the result was **Medium**, with **"Scored by: ML (Experimental)"**.
- Note: the first save attempt showed "Please select a mood, trigger, location, and activity." That's the form's required-field check (four fields weren't all chosen), not a defect; no request was sent.
- **Not verified:** that the stored Firestore `recoveryContext` is empty and `nicotineUsedSinceLastCheckin` is unset. Not inspected. (Automated tests cover this.)

### Test 5 — backend unreachable (offline behaviour): **PASS**

- **Method:** the phone was cut off from the backend by removing the USB tunnel (`adb reverse --remove tcp:8000`). The backend kept running on the PC (`/ready` 200), and a phone-side `curl` to `127.0.0.1:8000` failed to connect. No app, configuration or Firebase change. The tunnel was restored afterwards, and the phone again got a 200 from `/ready`.
- **Owner's on-screen confirmation:**
  - the craving was saved;
  - the app showed "Your entry is saved. The risk assessment will update when the services are reachable.";
  - **no risk level** and **no "Scored by" label** appeared.
- **Backend evidence:** verified that **no `/predict/relapse` request arrived** during the test. The log has four `/predict/relapse` lines since the restart: the assistant's own fake-token 401 check, then Tests 1, 2 and 4. Nothing was added during Test 5. No app crash in logcat.
- **Not verified:**
  - the save duration (not reported);
  - the Firestore document (`riskAssessmentPending`) was not inspected;
  - later re-scoring of the pending entry: the background worker that re-scores pending assessments isn't running in this local setup, so the entry is expected to stay pending here. That's not a defect of this test.

## Status summary

| Test | Physical phone (owner-observed) | Backend log evidence | Automated tests |
| --- | --- | --- | --- |
| 1. Nothing rated, check-in not answered | PASS: Medium, "Scored by: ML (Experimental)" | `/predict/relapse` 200 | Yes |
| 2. Two moods + check-in answered | PASS: high-risk screen opened (label not reported in that run) | `/predict/relapse` 200, `/recommend/alternative` 200 | Yes |
| 3a. ML label on result banner | PASS (Tests 1 and 4) | Matching 200s | Yes |
| 3b. ML label on high-risk screen | PASS: chip "Scored by: ML (Experimental)" on a fresh high-risk save | `/predict/relapse` 200, `/recommend/alternative` 200 (about 22:21) | Yes |
| 3c. "Rule-based" label | Not tested (owner config decision) | — | Yes (automated only) |
| 3d. "Rule-based (ML unavailable)" label | Not tested (needs model fault) | — | Yes (automated only) |
| 4. Skip check-in | PASS: "Skipped" shown, saved, Medium, ML label | `/predict/relapse` 200 | Yes |
| 5. Backend unreachable | PASS: pending message, no level or label | No request arrived (verified) | Yes |
| Stored Firestore values (all tests) | Not inspected | — | Yes (fakes) |

## Delivery checklist items (`docs/SETUP_GUIDE.md` §8)

### #2 — Email/password sign-in with the existing account; Dashboard loads: **PARTIALLY VERIFIED**

- **Owner's report:** item #2 performed on the phone. No specific observations (sign-in result, Dashboard contents) were reported.
- **Evidence available:**
  - no crash or ANR for the app in logcat;
  - Quit Companion's main activity was in the foreground afterwards (about 22:26);
  - throughout the session the app sent valid Firebase ID tokens: after the credential fix, the backend accepted authenticated requests with 200. That shows a working signed-in session, but from earlier in the session, not necessarily this sign-in.
- **Missing:**
  - Email/password sign-in and Dashboard reads go directly to Firebase, not the local backend, so the backend log has **no record** of this sign-in (none expected).
  - This phone doesn't pass the app's own logs to logcat, so `[perf] dashboard_load` (pass condition < 3000 ms on mobile data) **couldn't be measured**.
  - Mobile-data conditions weren't confirmed.
  - The owner's explicit confirmation that sign-in succeeded and the Dashboard showed their data hasn't been recorded.
- **To complete:** the owner's confirmation of sign-in and Dashboard data. The timing criterion stays unmeasured on this device. A phone that shows app logs, or a profile build with timing on screen, would be needed.

## Log notes

- This vivo phone didn't pass the app's own log lines to logcat (0 lines from the app process), so `[perf]` timings couldn't be read. Crash and ANR monitoring of system logs showed none.
- The FastAPI access log records the path and status, but not request bodies or prediction results.
- The phone briefly dropped to "unauthorized" over USB after Test 2. It was re-authorized and `adb reverse` restored before the next test.

# Final master run — audit, verification and hand-off (2026-11-23)

## 1. Consolidated checklist

### Completed and verified locally (automated tests; no physical device)

| Step | Item | Evidence |
| --- | --- | --- |
| 2 | Badge pop-up (combined dialog, pinned button, logout clearing) | Step 2 fix record; Flutter suite |
| 3 | Dashboard risk banner, first-craving prompt, 7/30-day chart | Step 3 record; tests |
| 4 | Crisis Support (verified helplines), professional-help prompt | Step 4 record; tests |
| 5 | Health-Bot topic sources, guards, fallback, 1.5 s Gemini budget | Step 5 record; backend + Flutter tests |
| 6 | High-risk check-in, duplicate prevention, relapse exclusion | Step 6 record; tests |
| 7 | Knowledge Hub CDC videos (links verified on 2026-11-23) | Step 7 record; tests |
| 8 | Offline craving outbox, sync, pending marker | Step 8 record; tests |
| 9 | ML loading/fallback, `/ready` predictor status | Step 9 record; tests |
| 10 | Community validation + strengthened rules | Step 10 record; Flutter + emulator rules tests |
| 11 | HTTPS-only release guard, `key.properties` signing support | Step 11 record (guard verified by real builds) |
| 12 | FCM-default delivery with fallback, worker heartbeat/healthcheck, preflight tool | Step 12 record; tests |
| 13 | Performance instrumentation, local benchmarks, safe optimisations | Step 13 record |
| 14 | Table 4.3 | `docs/FINAL_IMPLEMENTATION_STATUS.md` |

### This run

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| Flutter suite (119 files) | **805 passed, 0 failed, 0 skipped** |
| Backend pytest | **305 passed, 0 failed, 0 skipped**. The 5 tests previously skipped (training-only `pandas`/`pyreadr` missing) now run after installing the versions pinned in `backend/ml/requirements.txt` into the dev venv; numpy/scikit-learn are unchanged |
| Firestore rules (local emulator, `demo-quit-companion`) | **13 passed, 0 failed**. A leftover emulator process was found and stopped afterwards; README note added |
| Debug APK | `mobile/build/app/outputs/flutter-apk/app-debug.apk` (built with `--dart-define=OTP_BACKEND_BASE_URL=http://127.0.0.1:8000`, the existing USB-demo setup) |
| Emulator smoke test (Pixel_6, Android 17, headless) | Installs; launches; welcome screen and Log In screen render with the app theme; **0 fatal exceptions** in logcat. Sign-in not attempted (needs a real account) |
| App → backend from the emulator | **Not verified.** The local API answered on the PC (`/health` 200); requests from the emulator's shell via `nc` returned nothing, both through `adb reverse` and via `10.0.2.2`. Stopped rather than guessing; moved to the phone checklist |
| Release APK | **Not built**: no production HTTPS URL (Step 11 guard) |

### Pending: needs the owner's phone or a second device
See `docs/SETUP_GUIDE.md` §8 (19 checks). None of them has been performed.

### Blocked: needs owner access, approval or money
1. **Server + domain** for Docker Compose/Caddy deployment (costs depend on the provider you choose). This also blocks the production URL, the release APK, FCM delivery tests, production latency and the deployed `/ready` check.
2. **Firebase console changes** (live project): deploy the Step 10 rules, the worker's Firestore indexes, and add the Google Sign-In SHA fingerprints.
3. **Release keystore** creation (your passwords).
4. **Clinical advisor review** record (external person).
5. **Live Gemini calls** (quota) for Health-Bot latency/quality checks, only with your approval.

## 2. Decisions that need the owner

1. **`RELAPSE_PREDICTOR_MODE` in production:** `ml` (code default; experimental XGBoost, not clinically validated) or `rule_based` (deploy template; SRDS rule table). Table 4.3's "Rule-based predictor in production" holds only with `rule_based`.
2. **`REQUIRE_CLINICAL_REVIEW` in production:** `true` (template) blocks non-emergency Health-Bot and coaching (503 → app fallback) until a real advisor record exists. `false` serves unreviewed guidance.
3. **Hosting provider / server and domain** for deployment.
4. **Release keystore:** create one (needed for Play upload), or sideload debug-key release builds only.
5. **Google Sign-In fingerprints:** register this PC's debug SHA-1 `02:92:F9:5C:CA:35:57:A2:04:1B:46:DC:65:F9:3E:0B:09:4D:C3:0E` (and SHA-256 `CF:27:21:0A:D3:DA:56:87:D3:FD:DB:6E:7C:E7:43:0C:8A:C6:E0:46:1E:A9:A5:87:34:B8:9F:25:C5:64:F0:D3`) plus the release key's.
6. **Credential rotation** (section 3): optional, not required by the evidence.
7. **Approval for live Gemini usage** during phone testing (check 12).
8. **Before committing:** whether the untracked `Claude outputs/mobile_test_folder.zip` (187 test files, no credential-like names) and the `baseline_*.txt` files belong in the repository.

## 3. Security audit (Step 0, final stage)

Method: Git history and file inspection, printing only file names, counts and equality booleans. No secret value was printed.

- **Repository visibility:** `github.com/sukainaayesha71/Quit-Companion` is **public** (GitHub API, anonymous request: `private=false`, last push 2026-11-20). History has 2 commits.
- **Firebase Admin key:** never committed. No file name matching admin/service-account/credential patterns in any commit; 0 occurrences of private-key material in history. The local key (`backend/*firebase-adminsdk*.json`) is git-ignored and dockerignored.
- **Gemini key:** never committed. 0 non-empty `GEMINI_API_KEY` assignments in history. It exists only in `backend/.env` (git-ignored, dockerignored). It is **not** the same value as the Firebase client key.
- **Only key in the public history:** the Firebase Android client API key in `mobile/android/app/google-services.json`. This is client configuration meant to ship inside the APK, protected by Firestore rules and Firebase Auth rather than secrecy. Optional hardening: restrict that key to the Android package and SHA fingerprints in Google Cloud Console.
- **Working tree:** none of the uncommitted changes include credential files. `mobile/lib/` and `mobile/test/` are currently untracked and will be added at the final commit; they contain `firebase_options.dart` (client config, same category as above). The untracked zip contains no credential-like file names.
- **Conclusion:** no evidence that the Firebase Admin key or the Gemini key was exposed through Git. Exposure through other channels (chat, email, screenshots, shared drives) can't be checked from the repository. **Rotation isn't required by this evidence**; it remains your choice.
- **If you decide to rotate** (do not run without approval):
  1. Firebase console → Project settings → Service accounts → Generate new private key. Install it on the server/PC, update `FIREBASE_SERVICE_ACCOUNT_JSON` / `FIREBASE_CREDENTIAL_FILE`, restart the backend and worker, check `/ready`, then delete the old key in Google Cloud Console → IAM → Service accounts → Keys.
  2. Google AI Studio / Cloud Console → create a new Gemini API key (restrict it to the Generative Language API, and to the server IP if possible), update `GEMINI_API_KEY`, restart, then delete the old key.
  3. Never paste keys into chats, commits or screenshots.

## 4. Files changed in this run

- `README.md`: testing table (current results), status table, links to the final status and setup guide.
- `docs/SETUP_GUIDE.md` (**new**; the README linked to it but it didn't exist): Firebase/SHA, environment variables, USB demo run, release build, deployment, tests, 19-item phone checklist.
- `docs/FINAL_IMPLEMENTATION_STATUS.md`: verification snapshot; outstanding items (Google Sign-In fingerprints, phone connectivity). Table 4.3 rows unchanged.
- `mobile/test/firestore_rules/README.md`: Windows leftover-emulator note.
- Dev environment only: `pandas` and `pyreadr` installed into `backend/.venv` (pinned in `backend/ml/requirements.txt`; not in the Docker image).
- No application code changed in this run. No Git operations, deployments, Firebase changes, Gemini calls or credential changes.

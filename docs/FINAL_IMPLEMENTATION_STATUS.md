# Final implementation status

*Final version: 2026-11-23 (Step 14). Corrections from the evidence review were applied at the project owner's direction; see the change log below.*

## Table 4.3 — Final Implementation Status

| SRDS Item | Final Implementation | Status |
| --- | --- | --- |
| Relapse prediction trained on PATH and Perski data | Rule-based predictor in production. RF/XGBoost trained on EMASENS_ML only; PATH data not obtainable. ¹ ² | Partly met; not clinically validated |
| Health-Bot using Dialogflow and NLTK | Gemini on the server, grounded in the project's own summaries (not direct CDC/NCI quotations), with links to CDC, NCI/Smokefree.gov and NHS pages, emergency and medication guards, and a curated fallback. This differs from the earlier requirements decision to retain Dialogflow for safety. | Met with a different technology; differs from the recorded Dialogflow decision |
| Medical advisor validates health content | Review-record gate implemented; no real advisor approval exists yet. | External task pending |
| Points, streaks and badges | Six badge tiers, derived points and streaks. Badge congratulations pop-up implemented (badges earned together shown in one dialog). Step 2 fix verified by tests: 149 affected tests passed, including 38 responsive-screen tests and the account-deletion flow; complete Flutter suite 805 passed, 0 failed, 0 skipped (Step 2 record, 2026-11-23). Real-phone verification pending: multiple-badge pop-up, largest font size, and account isolation after logout/login. | Met in code and tests; real-phone verification pending |
| Community with real-time updates | Live Firestore listeners, likes, replies, filter and deletion. Two-device real-time testing and deployment of the updated Firestore rules are pending. | Met in code; two-device test and rules deployment pending |
| 3–5 daily EMA prompts via FCM | Local and remote schedules with a worker (FCM push by default, on-device fallback). Production delivery is pending because the worker is not deployed; live delivery timing not measured. | Implemented at code level; production delivery pending |
| Offline craving capture | Encrypted outbox with automatic sync. Real-device airplane-mode testing is pending. | Met in code and automated tests; real-device test pending |
| Android and iOS | Android only. No iOS project exists in the repository. | Not delivered |
| Latency targets (1.5 s, 3 s, 500 ms) | Timing header, benchmark tool and local/simulated measurements (Step 13). Local and simulated results are not proof of meeting real-device targets; not measured on 4G devices or against a production backend. | Pending measurement |
| Teal colour scheme | The current code uses a cream, sage and terracotta palette. The original SRDS teal requirement and any approval to change it are unverified. | Changed; requirement and approval unverified |

¹ **Open item (unchanged at the owner's direction; still needs a decision).** The code default is `RELAPSE_PREDICTOR_MODE=ml` (packaged XGBoost, falls back to rule-based only if the model can't load). The deployment template `deploy/.env.example` sets `rule_based`, and no production deployment exists yet. "Rule-based predictor in production" holds only if the deployed environment keeps the template value.

² **ML integration (audited and fixed 2026-11-23).** The ML model is genuinely used when `ml` mode is active, and the result screen now shows the backend-reported source ("ML (Experimental)", "Rule-based", or the labelled fallback). Unanswered mood sliders and check-in items are sent as missing, not as default answers, and the recovery check-in is offered on every craving log. Predictions differentiate meaningfully only when the check-in is answered; with it skipped the model returns "medium" for almost every input. Model: EMASENS_ML v2.0.0, 6,124 check-ins from 38 UK adult cigarette smokers; study held-out ROC-AUC 0.84 is **not** real-world accuracy for app users; not clinically validated; not production-approved; not validated for vaping, pouches or hookah. Evidence: `docs/superpowers/plans/2026-11-23-ml-integration-audit.md` and `2026-11-23-ml-integration-fixes-record.md`. Status of the row is unchanged.

## Evidence

| Row | Evidence in the repository |
| --- | --- |
| Relapse prediction | `backend/app/config.py`, `deploy/.env.example`, `backend/app/relapse/`; EMASENS_ML training and PATH HTTP 403 in `docs/ANDROID_COMPLETION.md` |
| Health-Bot | `backend/app/healthbot/service.py` (Gemini, guards, curated knowledge base), `backend/app/healthbot/sources.py` (CDC, NCI, Smokefree.gov, NHS links); no Dialogflow or NLTK code or dependency |
| Medical advisor | `backend/app/healthbot/review.py`; `deploy/reviews/` holds only `README.md` (no approval record) |
| Points, streaks, badges | `mobile/lib/features/rewards/`; Step 2 fix and verified test results in `docs/superpowers/plans/2026-11-23-step2-badge-popup-fix-record.md` |
| Community | `mobile/lib/features/community/data/firestore_community_post_repository.dart` (`snapshots()` listeners); rules in `mobile/firestore.rules` (Step 10, not deployed) |
| EMA prompts | `mobile/lib/features/reminders/`, `backend/app/worker.py`, `backend/app/notifications/`; Step 12 record |
| Offline capture | `mobile/lib/features/craving/data/offline_craving_log_repository.dart`; Step 8 record and tests |
| Android and iOS | `mobile/android/` exists; no `mobile/ios/` |
| Latency | `X-Response-Time-Ms` middleware (`backend/app/main.py`), `backend/tools/benchmark_api.py`, `backend/tools/measure_local_latency.py`, `mobile/test/perf/`; Step 13 record |
| Colour scheme | `mobile/lib/core/theme/app_theme.dart` |

## Verification snapshot (2026-11-23, final local run)

| Check | Result | Kind |
| --- | --- | --- |
| `flutter analyze` | No issues | Local |
| Flutter test suite (all 119 files) | 805 passed, 0 failed, 0 skipped | Local, automated (fake services) |
| Backend `pytest` (incl. worker, ML deployment, Health-Bot) | 305 passed, 0 failed, 0 skipped | Local, automated |
| Firestore rules tests | 13 passed, 0 failed | Local emulator, `demo-` project (not the live project) |
| Debug APK | Built; installs and starts on the Pixel_6 Android 17 **emulator**; welcome and Log In screens render; no crash in logcat | Emulator only, not a physical phone |
| App → backend from the emulator | **Not verified** (the host API answered locally; the in-emulator request tool returned nothing) | — |
| Release APK | **Not built**: no production HTTPS URL | Blocked |
| Google Sign-In fingerprints | This PC's debug SHA-1 is **not registered** in `google-services.json` | Found 2026-11-23, needs a Firebase console change |

Details: `docs/superpowers/plans/2026-11-23-final-master-handoff-record.md`.

## Outstanding manual checks (none complete)

- Backend and worker deployment (Step 12) and the production HTTPS URL.
- Release APK/AAB build with the production URL and a release keystore (Step 11).
- Firestore rules and index deployment (Steps 10 and 12).
- Physical-device verification of Steps 2–13, including the real-device airplane-mode test (Step 8).
- Two-device community/craving propagation test.
- FCM delivery test after deployment.
- Real-device, 4G and production latency measurements (Step 13).
- Clinical advisor review record.
- Badge pop-up real-phone checks (Step 2):
  - multiple badges earned together appear in one pop-up;
  - the layout works at the largest system font size;
  - account isolation after logout and login (no previous-account badge appears).
- Register this PC's debug SHA-1/SHA-256 (and later the release key's) in Firebase for Google Sign-In, then re-download `google-services.json`.
- App-to-backend connectivity on a phone (USB `adb reverse` demo, then the deployed HTTPS URL).
- Owner decisions: production `RELAPSE_PREDICTOR_MODE` and `REQUIRE_CLINICAL_REVIEW`.

## Change log

- **2026-11-23, first version:** table added exactly as supplied by the project owner, with a separate evidence check.
- **2026-11-23, ML integration fixes:** footnote ² added (source label, honest missing inputs, prompted check-in). Row status unchanged.
- **2026-11-23, final master run:** verification snapshot added; Google Sign-In fingerprint and connectivity checks added to the outstanding list. Table rows unchanged.
- **2026-11-23, final (Step 14):** owner-directed corrections to the Health-Bot, badges, community, EMA/FCM, offline capture, iOS, latency and colour-scheme rows. The relapse-prediction row's text is unchanged; its open flag is kept as footnote ¹. The dated record is `docs/superpowers/plans/2026-11-23-step14-table-4-3-final-record.md`.

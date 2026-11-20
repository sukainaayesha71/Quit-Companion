# Android and backend completion record

This record supersedes the missing-code inventory in `FEATURE_AUDIT.md`. iOS is
excluded. Implemented code, live development services, and external validation
are distinguished below; passing tests is not medical or production approval.

## Implemented workflows

| Requirement | Implementation |
| --- | --- |
| Secure authentication | Removed unverified JWT decoding and development-token minting from the real Firebase provider. Missing credentials fail closed. |
| Offline craving capture | Encrypted per-account outbox and history cache; durable offline submission/deletion; automatic retries; idempotent document IDs; account-deletion cleanup. |
| Honest pending assessments | Unavailable predictions are marked pending in history and results. The worker scores synchronized pending records later. |
| Live updates | Firestore subscriptions for community posts, likes and replies, with cancellation and stale-event protection; dashboard craving-change subscriptions. |
| Points and profile badges | Unique persisted milestones yield 10, 50, 150, 300, 600 and 1,200 points. Points are derived from earned badge types, so repeated loads cannot double-award. Profile and reward-history displays added. |
| Personalized alternative API | Authenticated `/recommend/alternative`, contextual Beta-Bernoulli learning from the owner's completed outcome feedback, and offline local ranking fallback. No invented clinical success percentages. |
| Initial, weekly and restart plans | Authenticated `/plans/{initial,weekly,restart}`, saved to private generated-plan documents and connected to onboarding, weekly-plan and relapse screens. Gemini selects actions from a bounded catalogue; unavailable generation has a labeled personalized fallback. |
| Grounded HealthBot | Curated evidence excerpts supplied to Gemini, source links returned and displayed, medication-query/output guards, severe-anxiety emergency detection, bounded generation timeout, fresh disclaimer on each screen visit, contact-detail redaction before sending/persisting. |
| Clinical-review controls | Content-version hash and advisor record validation; optional production gate blocks unreviewed guidance, while emergency escalation remains available. No advisor approval is fabricated. |
| Support access | The floating health/support button was removed at the user's request. Existing Profile help pages remain. |
| Journal management | Entry menus support editing notes and confirmed deletion. Editing preserves dates and relapse metadata; backend deletion atomically recalculates the streak anchor when a relapse entry is removed. |
| Community post deletion | Authors can confirm deletion of their posts. The authenticated backend verifies ownership and recursively removes the post, likes and replies. Other users have no delete control. |
| Remote EMA reminders | Authenticated `PUT /notifications/schedule`, IANA timezone and time validation, 3–5 daily prompts, user opt-in to FCM delivery, and mutually exclusive local/remote scheduling. |
| Background delivery/recovery | Timezone-aware worker, Firestore delivery leases/receipts, five-minute activity outcome prompts, invalid-token removal, and pending-assessment recovery. Outcome feedback can be recorded from activity history. |
| Prospective model data | Optional recovery ratings, cigarette availability and nicotine-use-since-last-check-in; separate research consent, profile withdrawal control and a pseudonymized, opt-in export tool excluding names/email/chat/notes. |
| ML improvement | Corrected participant-specific next-EMA labels; censored tails excluded; grouped development CV; thresholds chosen from development out-of-fold predictions; held-out evaluation, prevalence baseline, participant-bootstrap uncertainty, saved candidate and inference mode. |
| PATH integration preparation | Authorized CSV import with explicit wave, license, feature and outcome-horizon manifest. Longitudinal PATH outcomes are not silently pooled with EMA labels. |
| Deployment and transport | Non-root Docker image, API/worker/TLS proxy Compose configuration, restart policy, health/readiness endpoints, response-time headers, latency measurement tool and local process supervision. Release Android builds disallow cleartext HTTP; debug USB builds retain localhost HTTP. |

## Verified results

- Full Flutter suite: **543 passed**.
- Final backend suite: **219 passed**.
- Dart analysis: no errors; final style-only follow-up checks are recorded in the session.
- Android debug APK built successfully with `OTP_BACKEND_BASE_URL=http://127.0.0.1:8000`.
- Local API health verified on port 8000; OpenAPI exposes the new plan,
  recommendation and scheduling endpoints. USB forwarding configured for device
  `28261FDH200448`.
- Docker configuration supplied, but the Docker engine was not running on this
  machine; a container build and public HTTPS deployment were not verified.
- SDK/Kotlin dependency migration warnings remain; they did not prevent the
  successful Android build. Existing NumPy/joblib deprecation warnings remain.

## ML result and limits

The new internally evaluated extended-input XGBoost candidate achieved:

| Measure | Held-out result |
| --- | --- |
| ROC-AUC | 0.8406 |
| Participant-bootstrap 95% ROC-AUC interval | 0.6958–0.9137 |
| Average precision | 0.2309 |
| Positive outcome prevalence / constant baseline AP | 0.0510 |
| Precision at selected high-risk threshold | 0.1599 |
| Recall at that threshold | 0.7231 |
| Brier score | 0.0439; constant baseline 0.0488 |

These are **internal EMASENS results for adult cigarette quit attempts**, not
clinical accuracy or an independently validated app-population model. Many
high-risk flags are false positives. Vaping, pouches and hookah are not validated.
The default production score remains rule-based. An operator can explicitly
evaluate the candidate with `RELAPSE_PREDICTOR_MODE=candidate` after generating
`backend/ml/models/app_candidate.joblib`; missing required ratings are rejected.

The reproducible aggregate report is `ML_CANDIDATE_EVALUATION.json`. Run:

```powershell
cd backend
.venv/Scripts/python.exe -m ml.fetch_data
.venv/Scripts/python.exe -m ml.evaluate_candidate
```

The official PATH public-use archive returned HTTP 403 during the download
attempt. No restricted access was bypassed, and no claim is made that a model
has been trained on PATH. `python -m ml.import_path approved-mapping.json` is
available when an authorized, documented export can be obtained.

## Running and deploying

For the current USB development setup, run from `backend/`:

```powershell
.venv/Scripts/python.exe tools/local_services.py --worker
adb reverse tcp:8000 tcp:8000
```

This supervises the API and pending-assessment recovery. It intentionally does
not send push messages to users. To run the full opt-in notification worker,
an operator explicitly uses `python -m app.worker` or the Compose worker.
The notification transport requires opted-in device tokens and a continuously
running worker; Android/FCM can delay delivery, so exact delivery timing is not
guaranteed.

For deployment, copy `deploy/.env.example` to an uncommitted `deploy/.env`, set
the domain, server credentials and secret-file paths, and run
`docker compose --env-file deploy/.env -f deploy/compose.yaml up -d --build`.
The production example requires an actual clinical-advisor review record from
`deploy/reviews/README.md`. Its catalogue approval does not by itself approve
every generated paraphrase or clinically validate an ML model.

Required collection-group indexes are declared in `mobile/firestore.indexes.json`.
The additive `backend/tools/ensure_indexes.py` preserves existing indexes and
supports dry-run/default and explicit `--apply` modes. Firestore rules and public
deployment must be reviewed for the target environment before publication.

`backend/tools/benchmark_api.py` measures actual authenticated API p50/p95 using
a dedicated test-account token supplied through an environment variable. The
SRDS 4G dashboard latency and FCM arrival targets have not been measured on a
representative network/device fleet and must not be claimed as guaranteed.

## External requirements that cannot be manufactured in code

- Actual medical-advisor review of health guidance and the generated-answer protocol.
- Authorized PATH data with the required variables and a documented mapping.
- Independent prospective app-population validation before promoting the ML candidate.
- Public deployment/domain/TLS setup and real FCM delivery/latency verification.

The implemented flows are ready for Android development testing; these external
requirements remain release criteria rather than completed approvals.

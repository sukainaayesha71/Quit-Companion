# Backend + Dataset + AI/ML Pipeline — Audit & Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Phase C (training) tasks must not start until Open Decisions 1-2 are resolved by the user.**

> **FINAL STATUS (2026-08-17, user-approved) — read this first:**
> - **Production relapse-risk predictor: the rule-based decision table** (`RuleBasedPredictor`, SRDS §5.5.1), served via `/predict/relapse`, Firebase-auth-gated. Unchanged, unreplaced.
> - **ML (RandomForest/XGBoost on EMASENS_ML): experimental/research evaluation only** — not deployed, not wired into any endpoint. Kept for research/reproducibility (§13-14).
> - **Why not deployed:** the only model with real separative power (`full_ema`, AUC 0.852) needs fields `CravingLog` doesn't collect (demographics, substance availability, structured location/activity/social-context, motivation/confidence/pain, prior-lapse history). The model trainable on what the app *can* actually supply — even after extending `CravingLog` with all ten EMASENS mood dimensions (§14) — still scores at or below chance (AUC 0.48-0.57 across four CravingLog-compatible variants). Deploying it would not be justified. **No claim of clinical validity is made anywhere in this project.**
> - **Documentation conflict flagged, not silently resolved:** see §14's "Documentation conflict" subsection — the SRDS's original `shall`-worded AI-model requirement, and the SDD FR5/§2 wording that still frames the trained model as "primary... deferred pending dataset validation," both read as if deployment is still an open future path. This final status closes that out as a considered decision (data/features evaluated, deployment not justified), not a pending item — flagged for you to decide whether the SDD/SRDS text itself should be updated; not changed here.

**Goal:** Audit exactly what exists vs. is missing in Quit-Companion's AI/ML and backend layer, then define an ordered path to a production-ready relapse-risk service — without downloading data, training a model, or touching Flutter/Modules 1-5/auth in this pass.

**Architecture:** No architecture change proposed here beyond what SDD §2 already specifies: FastAPI stays the single backend surface for both AI-serving and OTP; the relapse-risk endpoint's contract (`POST /predict/relapse`, `{risk_level}`) stays stable so today's rule-based fallback and a future trained model are interchangeable behind it, exactly as SDD §2's own diagram shows (`F -.->|primary, deferred| I[Trained ML Model]`, `F -->|fallback, active today| J[Rule-Based Decision Table]`).

**Tech Stack:** Existing — FastAPI, Pydantic, pytest (backend); `http` package (Flutter). Any ML work would add `scikit-learn`/`xgboost`/`pandas`/`numpy`/`joblib` to `backend/requirements.txt` — not added in this pass (Phase C, blocked).

**Spec:** `docs/Quit_Companion_SDD.md` §2 (System Architecture), §3 (FR5), §9-10 · `docs/srds.txt` §5.5 (Algorithm Viewpoint), §3.1 (FR table), NFR Testability · project memory `dataset-decision-relapse-prediction`.

## Global Constraints

- **No dataset download, no model training, no code changes in this pass** — audit and plan only, per explicit instruction.
- **The rule-based decision table is not a placeholder to "fix" — it is the current, sanctioned, sign-off'd implementation.** SDD §2: *"Any implementation work can proceed against the fallback now; it must not be described as 'the AI model' without that caveat."* This plan does not touch its logic (already verified correct against SRDS §5.5.1 and fully tested).
- **PATH Study, Perski et al. 2023, and Kaggle Smoker Status are the only sanctioned dataset candidates** (project memory, 2026-08-10 decision). NHANES/SAMHSA/UCI (the original Proposal's list) are explicitly **not** authoritative unless separately re-validated — don't reach for them as a "faster" substitute.
- **No FR in the SDD specifies numeric evaluation-metric targets.** The only requirement is SRDS's generic NFR: *"accuracy evaluation using held-out test datasets."* Any specific metric/threshold in this plan is a **proposal**, not a documented requirement — flagged as Open Decision 4.
- **Modules 1-5, Flutter UI, authentication, and Google Sign-In are untouched** — this plan is backend/`backend/` only, plus documentation. The one candidate exception (securing `/predict/relapse` with auth) is called out as Open Decision 3, not silently done.
- **The WhatsApp OTP backend (phone auth) must keep passing its existing 43 tests unmodified** — this plan adds new backend modules alongside it, never edits `app/otp/`, `app/whatsapp/`, `app/phone.py`, `app/routers/phone_auth.py`, or `app/firebase_identity.py`.

---

## 1. Current Architecture

Per SDD §2 (verified against the actual repo, not just the doc):

```
Flutter Mobile Client
  --HTTPS/JSON--> FastAPI Backend (backend/)
                    |-- /auth/phone/send-otp, /auth/phone/verify-otp  (WhatsApp OTP -> Firebase Admin SDK custom token)
                    |-- /predict/relapse                              (rule-based fallback — the ONLY AI-serving endpoint that exists)
                    |-- /health
  --Firebase SDK--> Firestore (all persistence except OTP's in-memory store)
  --Auth---------> Firebase Authentication
```

The SDD's own diagram shows two *planned* FastAPI concerns beyond OTP — "Habit Replacement Service" and "Dialogflow NLP query" — **neither exists in the repo.** Confirmed by direct search: no `habit`/`recommend`/`dialogflow`/`healthbot` module anywhere under `backend/app/`. Both belong to Mehreen's modules (Alternatives & Habit Replacement, Health-Bot) per SDD §2.1 — consistent with the ownership audit from the prior Module 6 investigation. **Out of scope for this plan.**

## 2. Existing Backend Status

**Directory (excluding `__pycache__`/`.venv`):**
```
backend/
  app/
    __init__.py
    config.py              — Settings (pydantic-settings), reads .env
    dependencies.py        — process-wide singletons (OTP, WhatsApp, Firebase identity)
    firebase_identity.py   — Admin SDK: get-or-create user + mint custom token
    fake_firebase_identity.py — test double
    main.py                — FastAPI app, registers phone_auth + relapse routers, GET /health
    phone.py                — phone-number normalization/validation
    otp/
      service.py, store.py  — OTP generation/hashing/expiry/attempt-limiting
    relapse/
      service.py             — predict_relapse_risk(): the rule-based fallback (SRDS §5.5.1)
    routers/
      phone_auth.py          — POST /auth/phone/send-otp, /auth/phone/verify-otp
      relapse.py              — POST /predict/relapse
    whatsapp/
      client.py, meta_client.py, fake_client.py — Meta Cloud API integration
  tests/
    conftest.py, test_otp_service.py, test_phone.py,
    test_phone_auth_router.py, test_relapse_router.py, test_relapse_service.py
  requirements.txt, .env.example, README.md
```

**Existing endpoints (complete list — confirmed from `main.py` + router files, nothing else registered):**
| Method | Path | Purpose | Auth required |
|---|---|---|---|
| GET | `/health` | Liveness check | None |
| POST | `/auth/phone/send-otp` | Generate + send OTP via WhatsApp | None (pre-auth by nature) |
| POST | `/auth/phone/verify-otp` | Verify OTP, mint Firebase custom token | None (pre-auth by nature) |
| POST | `/predict/relapse` | Rule-based relapse-risk scoring | **None** — flagged, see Open Decision 3 |

**Request/response schemas** (Pydantic, `routers/relapse.py`): `PredictRelapseRequest{intensity: int 1-10, mood: Literal[5 values], trigger_category: Literal[5 values], last_24h_count: int >=0}` → `PredictRelapseResponse{risk_level: "low"|"medium"|"high"}`. Matches the Flutter `CravingLog` schema's vocabulary exactly (confirmed against `mobile/lib/models/mood.dart`, `trigger_category.dart`).

**Model-loading mechanism:** none exists — there is no model artifact anywhere in the repository (confirmed via filesystem search for `*.pkl`, `*.joblib`, `*.h5`, `*.csv`, `*.parquet`, `*.ipynb`, `*dataset*` — zero matches outside this plan's own prose). `predict_relapse_risk()` is a pure Python function with hard-coded if/else thresholds, no I/O, no loaded artifact.

**Environment variables** (`.env.example`/`config.py`): all WhatsApp Business Platform + Firebase Admin SDK + OTP-policy. **Zero ML-related environment variables exist** (no dataset path, no model path, no training config, no feature-store URL).

**Current test coverage:** 43 backend tests total, all passing (verified this session: `pytest -q` → `43 passed`). Relapse-specific: 11 parametrized rule cases + 2 dedicated (`test_relapse_service.py`) + 5 endpoint/validation cases (`test_relapse_router.py`). No tests exist for anything ML-pipeline-related, because nothing ML-pipeline-related exists yet.

**Missing production pieces** (relative to "production-ready AI backend," independent of the dataset question):
- No authentication/authorization on `/predict/relapse` (Open Decision 3).
- No model loading/versioning mechanism (moot until a model exists, but the *mechanism* itself — how a future model file gets loaded, hot-swapped, or rolled back — isn't designed).
- No structured logging/observability on predictions (can't detect drift, can't audit what was returned to whom).
- No rate limiting on any endpoint.
- No CI pipeline running `pytest` on push (not found in repo; out of scope unless requested).

## 3. Dataset Inventory

| Dataset | Role (SRDS/memory) | Present locally? | Required features (per SRDS) | Target/label | License/access | Preprocessing needed |
|---|---|---|---|---|---|---|
| **PATH Study** (Population Assessment of Tobacco and Health) | **Primary candidate** | **No** — zero dataset files anywhere in repo | Not yet inspected — SRDS never lists PATH's actual variable names, only asserts it's suitable | Not yet inspected | **Restricted-use**, NIH/FDA-administered — requires a formal data-use application, likely weeks-long approval, institutional/PI requirements typically apply | Unknown until access granted and variables inspected |
| **Perski et al. (2023)** | Secondary candidate | **No** | Not yet inspected | Not yet inspected | Not yet checked (academic publication dataset — may or may not have public supplementary data) | Unknown |
| **Kaggle "Smoker Status" dataset** | Secondary candidate | **No** | Not yet inspected — and by name this looks like a **smoker-vs-non-smoker classification** dataset (health/biometric features), not a **craving-relapse-event** dataset with intensity/mood/trigger/frequency features the app actually collects | Likely smoker/non-smoker binary label — **probably the wrong target entirely** for FR5's relapse-risk-during-a-craving-event use case, but unconfirmed without inspection | Public on Kaggle (Kaggle's standard terms), likely no restricted-access barrier | Unknown — feature-mapping to `CravingLog`'s schema is doubtful even before inspecting |
| NHANES / SAMHSA-NSDUH / UCI Smoking-Drinking | Original Proposal's list | **No** | N/A | N/A | N/A | **Explicitly not authoritative** per memory decision (2026-08-10) — do not substitute these in without a fresh decision |

**Bottom line: zero datasets are present, validated, licensed, or feature-inspected.** This is not a partial-progress item — it is a hard blocker on any real training work, and has been formally deferred since the SDD's first draft (§0 Document Control: *"PATH Study access, licensing, and variable/outcome compatibility... Not validated. No dataset is confirmed usable yet."*).

**A structural tension worth surfacing now, before any dataset work starts:** the app's actual `CravingLog` schema (already shipped in Modules 1-3, verified/tested) collects exactly `intensity (1-10)`, `mood` (5-value enum: stressed/bored/sad/happy/social), `triggerCategory` (5-value enum: stress/afterMeal/socialPressure/boredom/other), `locationContext` (free text), `activity` (free text), `notes`, plus derived `last24hCount`. **None of the three candidate datasets have been confirmed to contain matching fields.** A trained model needs either (a) a dataset whose features can be honestly mapped to this exact schema, or (b) changing what the app collects to match the dataset — the second option touches Module 3's already-verified UI/form, which is explicitly restricted by this session's constraints. This is folded into Open Decision 1 below, not decided here.

## 4. ML Model Status

**Specified in SRDS/SDD:** scikit-learn/XGBoost — "Random Forest/XGBoost classifiers fine-tuned on PATH and Perski et al. datasets" (SRDS External Services table; SDD §2: *"primary target is a real trained model (RandomForest/XGBoost candidates)"*).

**Input features (as specified, informally):** craving intensity, mood, trigger category, craving-history frequency/timing. (SRDS §5.5.2's pseudocode comment names only "Fine-tuned XGBoost/RandomForest model on PATH + Perski datasets" — no formal feature list beyond what the rule-based fallback already consumes.)

**Prediction target:** originally binary (SRDS: "High Risk / Low Risk"); **SDD §3 FR5 formally corrects this to categorical High/Medium/Low**, explicitly **not** a numeric confidence score. This correction is authoritative and must carry into any future trained model — a model producing a probability/score would need an explicit binning decision to satisfy FR5 as written.

**Preprocessing:** not specified anywhere in either document — entirely undefined until a dataset is chosen and inspected.

**Training process:** not specified — no pipeline, no train/val/test split methodology, no hyperparameter approach documented anywhere.

**Evaluation metrics:** not specified beyond the generic NFR ("accuracy evaluation using held-out test datasets"). No target thresholds. See Open Decision 4.

**Expected output:** `RiskLevel` (low/medium/high) — must match the *existing* `RelapseRiskLevel` Dart enum / `RiskLevel` Python enum exactly, since the endpoint contract is already fixed and consumed by shipped Flutter code.

**Model serialization format:** not specified. See Open Decision 5.

**Where it should live:** not specified. Given the existing pattern (`app/relapse/service.py` holds all relapse logic), a trained model's loading code would live alongside it — see File Structure below.

**Is any model already trained?** **No.** Exhaustive filesystem search (`.pkl`, `.joblib`, `.h5`, `.onnx`, `.ipynb`, any `*dataset*`/`*model*` directory) found nothing anywhere in the repository, and `backend/requirements.txt` has no ML library (`scikit-learn`, `xgboost`, `pandas`, `numpy` are all absent). There is nothing to inspect instead of building — this would be a from-scratch effort once a dataset is available.

## 5. Training Pipeline

**Status: does not exist.** No script, no notebook, no data directory, no experiment-tracking config. This section of the plan is necessarily a *proposed* pipeline shape for Phase C (blocked), not an audit of something present:

1. Ingest the approved dataset (Open Decision 1) into a `backend/ml/data/` directory (git-ignored — raw data is never committed).
2. Feature engineering: map dataset columns to the app's `intensity/mood/triggerCategory/last24hCount` schema (or the dataset's native schema, if Open Decision 1 accepts a schema change — see the tension noted in §3).
3. Train/validation/test split (stratified by the High/Medium/Low label, given likely class imbalance — High-risk events are presumably rarer).
4. Train candidate models (RandomForest, XGBoost per spec) with a fixed random seed for reproducibility.
5. Evaluate against Open Decision 4's metrics; select the winning candidate.
6. Serialize per Open Decision 5; store under `backend/ml/models/` (git-ignored, deployed as a build artifact, not committed to source control — standard practice for binary model files, and consistent with this repo's existing "never commit secrets/`.env`" discipline).

**None of this is built or startable until Open Decision 1 resolves.**

## 6. Model Evaluation

No held-out evaluation harness exists (there's nothing to evaluate yet). Proposed shape once a model exists: a `backend/ml/evaluate.py` script computing per-class precision/recall/F1 (not just accuracy — see Open Decision 4's rationale) against the held-out test split, with results written to a versioned report file so future retraining can be compared against prior runs.

## 7. FastAPI Integration

The integration seam is already correctly designed for this — `predict_relapse_risk()` is a plain function called from `routers/relapse.py`; swapping it for `model.predict(...)` behind the same function signature requires **zero changes to the router, the Pydantic schemas, or the Flutter client.** This is by explicit SDD design (§2's diagram shows fallback/primary as interchangeable behind one endpoint) and should be preserved, not restructured.

Proposed (Phase B, buildable now, no dataset needed): introduce a `RelapsePredictor` protocol/interface in `app/relapse/` with two implementations — `RuleBasedPredictor` (today's logic, renamed/wrapped, behavior-identical) and a `ModelPredictor` stub that raises `NotImplementedError` until Phase C. A settings flag (`RELAPSE_PREDICTOR_MODE=rule_based|model`, defaulting to `rule_based`) selects between them at startup. This lets the "swap mechanism" be built, tested, and reviewed *before* any model exists, de-risking the eventual swap — without training anything now.

## 8. Flutter Integration — Traced End-to-End

```
LogCravingScreen (docs/UI_Design/log craving 6.png)
  -> user fills intensity/mood/trigger/location/activity/notes, taps Submit
  -> CravingLogController.submitCraving()
       -> CravingLogRepository.countLoggedSince(userId, now - 24h)   [Firestore query]
       -> RelapsePredictionClient.predict(intensity, mood, trigger, last24hCount: priorCount + 1)
            -> HttpRelapsePredictionClient: POST {baseUrl}/predict/relapse
                 -> backend: predict_relapse_risk() [RULE-BASED, see below]
                 <- {risk_level: "low"|"medium"|"high"}
       -> CravingLog(..., relapseRiskScore: riskLevel) saved via CravingLogRepository.logCraving()  [Firestore write]
       -> lastRiskLevel exposed on the controller
  -> UI: RiskResultBanner shown inline (all levels)
  -> UI: if riskLevel == high -> navigate to HighRiskScreen (disabled "Try This" alternative buttons — FR7/Alternatives not built; skip link back to Dashboard)
```

**Explicit answer to "is this real ML, deterministic logic, or a placeholder?":** it is **deterministic, rule-based logic** — a hand-written decision table faithfully implementing SRDS §5.5.1 exactly (verified line-by-line against the SRDS table: intensity≥8→High, stressed+socialPressure→High, ≥3 logs/24h→High, 5-7+bored→Medium, else Low). It is **not** a placeholder or mock in the sense of "fake code standing in for something broken" — it's the real, tested, currently-shipping business logic, explicitly sanctioned by the SDD as the active implementation until a trained model is validated. It is also **not** any form of trained ML model — no learned parameters, no dataset was involved in producing it, and it must never be described to a reader as "the AI model" per the SDD's own explicit caution.

## 9. AI/ML Gap Analysis

**Already implemented:**
- Rule-based relapse-risk fallback: backend service, endpoint, Pydantic validation, Flutter client, full request/response wiring, end-to-end tested (Flutter + backend).
- FastAPI app skeleton, settings/config pattern, dependency-injection pattern, fake-client testing pattern — all reusable for any future ML endpoint.
- WhatsApp OTP backend (unrelated to AI, but part of "backend production-readiness") — functionally complete, 43 passing tests.

**Partially implemented:**
- FastAPI's "AI serving" role (SDD §2): the service exists and serves relapse-risk, but only via the fallback path — the trained-model path has zero code.
- Endpoint security posture: OTP endpoints are legitimately unauthenticated (pre-auth by nature); `/predict/relapse` is unauthenticated too, but that one *is* called by an already-signed-in user and arguably shouldn't be open to the public internet (Open Decision 3).

**Missing:**
- Any code for: dataset ingestion, feature engineering, model training, model evaluation, model serialization/loading, model versioning.
- ML dependencies in `requirements.txt`.
- Authentication on `/predict/relapse`.
- Observability/logging for predictions (can't audit or detect drift on either the current rule table or a future model).
- Habit-Replacement recommendation service and Dialogflow NLP integration (SDD §2's other two planned FastAPI concerns) — **confirmed out of scope**: both belong to Mehreen's modules (Alternatives & Habit Replacement, Health-Bot), consistent with the prior Module 6 ownership audit. Not addressed by this plan.

**Blocked by missing data/infrastructure:**
- All of Phase C (dataset ingestion through trained-model deployment) is blocked on Open Decision 1 — no dataset is licensed, accessible, or feature-validated. PATH Study specifically requires an external, likely multi-week, restricted-access application process outside this tool's ability to perform.
- Model evaluation is blocked on both Open Decision 1 (data) and Open Decision 4 (metrics/targets — none currently documented).

---

## Unresolved Decisions — need your approval before Phase C can start (Phase A/B below don't require these)

**1. Dataset path — which of the following do we pursue?**
- **(a) Apply for PATH Study restricted access.** Most SRDS-aligned, but a genuinely slow external process (NIH/FDA data-use agreement, likely institutional sign-off) — I cannot do this for you; it requires you (and possibly your supervisor/institution) to initiate an application.
- **(b) Inspect Perski et al. (2023)** for public supplementary data and feature/license compatibility — faster to check, unconfirmed whether usable data exists publicly.
- **(c) Inspect the Kaggle "Smoker Status" dataset** — fastest to obtain, but by name it's very likely a smoker/non-smoker classification dataset, not a craving-relapse-event dataset; its features and target probably don't match FR5's actual need even before inspection. Needs honest evaluation, not adoption-by-convenience.
- **(d) Formally adopt the rule-based decision table as the permanent, final relapse-risk implementation** for this project's scope, closing out the "primary model, deferred" line in SDD §2/§10 rather than continuing to defer it. This is a legitimate FYP-scope decision — plenty of production systems ship a well-tested deterministic model — but it's a real decision, not a default I should assume.

**My recommendation:** (d), unless you have a specific reason to believe PATH access is realistically obtainable in your project timeline — the restricted-access process is the single biggest risk to ever shipping a real trained model here, and (b)/(c) both carry the same "does this dataset's schema even match what the app collects" risk flagged in §3. **I am not choosing this for you** — it directly determines whether Phase C ever starts.

**Why it matters:** everything in §5/§6/§7's "Phase C" depends on this; no code should be written against an assumed dataset.

**2. If (a), (b), or (c) above — do you want me to inspect a specific dataset's public documentation/schema (not download raw data, just read published variable lists/codebooks) to validate feature compatibility before you commit to an access application?**
This is research, not a download — I can do this without violating "no external datasets without approval" if you scope it explicitly (e.g., "look up Kaggle Smoker Status's column list and license terms, don't fetch the actual CSV").

**Why it matters:** avoids spending weeks on a PATH application only to discover its variables don't map to `CravingLog`'s schema, or discover Kaggle's dataset doesn't either.

**3. Should `/predict/relapse` require authentication (Firebase ID token verification via the Admin SDK, already available in this backend for the OTP flow)?**
**My recommendation: yes** — it's currently callable by anyone on the network with no Firebase session, unlike every Firestore write in this app (all gated by `request.auth.uid == userId`). Adding verification would mean: Flutter attaches the user's Firebase ID token as a header, the backend verifies it via `firebase_admin.auth.verify_id_token`, mirroring `firebase_identity.py`'s existing Admin SDK usage. This *does* touch `HttpRelapsePredictionClient` (Flutter) — flagged explicitly since your constraints say "don't change Modules 1-5 unless the audit finds a genuine bug," and I'm treating an open unauthenticated AI endpoint as close enough to a genuine gap to raise, not close enough to fix without asking.
**Alternative:** leave it open for now (matches OTP endpoints' current unauthenticated posture) and revisit later.

**4. What evaluation metrics/thresholds should gate a future model before it's allowed to replace the rule-based fallback?**
Nothing is specified in SRDS/SDD beyond "accuracy evaluation using held-out test datasets." For a 3-class, almost-certainly-imbalanced target (High-risk events are presumably the minority class), **raw accuracy is a poor/misleading metric** — a model that always predicts "Low" could score high accuracy while being useless. **My recommendation:** per-class recall and F1, with a specific floor on **High-risk recall** (missing a true high-risk case is the costlier failure mode for this app's purpose) — but I'm not setting a numeric floor (e.g., "recall ≥ 0.85") myself; that's a product/safety call for you to set once real data exists.

**5. Model serialization format, once training is unblocked?**
**My recommendation:** `joblib` (the scikit-learn-ecosystem standard, handles both RandomForest and XGBoost via `xgboost`'s sklearn-compatible API) over raw `pickle` (joblib is more efficient for numpy-heavy objects) or ONNX (adds conversion complexity with no clear benefit at this project's scale). Low-stakes — flagged for completeness, not blocking.

---

## Resolved decisions (2026-08-17) — Decisions 1-5 confirmed by user

1. **Dataset:** do not apply for PATH access yet. Research public compatibility first (Decision 2 below) before any commitment.
2. **Dataset compatibility research: approved**, read-only (published docs/codebooks/license terms only — no raw data download, no restricted-access application, no dataset adopted). Comparison delivered in a new §11 below.
3. **Firebase auth on `/predict/relapse`: approved.** Design documented here before implementation, per instruction.
4. **Evaluation metrics: use per-class precision/recall/F1, explicitly report High-risk recall. No numeric threshold invented** — marked a future product decision, not set here.
5. **Model format: `joblib`, only once a real model is trained.** No placeholder/fake model is created to satisfy the pipeline shape.

### Auth-threading design (Decision 3) — documented before implementation

**Goal:** `/predict/relapse` must reject anonymous requests, while reusing the *existing* Firebase Auth session already established by Modules 1-3 — no new sign-in flow, no new token-exchange mechanism, no change to `FirebaseAuthRepository` or any auth screen.

**Flow:**
1. **Flutter (`HttpRelapsePredictionClient`):** gains an optional constructor parameter `Future<String?> Function()? getIdToken`, defaulting to `() => fb.FirebaseAuth.instance.currentUser?.getIdToken()`. Before POSTing, it awaits this and attaches `Authorization: Bearer <token>` if non-null. The default reads the ID token from whichever session is already active (email/password, phone/OTP, or Google) — all three already populate `FirebaseAuth.instance.currentUser` identically, so this works unmodified for every existing sign-in method.
2. If no token is available (defensive-only case — `CravingLogController` is only reachable post-auth in practice), the request is sent without the header; the backend rejects with 401, surfaced to the app as the existing `RelapsePredictionException` (no new exception type).
3. **Backend (`firebase_identity.py`):** `FirebaseIdentityProvider` (the existing ABC) gains one new method, `verify_id_token(id_token: str) -> str` (returns the uid). `AdminSdkFirebaseIdentityProvider` implements it via `firebase_admin.auth.verify_id_token(id_token, app=app)`, **reusing the same lazily-initialized `_ensure_app()` Admin SDK app** already used for custom-token minting (a second `initialize_app` call with the same name would raise — sharing the instance avoids that). `FakeFirebaseIdentityProvider` implements it via a simple in-memory `dict[str, str]` (token → uid) that tests populate directly, no real SDK involved.
4. **Backend (new `app/firebase_auth_dependency.py`):** a small FastAPI dependency `require_firebase_uid(authorization, provider)` — parses `Bearer <token>` from the `Authorization` header, calls `provider.verify_id_token`, and raises `HTTPException(401)` on a missing header, malformed header, or verification failure. Kept in its own module (not inline in `routers/relapse.py`) since it's generic enough to reuse if another endpoint needs the same gate later.
5. **`routers/relapse.py`:** the endpoint gains `uid: str = Depends(require_firebase_uid)`. The uid is not otherwise used (the request body carries no `userId`, and the prediction doesn't depend on who's asking) — this is purely an authentication gate, matching what was asked ("should not accept anonymous prediction requests"), not a new authorization/ownership check.
6. **Unchanged:** `phone_auth.py`'s two endpoints stay exactly as they are — they are legitimately pre-auth (that's their entire purpose) and are explicitly out of scope for this change.

**Response contract is unchanged** (`{risk_level}`) — only the request now needs one additional header, attached transparently by the Flutter client. `CravingLogController` and everything above it in the Flutter stack (screens, `FakeRelapsePredictionClient`-based tests) needs **zero** changes, since `RelapsePredictionClient`'s abstract `predict()` signature doesn't change.

**Phase B status: implemented and verified (2026-08-17).** Backend `pytest`: 69/69 passing (43 pre-existing + 26 new: predictor-equivalence + auth-gate tests). Flutter `flutter test`: 203/203 passing (201 pre-existing + 2 new: Authorization-header-attached / header-omitted-when-no-token). `flutter analyze`: 0 issues. No existing test was modified in a way that changes what it asserts — `test_relapse_router.py`'s five original cases now also supply a valid fake token (required since the endpoint is no longer anonymous) but still assert the exact same response bodies as before.

---

## 11. Dataset Compatibility Research (2026-08-17) — read-only, no downloads, no accounts created

Per Decision 2 (approved): public documentation, codebooks, dataset-description pages, and the Perski et al. paper itself were inspected. **No raw data was downloaded, no PATH access application was started, no account was created on any restricted-access system.**

| Dataset | Target/Label | Relevant Features | Relapse/Craving Relevance | Access | License/Restrictions | Compatibility with `CravingLog`/`/predict/relapse` | Recommendation |
|---|---|---|---|---|---|---|---|
| **PATH Study** (ICPSR, waves 1-4.5+, ~67,276 participants) | No per-event "lapse" label. Derived variables classify respondents into tobacco-use-status categories (current/former/never user, by product) **per survey wave** (roughly annual), not per craving moment. | Survey-based tobacco-use history/patterns, demographics, product-use status; **no** craving-intensity, mood, trigger, or activity-context fields at the momentary level. | **Low.** PATH studies population-level tobacco-use trajectories across ~yearly survey waves — a fundamentally different *grain* from "predict risk from one logged craving right now." | Two tiers, not one: **Public-Use Files** (ICPSR account + standard terms, no lengthy application) and **Restricted-Use Files** (formal NIH/FDA-administered data-use agreement, materially slower/uncertain — this is the tier the earlier project memory's caution refers to). Public-use tier is more accessible than previously assumed, but doesn't change the feature/grain mismatch below. | ICPSR standard academic data-use terms (public-use tier); restricted-use tier carries its own binding data-handling agreement. | **Poor.** No plausible mapping from annual-survey-wave variables to `intensity(1-10)/mood/triggerCategory/last24hCount`. Using PATH would mean designing a materially different model (population relapse trend, not per-craving risk) — not a drop-in for FR5. | **Do not pursue for this endpoint's exact target**, even at the public-use tier. Might be relevant to a *different*, not-yet-specified population-trend feature — out of scope here. |
| **Perski et al. (2023)** / Smoke Free app lapse dataset (*Nicotine & Tobacco Research* 25(7):1330-1339) | Binary **lapse** (yes/no) per self-initiated craving-feature entry — "a single smoking episode after the designated quit date." Closest conceptual match to FR5 of the three, though binary, not High/Medium/Low. | Craving severity (**0-10 Likert — matches our `intensity` scale almost exactly**), 7 binary feeling flags (annoyance/anxiety/boredom/sadness/happiness/hunger/loneliness — richer than but overlapping our 5-value `mood` enum), binary activity flags (bar, chatting, coffee, alcohol, driving, eating, working, etc. — overlaps conceptually with our free-text `activity`), binary social-context flags (alone/colleagues/family/friends/partner/strangers — overlaps with our `socialPressure` trigger), temporal features (time of day, day of week, days since quit, minutes since prior entry, **prior-entry lapse status** — richer than our `last24hCount`). | **High.** This is the same problem shape: momentary craving-entry data used to predict a near-term lapse. This is almost certainly *why* the SRDS cites this paper specifically for FR5. | Analysis **code and R scripts are public on GitHub** (`OlgaPerski/lapses_smokefree_ml`). The **underlying raw participant dataset is proprietary to the Smoke Free app company** — the repository's visible structure (`/data`, `/scripts`, `/outputs` folders) does not establish that full raw participant records are included or redistributable; no README statement offers a public-data-request path. Obtaining the actual dataset would mean contacting the paper's authors and/or the Smoke Free company directly — a request/permission negotiation, not a click-through download, and not guaranteed to succeed. | Not stated for any data component in what's publicly visible; this alone is a reason not to treat it as usable without direct confirmation from the rights-holder. | **Best feature/target match by far**, but **data is not established to be legally/practically obtainable** for this FYP without direct outreach and permission — which is outside what "publicly available documentation" research can resolve. | **Do not attempt to obtain/use the raw data without direct, explicit permission from the authors/Smoke Free** — a real ask, not a download, and success isn't guaranteed. The published **methodology/feature schema is still valuable**: it validates that our `CravingLog` schema's shape (intensity + mood + trigger/social-context + activity) is a reasonable, literature-aligned feature set even without their data. |
| **Kaggle "Smoker Status" dataset** (bio-signals) | Binary **smoker vs. non-smoker** — a static health/demographic classification, not an event or a risk score. | Clinical/bio-signal labs: cholesterol (total/HDL/LDL), liver enzymes (AST/ALT/Gtp), blood pressure, blood sugar, urine protein, dental caries, hearing, eyesight, age/height/weight/waist circumference. | **None.** This predicts whether a person is currently a smoker from health-checkup data — an entirely different problem from "is this specific logged craving high-risk for relapse." Zero temporal/craving/mood/trigger dimension of any kind. | Fully public, instant download, no restrictions, no application. | Standard Kaggle dataset/competition terms (permissive for research use). | **None.** No feature or target overlap with `CravingLog`/`/predict/relapse` whatsoever. | **Confirmed unsuitable** — easiest to access, but solves a different problem entirely. Do not use, regardless of its convenience.

### Clear conclusion

**A. Best dataset if one is genuinely suitable:** **None of the three is both suitable and obtainable right now.** Perski et al. (2023) is the clear *best fit by feature/target design* — its schema (0-10 craving severity, mood flags, activity, social context, temporal recency) maps onto our `CravingLog` schema better than anything else found, and it targets the exact right event (craving → lapse). But its raw data is not established as publicly obtainable — it is gated behind the paper's authors/the Smoke Free company, and permission-seeking wasn't authorized as part of this research pass. PATH is grain-mismatched (annual survey vs. momentary event) even at its more-accessible public-use tier. Kaggle is a different problem entirely. **Honest answer: no dataset among the three sanctioned candidates is ready to train against today.**

**B. What additional data would be required if none is suitable:** Either (i) **direct permission from Perski et al./Smoke Free** to use their dataset or a derived/de-identified extract of it (a real outreach step, not a technical one — needs your decision on whether to pursue, since it involves contacting external parties on the project's behalf), or (ii) **the project's own collected `CravingLog` data**, once enough real users have logged enough cravings *with known outcomes* (i.e., enough logged events that were later confirmed as an actual relapse or not) to train on — which the app doesn't yet capture as a labeled outcome at all (a craving log currently has no "did this actually lead to a lapse" field), or (iii) a **new, not-yet-identified public dataset** that specifically captures momentary craving/mood/trigger context with a lapse outcome — the search for this pass was scoped to the three SRDS-named candidates only, per your instruction not to invent unlisted alternatives.

**C. Is the SDD's planned XGBoost/RandomForest approach realistically implementable with available data?** **Not right now, and not without one of B's paths resolving first.** The *algorithmic* choice (RandomForest/XGBoost) is entirely reasonable and well-precedented (it's literally what Perski et al. used successfully on a closely-matching problem) — the blocker is data, not modeling approach. Nothing here suggests XGBoost/RandomForest is the wrong tool; it suggests there is currently no legally-obtainable, feature-compatible dataset to fit one against.

**D. What the next safe step should be:** Nothing dataset-related requires code changes right now. Concretely, the safe next steps are all decisions/outreach, not implementation: (1) decide whether to attempt contacting Perski et al./Smoke Free about data access (a real, non-trivial ask — I'd need your explicit go-ahead to even draft that outreach, since it represents the project externally); (2) decide whether to start capturing a genuine outcome label in `CravingLog` (e.g., a later "did you end up using nicotine after this?" follow-up) so the app can eventually train on its *own* data — this would be a real Module 3 schema change, needing its own scoped decision, not something to fold in here silently; or (3) formally close the "primary model, deferred" line and keep the rule-based fallback as the permanent implementation (the option already recommended in §"Unresolved Decisions" #1(d) above) — which, given this research, now has direct evidence behind it rather than just a schedule-risk argument.

**Superseded (2026-08-17, same day):** the user has decided to pursue a real trained model rather than option D3 above. §12 below extends the dataset search beyond the three original candidates and identifies a genuinely viable option.

---

## 12. Extended Dataset Search (2026-08-17) — beyond the original three candidates

Per the user's direction not to settle for the rule-based fallback or a convenience dataset, the search was widened to smoking-lapse/EMA research more broadly. Two more candidates were evaluated in addition to the original three (§11).

| Dataset | Source | Target | Relevant Features | Relapse/Lapse Relevance | Accessibility | License | Suitability |
|---|---|---|---|---|---|---|---|
| **EMASENS_ML** (Perski et al. 2024, *PLOS Digital Health*) — **RECOMMENDED, see below** | Zenodo, DOI [10.5281/zenodo.10472386](https://doi.org/10.5281/zenodo.10472386); code mirrored on GitHub (`OlgaPerski/EMASENS_ML`) | Binary **lapse** (yes/no) — "reported having lapsed in the last hour, or pressed a button to indicate they had lapsed" | Craving (0-10 Likert), positive/negative affect (0-10 Likert: happy/enthusiastic, sad/stressed), confidence to stay quit, motivation to stay quit, bodily pain, social context, physical context, cigarette/alcohol/caffeine/nicotine availability-or-use, activity, **optional** Fitbit heart-rate/step-count sensor data | **High** — same authorship/research line as the SRDS-cited Perski et al. (2023) paper, purpose-built for exactly this prediction problem | **Open, no restriction.** Single 3.3MB ZIP, direct download, no application, no account beyond a normal Zenodo page visit. | **CC-BY-4.0** — reuse/redistribution permitted with attribution to Olga Perski. Clean for an FYP. | **Best of all five candidates evaluated** — see recommendation below. |
| Businelle "Project Prevail" EMA lapse-risk study | Multiple papers (e.g., *Nicotine & Tobacco Research* 2016; NIH R01-CA221819) | Binary lapse within a following window | Urge, stress, cigarette availability, alcohol use, motivation to quit, proximity to others smoking — a *very* tight, close-to-minimal feature set | **High** — purpose-built, and its "6-variable" model is close to what a lightweight production classifier could look like | **Not open.** Confirmed: "Prevail II data are not open source" — only simulated placeholder data and analysis code are shared (OSF), not real participant records. | N/A (raw data not released) | **Not usable** — same "proprietary, request-only" situation as the original 2023 Smoke Free dataset, confirmed by search, not assumed. |
| PATH Study *(carried forward from §11)* | ICPSR/NAHDAP | Annual survey-wave tobacco-use status | No momentary craving/mood/trigger fields | Low — wrong grain | Public-use tier accessible; restricted-use tier gated | ICPSR terms | Poor (unchanged from §11) |
| Perski et al. 2023 / Smoke Free *(carried forward from §11)* | GitHub (code only) | Binary lapse | Craving severity, mood flags, activity, social context | High conceptually | Raw data proprietary to Smoke Free, not released | Unspecified | Good features, data not obtainable (unchanged from §11) |
| Kaggle Smoker Status *(carried forward from §11)* | Kaggle | Smoker vs. non-smoker (static) | Bio-signals/lab values | None | Fully public | Kaggle standard | Confirmed unsuitable (unchanged from §11) |

### Recommended dataset: EMASENS_ML (Perski et al., 2024)

**Dataset name:** "Data and analytic code for Supervised Machine Learning to Predict Smoking Lapses from Ecological Momentary Assessments and Sensor Data: Implications for Just-in-Time Adaptive Intervention Development" (repository name `EMASENS_ML`).

**Source:** Zenodo, DOI `10.5281/zenodo.10472386`, v2.0.0, published 2024-06-25, by Olga Perski. Paper: *PLOS Digital Health* 2024, PMC11343380.

**License / access conditions:** CC-BY-4.0 (attribution required, otherwise unrestricted reuse/redistribution — no application, no account, no institutional agreement). Ethics-cleared and anonymized under UCL Research Ethics Committee approval (Project ID 15297.004); participants explicitly consented to open sharing of their anonymized data.

**Target variable:** Binary `lapse` (yes/no) per hourly EMA entry — "reported having lapsed in the last hour, or pressed a button to indicate they had lapsed." **Binary, not the SDD's High/Medium/Low categorical** — see Limitations.

**Features (EMA-only model, the one to target — see rationale below):**
- Craving: 0-10 Likert
- Positive affect (happy, enthusiastic) and negative affect (sad, stressed): 0-10 Likert each
- Confidence to stay quit, motivation to stay quit: Likert
- Bodily pain, social context, physical context: categorical
- Cigarette availability, alcohol/caffeine/nicotine use: categorical/binary
- Activity: categorical
- *(Available but proposed to exclude: Fitbit heart-rate/step-count sensor data — our app has no wearable-sensor integration, and the paper's own EMA-only Random Forest already scored AUC 0.899 vs. 0.952 with sensors — a meaningful but not disqualifying drop, and the honest choice given what our app can actually feed a deployed model.)*

**How its features map to `CravingLog`:**

| EMASENS_ML feature | `CravingLog` field | Mapping quality |
|---|---|---|
| Craving (0-10) | `intensity` (1-10) | Near-exact — trivial rescale |
| Positive/negative affect (0-10 x2) | `mood` (5-value enum: stressed/bored/sad/happy/social) | Partial — affect is two continuous dimensions, ours is one categorical pick; would need a documented, defensible mapping rule (e.g., derive a single dominant-mood category from the two affect scores), not a 1:1 rename |
| Social context, physical context | `triggerCategory` (stress/afterMeal/socialPressure/boredom/other) + `locationContext` (free text) | Partial — conceptually overlapping, vocabularies don't line up field-for-field |
| Activity | `activity` (free text) | Good — same concept, different encoding (categorical vs. free text) |
| Cigarette availability, alcohol/caffeine use | *(no equivalent field today)* | Gap — either dropped as a feature, or would need new `CravingLog` fields (a Module 3 scope question, not decided here) |
| Confidence/motivation to stay quit | *(no equivalent field today)* | Gap — same as above |
| *(n/a)* | `last24hCount` (our current rule table's 4th input) | Gap the other way — EMASENS_ML doesn't have a direct equivalent, though "minutes since prior entry" (mentioned in the paper, not confirmed present in the release) may substitute |

**Why it's suitable:** it is the only one of five candidates evaluated across two research passes that is simultaneously (a) purpose-built for the *exact* problem — predicting a near-term smoking lapse from momentary craving/mood/context data — and (b) genuinely, legally, immediately obtainable with no application, no request, no waiting. Its craving scale is nearly identical to ours already. It's from the same research group the SRDS itself cites for this exact FR, strengthening the academic-defensibility case your instructions asked for.

**Limitations (stated plainly, not glossed over):**
1. **Small sample:** 38 participants, 6,124 total EMA entries, 6.9% lapse rate. Workable for RandomForest/XGBoost at FYP scope, but generalizability is limited — the paper's own authors caveat this ("results limited to London-based individuals").
2. **Binary label, not High/Medium/Low.** FR5 wants three classes. A trained binary lapse-probability model would need an explicit, documented binning rule (e.g., probability thresholds → Low/Medium/High) to satisfy FR5's literal output contract — a design decision for the plan, not a blocker.
3. **Feature mismatch is partial, not total** (see mapping table above) — some of our fields (nothing captures "cigarette availability" or "confidence/motivation") and some of theirs (two-dimensional affect vs. our one categorical mood) don't map cleanly. Training against this dataset either means accepting a feature subset that's genuinely shared, or extending `CravingLog` to capture more — the latter is a Module 3 scope question, explicitly not decided here.
4. **Population mismatch:** UK adults in a formal 10-day quit-attempt research trial, not Pakistan-based university students/young adults using a consumer app long-term — an external-validity caveat worth stating in any FYP writeup, not hidden.
5. **Class imbalance** (6.9% positive) will need explicit handling (class weighting, stratified splits) — already anticipated in this plan's evaluation-metrics decision (§"Unresolved Decisions" #4: report per-class recall/F1, especially High-risk/lapse recall, not raw accuracy).

**Proposed preprocessing (not yet performed):**
1. Download and extract the Zenodo ZIP (pending your explicit approval — not done in this pass).
2. Inspect the actual file schema inside (format wasn't visible from the Zenodo landing page alone — likely CSV/RData per the paper's R-based analysis code).
3. Rescale/relabel fields per the mapping table above; document every mapping decision inline in the preprocessing script (no silent feature invention).
4. Define the binary→High/Medium/Low binning rule for FR5 compliance (a decision to bring back to you, not to invent silently).
5. **Person-level (grouped) train/test split** — critical for this dataset: splitting by *EMA entry* instead of by *participant* would leak the same person's data across train and test, inflating apparent performance. Standard practice for repeated-measures EMA data, and something the source paper itself had to account for.
6. Handle missing EMA responses (the paper notes missingness was common) — likely listwise deletion or a documented imputation rule, to be decided at implementation time with reasoning shown, not silently.

**Proposed model(s):** Random Forest and XGBoost, exactly as the SDD specifies and exactly what this paper itself trained (their EMA-only Random Forest scored AUC 0.899) — direct precedent that this approach works on this exact data shape.

---

| File | Responsibility | Phase |
|---|---|---|
| `docs/superpowers/plans/2026-08-17-backend-ai-ml-implementation-plan.md` | This document | A (done) |
| `backend/app/relapse/predictor.py` | `RelapsePredictor` ABC + `RuleBasedPredictor` (wraps existing `predict_relapse_risk`, behavior-unchanged, proven by regression tests) + `ModelPredictor` (raises `NotImplementedError`, no fake model) | **B (done)** |
| `backend/app/relapse/service.py` | Unchanged — `predict_relapse_risk`/`RiskLevel` kept exactly as-is; `RuleBasedPredictor` delegates to it | **B (done)** |
| `backend/app/config.py` | `relapse_predictor_mode: Literal["rule_based","model"] = "rule_based"` setting added | **B (done)** |
| `backend/app/dependencies.py` | `get_relapse_predictor()` singleton added, selects `RuleBasedPredictor`/`ModelPredictor` by settings | **B (done)** |
| `backend/app/firebase_identity.py` | `FirebaseIdentityProvider.verify_id_token()` added (ABC + Admin SDK impl, reuses the existing lazily-initialized Admin SDK app) | **B (done)** |
| `backend/app/fake_firebase_identity.py` | `FakeFirebaseIdentityProvider.verify_id_token()` added (in-memory `valid_tokens` map) | **B (done)** |
| `backend/app/firebase_auth_dependency.py` | New: `require_firebase_uid` FastAPI dependency (Bearer-token parsing + verification + 401s) | **B (done)** |
| `backend/app/routers/relapse.py` | `/predict/relapse` now requires `Depends(require_firebase_uid)` and calls the injected `RelapsePredictor` instead of the function directly | **B (done)** |
| `backend/tests/test_relapse_predictor.py` | New: proves `RuleBasedPredictor` identical to `predict_relapse_risk`; proves `ModelPredictor` fails loudly | **B (done)** |
| `backend/tests/test_relapse_router.py` | Updated: existing cases now supply a valid fake token; added missing/malformed/unverifiable-token 401 cases | **B (done)** |
| `mobile/lib/data/http_relapse_prediction_client.dart` | Attaches `Authorization: Bearer <Firebase ID token>` (default reads from the already-active `FirebaseAuth.instance.currentUser`); omits header if no token | **B (done)** |
| `mobile/test/data/http_relapse_prediction_client_test.dart` | Updated: all cases inject a fake token provider; added header-attached / header-omitted / 401-message cases | **B (done)** |
| `backend/ml/README.md` | Dataset provenance, reproduction steps, known limitations | **C (done)** |
| `backend/ml/requirements.txt` | pandas/numpy/scikit-learn/xgboost/joblib/pyreadr — training-only, not in `../requirements.txt` | **C (done)** |
| `backend/ml/pipeline/feature_mapping.py` | Phase 2: full documented EMASENS<->CravingLog mapping table + `FULL_EMA_FEATURES`/`CRAVINGLOG_COMPATIBLE_FEATURES` | **C (done)** |
| `backend/ml/pipeline/load_data.py` | Phase 1: reproducible raw-`.rds` loader, read-only | **C (done)** |
| `backend/ml/train.py` | Phases 3-6: grouped stratified split, RF+XGBoost training, evaluation, Phase 5 threshold derivation, model persistence | **C (done)** |
| `backend/ml/data/raw/` | Downloaded+extracted dataset (git-ignored, not committed) | **C (done, not committed)** |
| `backend/ml/models/*.joblib`, `feature_columns.json` | Trained model artifacts (git-ignored, not committed) | **C (done, not committed)** |
| `backend/ml/outputs/training_metadata.json` | Full metrics/thresholds/selection record (git-ignored, not committed) | **C (done, not committed)** |
| `.gitignore` | Added `backend/ml/data/`, `backend/ml/models/`, `backend/ml/outputs/`, `backend/data/EMASENS_ML/` entries | **C (done)** |
| `backend/data/EMASENS_ML/` | Canonical dataset location (superseded the earlier `backend/ml/data/raw/` copy), git-ignored | **C (done, not committed)** |
| `backend/ml/pipeline/load_data.py` | Repointed `RAW_DATASET_PATH` to the canonical `backend/data/EMASENS_ML/` location | **C (done)** |
| `mobile/lib/models/craving_log.dart` | Ten nullable mood-slider fields added (Open Decision 6 Option A) | **C-extended (done)** |
| `mobile/lib/data/firestore_craving_log_repository.dart` | Read/write the ten new fields, null-safe for pre-existing records | **C-extended (done)** |
| `mobile/lib/controllers/craving_log_controller.dart` | `submitCraving()` gained ten optional mood params, default 5.0 | **C-extended (done)** |
| `mobile/lib/screens/craving/log_craving_screen.dart` | New "Rate your mood" slider section, existing form otherwise unchanged | **C-extended (done)** |
| `backend/tests/test_ml_feature_mapping.py`, `test_ml_model_loading.py` | New: mapping-table consistency + model-load/predict smoke tests | **C-extended (done)** |
| **Phase 7 (API integration)** | **Declined — user decision 2026-08-17.** `ModelPredictor` stays an unimplemented stub; `/predict/relapse` keeps `RuleBasedPredictor` as its only active implementation. | **Not started, not planned** |

## 13. Phases 1-6 Results (2026-08-17) — training complete, NOT yet integrated (Phase 7 gated)

**Pipeline design:**
- **Phase 3 (leakage prevention):** `StratifiedGroupKFold` (5-fold, seed 555, first fold used) — every participant's rows are entirely in train OR test; verified with a hard assertion (`train_ids.isdisjoint(test_ids)`), not just documented intent. Chosen over a plain grouped split specifically because 13/38 participants have zero lapses (Phase 1 finding) — a naive split risks an unlucky all-negative test fold; the stratified variant balances the (rare) positive class across the split while still respecting participant grouping.
- **Class imbalance (train set: 7.2% positive):** handled via `class_weight="balanced"` (RandomForest) / `scale_pos_weight` (XGBoost) — i.e. cost-sensitive learning, not resampling, and applied only within the training fold, so it cannot leak into the held-out test set.
- **Two feature sets trained and compared** (`pipeline/feature_mapping.py`): `full_ema` (52 columns, mirrors the source paper's own feature set) vs. `cravinglog_compatible` (5 columns — only what `CravingLog` can actually supply today).

**A bug found and fixed during this run, not hidden:** the first Phase 5 threshold-derivation attempt ("smallest probability threshold achieving >=85% recall") degenerated to `{low: 0.0, high: 0.0}` — trivially satisfied by flagging everyone positive. Replaced with the standard, textbook Youden's J statistic (argmax of TPR-FPR on the ROC curve) for `high_threshold`, which cannot degenerate this way. Model selection was also corrected to rank by ROC-AUC (threshold-independent) rather than recall-at-sklearn's-arbitrary-0.5-default, since Phase 5 always substitutes its own derived threshold anyway.

**Results (held-out test fold: 1,283 rows / 8 participants, 5.07% actual lapse rate):**

| Feature set | Model | ROC-AUC | Recall @ derived High threshold | Precision @ derived High threshold | Derived thresholds (low / high) |
|---|---|---|---|---|---|
| **full_ema** | **Random Forest (selected)** | **0.852** | **0.800** (52/65 lapses caught) | 0.173 | 0.170 / 0.190 |
| full_ema | XGBoost | 0.810 | 0.754 | 0.158 | 0.040 / 0.058 |
| cravinglog_compatible | XGBoost | 0.569 | 0.969 | 0.068 | 0.004 / 0.007 |
| cravinglog_compatible | Random Forest | 0.526 | 0.954 | 0.057 | 0.002 / 0.003 |

**Selected model: `full_ema` / Random Forest** — highest ROC-AUC, 80% lapse recall at its own derived threshold. This is comparable to, though somewhat below, the source paper's own reported RF result (AUC 0.899) — an expected gap, since this run used a single stratified-group split with cost-sensitive weighting rather than the paper's full 10-fold cross-validated hyperparameter search with training-set downsampling.

**The `cravinglog_compatible` models' apparently-high recall (0.95-0.97) is not a good result — flagged explicitly, not presented misleadingly.** With ROC-AUC barely above chance (0.53), their Youden's-J thresholds collapsed to near-zero probability cutoffs, which flags almost every test row as "High" — high recall achieved only by being almost meaningless as a filter (precision ~6%). This reflects genuinely weak signal in the 5 fields our app collects today, not a bug in this run.

**The central open finding for Phase 7:** the model worth deploying (`full_ema`/RF, AUC 0.852) requires fields `CravingLog` does not collect (10-dimension affect instead of 1 categorical mood pick, cigarette availability, structured location/activity, demographics). The model trainable on what the app *actually* sends today is not usable (chance-level). **This is not resolved by this plan** — see the options below, per **Open Decision 6**.

**Artifacts saved** (git-ignored, not committed — see `backend/ml/README.md`): all four trained models (`.joblib`), the full evaluation metadata (`ml/outputs/training_metadata.json`), and the exact encoded feature-column list per feature set (`ml/models/feature_columns.json`).

### Open Decision 6 — RESOLVED (2026-08-17, same day): Option A executed, then Option B chosen

**Option A was executed first** (user approved): `CravingLog` was extended with ten 0-10 mood sliders (one per EMASENS_ML affect dimension), and the model was retrained on the resulting 11-feature CravingLog-compatible set. **Result: performance did not improve — it got slightly worse** (AUC 0.503-0.478 vs. the original 5-feature set's 0.526-0.569). See §14 for the full before/after comparison.

**Final decision (Option B): keep the rule-based predictor as production; do not deploy any trained model.** With the richer feature set still at/below chance, extending `CravingLog` further would not plausibly close the gap to `full_ema`'s 0.852 AUC — the missing pieces are qualitatively different data (demographics, substance-availability, structured context, prior-lapse history), not more mood granularity. See §14 for the complete resolution record.

<details>
<summary>Original (superseded) framing of the three options, kept for history</summary>

### Open Decision 6 (new, blocks Phase 7): how to close the deployability gap?

**Option A — Extend `CravingLog` to collect more of `full_ema`'s features.** Concretely: replace the single categorical `mood` with several 0-10 sliders (at minimum the four EMASENS dimensions with a direct mapping: happy/stressed/sad/bored), and/or add a `cigarette_availability` field. This is a **Module 3 UI/schema change** — explicitly flagged since your constraints say not to touch Modules 1-5 without your approval; **not done in this pass**.

**Option B — Accept the `cravinglog_compatible` model's weak performance, or don't deploy a trained model at all**, and keep the rule-based fallback as the production implementation (Phase 7 would then not proceed) — the honest reading of this data is that 5 sparse per-event fields don't carry enough signal for this dataset's lapse-prediction task, independent of which algorithm is used.

**Option C — A hybrid:** deploy `full_ema`'s model behind the API, but only when the request happens to supply the richer fields (future-proofing), and fall back to the rule-based predictor when it doesn't (i.e. today, always) — the `RelapsePredictor`/`ModelPredictor` seam built in Phase B already supports this shape without further backend rework, but the Flutter/UI side to actually collect richer input is Option A's work, not separate.

**I'm not picking one of these** — it's a real product/scope decision (whether to touch Module 3's UI at all), not an ML question I can resolve alone.

</details>

## 14. Final Resolution (2026-08-17): CravingLog Extended, Deployment Still Not Justified

**What was executed (Option A):** `CravingLog` (`mobile/lib/models/craving_log.dart`) gained ten new nullable `double?` fields — `moodHappy, moodExcited, moodEnthusiastic, moodContented, moodCalm, moodIrritable, moodAnxious, moodStressed, moodSad, moodBored` — one per EMASENS_ML affect dimension, added alongside (not replacing) the existing categorical `mood` enum. Firestore repository, controller, and UI (`log_craving_screen.dart`, a new "Rate your mood" section of ten sliders under the existing mood-chip picker) were extended to match; all fields nullable/defaulted so pre-existing Firestore records never crash. `backend/ml/pipeline/feature_mapping.py`'s ten mood-dimension rows were upgraded from `partial`/`unavailable` to `direct`, and `CRAVINGLOG_COMPATIBLE_FEATURES` grew from 5 to 11 columns.

**Retrained on the expanded feature set** (same leakage-safe, participant-grouped, stratified split; seed 555):

| Feature set / model | ROC-AUC | Lapse recall @ derived threshold | Precision @ that threshold |
|---|---|---|---|
| full_ema / Random Forest *(unchanged — not affected by this change)* | 0.852 | 0.800 | 0.173 |
| full_ema / XGBoost *(unchanged)* | 0.810 | 0.754 | 0.158 |
| cravinglog_compatible **v1** (5 features: craving+happy+stressed+sad+bored) / RF | 0.526 | 0.954 | 0.057 |
| cravinglog_compatible **v1** (5 features) / XGBoost | 0.569 | 0.969 | 0.068 |
| cravinglog_compatible **v2** (11 features — all ten EMASENS mood dims + craving) / RF | **0.503** | 0.938 | 0.055 |
| cravinglog_compatible **v2** (11 features) / XGBoost | **0.478** | 0.831 | 0.061 |

**Honest finding:** expanding from 5 to 11 mood features made the CravingLog-only model *worse*, not better — RandomForest's AUC dropped 0.526→0.503, XGBoost's dropped 0.569→0.478 (now below the 0.5 chance line). The apparently-high recall figures are an artifact of near-chance models collapsing their Youden's-J threshold to near-zero, flagging almost every row "High" (precision stayed ~5-6%) — not a sign the extended model is actually useful. Most plausible explanation: with only 30 training participants and a 7.2% positive rate, six more numeric columns added capacity to overfit noise rather than new separable signal — the features genuinely missing (motivation, confidence, substance availability, structured location/activity/social-context, prior-lapse history, demographics) are qualitatively different information, not more granularity on mood.

**Decision: do not deploy any trained model.** The rule-based predictor (`RuleBasedPredictor`, wrapping `predict_relapse_risk`, SRDS §5.5.1) remains the sole production implementation behind `/predict/relapse`. `ModelPredictor` stays an unimplemented stub (raises `NotImplementedError`, no fake/placeholder model ever loaded). The `full_ema`/`cravinglog_compatible` `.joblib` artifacts, `training_metadata.json`, and the EMASENS_ML dataset itself are all retained on disk (git-ignored, never committed) purely for research/reproducibility and FYP writeup purposes — not referenced by any production code path.

**Documentation conflict — flagged, not resolved here:**
- `docs/srds.txt` (lines ~390-392, ~1071-1073) uses normative "shall" language: *"the system shall send craving data to the AI backend. The AI model... shall return a relapse risk score."* Taken literally, this requires a trained AI model in production. **This was already superseded before this session** by the SDD's FR5/§2 correction (2026-08-10/11 review, recorded in SDD §9 Traceability) which established the rule-based table as "the active fallback... until the primary is available" — so this isn't a new conflict this decision creates.
- However, `docs/Quit_Companion_SDD.md` §2 (line 67) and §3 FR5 (line 115) still describe the trained model as **"primary... deferred pending dataset validation"** / **"deferred pending dataset validation; the SRDS §5.5.1 rule-based decision table is the active fallback and must be used until the primary is available."** That wording reads as *provisional* — implying deployment is still an open future path once a dataset is validated. As of today, a dataset *was* validated (EMASENS_ML) and a model *was* trained and evaluated, and the conclusion is that deployment is **not justified with currently-collectible app data** — a materially different, more final status than "pending validation." **I have not edited the SDD or SRDS** — flagging this gap between documented intent and the actual evaluated outcome for you to decide whether/how to update those documents.

**Testing (final verification):**
- Backend `pytest`: **80/80 passing** (69 pre-existing + 11 new: 7 feature-mapping consistency tests, 4 model-load/predict smoke tests).
- Flutter `flutter test`: **210/210 passing** (203 pre-existing + 7 new: 3 widget tests for the mood sliders, 2 controller tests for mood-value passthrough, 2 repository round-trip tests).
- `flutter analyze`: **0 issues.**
- No change to `/predict/relapse`'s contract, `RelapsePredictor` abstraction, `RuleBasedPredictor`, Firebase-auth gate, or any Module 1-5 code.

## Testing Strategy

- **Phase B (executed):** `test_relapse_predictor.py` proves `RuleBasedPredictor` is behavior-identical to `predict_relapse_risk` across all 11 existing rule cases (two ways: direct assertion, and a same-call comparison). `test_relapse_router.py`'s five original cases now supply a valid fake token (required since the endpoint is no longer anonymous) and still assert the *same* response bodies as before; three new cases cover missing header / malformed header / unverifiable token, all expecting 401. Flutter: `http_relapse_prediction_client_test.dart` covers token-attached, token-omitted, and the 401-message-surfaced-verbatim cases.
- **Phase C (blocked):** table-driven tests over a trained model's predictions on a fixed, versioned held-out sample, asserting the §11-informed metrics (per-class recall/F1, High-risk recall reported) — cannot be written against a model/dataset that doesn't exist yet.
- **Regression guard — verified, not just planned:** `pytest -v` under `backend/`: **69/69 passing** (43 pre-existing, unmodified in behavior + 26 new). `flutter test` under `mobile/`: **203/203 passing** (201 pre-existing + 2 new). `flutter analyze`: **0 issues.**

## Security Considerations

- `/predict/relapse` **now requires** a valid Firebase ID token (Decision 3, implemented) — no longer callable anonymously.
- No secrets are hardcoded anywhere in `backend/` — confirmed (`.env`/`.env.example` pattern is followed correctly, `.env` is real but git-ignored, no service-account JSON committed).
- A future model file (Phase C) must never be committed to git if it embeds any dataset-derived information beyond model weights (e.g., no raw training data snapshots bundled into the artifact).
- Per §11: if Perski et al./Smoke Free data is ever pursued, any data-sharing agreement they impose becomes a binding constraint on Phase C's design, not optional; same for PATH's restricted-use tier if that path is ever chosen despite §11's recommendation against it.

## Acceptance Criteria

**Phase A (audit):** done — this document accurately reflects the repo's actual state, verified against live files.

**Phase B — done, verified:**
1. ✅ `RelapsePredictor` abstraction exists; `RuleBasedPredictor`'s output is provably identical to `predict_relapse_risk` for every existing test case.
2. ✅ `backend/tests`: all previously-passing tests still pass (69/69), plus new predictor-equivalence and auth-gate tests.
3. ✅ `/predict/relapse` rejects requests without a valid Firebase ID token (401); `HttpRelapsePredictionClient` attaches one automatically from the existing session; `flutter test` (203/203) and `pytest` (69/69) both fully pass.
4. ✅ No dataset file, no model file, no new ML dependency added to `requirements.txt`.

**Phase A continued — dataset research (§11):** done — comparison table delivered, no downloads, no accounts, no dataset adopted, conclusion states plainly that none of the three candidates is both suitable and obtainable today.

**Phase C — done, concluded (2026-08-17):** dataset obtained (EMASENS_ML), pipeline built, two rounds of training/evaluation completed (original 5-feature and extended 11-feature CravingLog-compatible sets, plus the full_ema reference model), results honestly reported including the unflattering finding that extending features made the CravingLog-compatible model *worse*. Artifacts retained for research/reproducibility only.

**Phase 7 (production integration): declined by explicit user decision, not blocked.** The rule-based predictor remains production. This is a final status, not a "pending further work" state — no further ML training is planned unless the user explicitly requests it (e.g., a new dataset, or a `CravingLog` outcome-label field enabling training on the app's own data).

## Out of Scope

- Actually downloading/acquiring any dataset (Open Decision 1/2 must resolve first, and even then this needs a separate explicit go-ahead per your "no downloads without approval" instruction).
- Training, evaluating, or serializing any model (Phase C, blocked).
- Habit-Replacement recommendation service, Dialogflow/Health-Bot NLP (Mehreen's modules — confirmed by the prior ownership audit).
- Any Flutter UI change, except `HttpRelapsePredictionClient`'s auth-header addition **if and only if** Open Decision 3 is accepted.
- Any change to Modules 1-5, onboarding, authentication, Google Sign-In.
- Any change to the SDD document itself.
- CI/CD pipeline setup (not requested; flagged as a missing-piece observation only in §2).
- Modifying `app/otp/`, `app/whatsapp/`, `app/phone.py`, `routers/phone_auth.py`, or `firebase_identity.py` in any way.

---

## Self-review

- **Spec coverage:** every SDD §2/§3(FR5)/§9-10 clause about the AI backend is traced to either "already implemented" (rule fallback) or an explicit open decision (dataset, model, metrics) — nothing about the AI/ML architecture is left unaddressed or silently assumed.
- **Placeholder scan:** all five open decisions have concrete recommendations with stated reasoning, not "TBD." Phase C's file list is explicitly marked "proposed shape, not created" rather than presented as already-planned tasks.
- **Boundary check:** Habit-Replacement/Dialogflow correctly traced to Mehreen's modules and excluded, consistent with the earlier Module 6 ownership audit — not re-litigated, just cross-referenced.
- **Reuse check:** Phase B reuses the existing rule-based function unchanged (wrapped, not rewritten), the existing FastAPI router/settings/testing patterns, and the existing Firebase Admin SDK usage (for Open Decision 3) — zero duplicated logic.

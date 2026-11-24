# Step 9 — FR5 ML model deployment configuration: implementation record (2026-11-23)

## Existing pipeline (unchanged)

- **Model:** `app/relapse/model_artifacts/app_candidate.joblib`, a scikit-learn `Pipeline` with the training-set median imputer and XGBoost, version `emasens-xgboost-v1`. It was trained on EMASENS_ML v2.0.0 (UK adult cigarette quit attempts). Its metadata file holds the sha256, the 15 feature columns, thresholds (low 0.0217, high 0.0433), and development/held-out metrics. `clinically_validated: false`.
- **Features versus app data:**
  - `craving_imp` comes from the 1–10 intensity, rescaled to 0–10.
  - The 10 mood sliders the Log Craving form always sends: happy, excited, enthusiastic, contented, calm, irritable, anxious, stressed, sad, bored.
  - The 4 optional recovery check-in ratings (motivation, confidence, pain, cigarette availability 1–3).
  - Omitted values go through the fitted imputer and are listed in `imputed_features`; they are never saved as user answers.
- **Wiring:** `RELAPSE_PREDICTOR_MODE` defaults to **`ml`**, which existing tests assert. `rule_based` (the SRDS §5.5.1 table) and the legacy research `model` remain available.
  - *Note:* `docs/ANDROID_COMPLETION.md` still says the production default is rule-based. That is out of date; the code default is `ml`.
- **Endpoint:** `POST /predict/relapse` (Firebase-auth). Pydantic validates ranges and allowed keys. The response carries `risk_level`, `assessment_source`, `clinically_validated=false`, `model_version` and `imputed_features`.
- **Load-time checks:** checksum verified before unpickling; thresholds validated.
- **Deployment:** the Dockerfile uses python:3.12-slim (matching local 3.12.10) and `COPY app ./app`, which includes the packaged artifact. `requirements.txt` pins `scikit-learn==1.9.0`, `xgboost==2.1.4`, `joblib==1.5.3` and `numpy==2.5.2`, matching the installed training environment.
- **Git:** `backend/ml/models/` (training outputs) is gitignored. `app/relapse/model_artifacts/` is the deliberately tracked deployment copy.

## Gaps fixed (no retraining, no algorithm/feature/threshold change)

1. **A missing or corrupt artifact crashed the whole API at import**, because the predictor is a module-level singleton, so auth, OTP and Health-Bot went down too.
   - Now: the error is logged, the server serves the rule-based predictor, and `/ready` reports `{"requested_mode":"ml","active":"rule_based","fallback_reason":"FileNotFoundError"}`.
   - `RELAPSE_MODEL_REQUIRED=true` restores fail-fast startup for deployments that must never run without ML.
2. **No configurable artifact path.** `RELAPSE_MODEL_PATH` loads a mounted copy, with the metadata beside it. The default is `PACKAGED_CANDIDATE_PATH`, resolved from the module file, so it doesn't depend on the working directory.
3. **Model faults were reported as client errors or 500s.**
   - Estimator exceptions and out-of-range probabilities now raise `PredictionModelError`, which is not a `ValueError`.
   - The endpoint then answers with the SRDS rule table for that request, labelled `assessment_source: "rule_based_fallback"`, with the same response shape.
   - Invalid input is still 400/422.
4. **The bundle wasn't checked against its metadata.** Loading now requires the estimator, columns and thresholds to be present, `predict_proba` to exist, and the columns to equal the metadata's documented feature order.
5. **The worker mislabelled re-scored logs.** It stored `assessmentSource = <configured mode>` even when the rule-based predictor was serving. It now records what actually scored the log.

## Files

- Modified:
  - `backend/app/config.py` (`relapse_model_path`, `relapse_model_required`)
  - `backend/app/relapse/predictor.py` (`PACKAGED_CANDIDATE_PATH`, `PredictionModelError`, load-time bundle checks)
  - `backend/app/dependencies.py` (fallback and `relapse_predictor_status`)
  - `backend/app/relapse/router.py` (model-fault fallback)
  - `backend/app/main.py` (`/ready` adds `relapse_predictor`; no paths or secrets)
  - `backend/app/worker.py` (`assessment_source()`)
- New: `backend/tests/test_ml_deployment.py` (22 tests).

## Verification

- Backend full suite: **286 passed, 5 skipped** (264 before; +22). The skips are unrelated to this step: 4 research-model loading tests need `pandas` (training-only), plus 1 pre-existing.
- No Flutter files changed.
- Not performed:
  - a Docker image build (the Docker engine wasn't verified running);
  - a live deployed `/predict/relapse` call with a real Firebase token.
- No accuracy claims: the metrics in the metadata are the existing internal EMASENS results. The model remains experimental and not clinically validated.

## Manual deployment checks

1. `docker compose --env-file deploy/.env -f deploy/compose.yaml up -d --build`, then `curl https://<domain>/ready`. Expect `relapse_predictor.active == "machine_learning"` and `model_version == "emasens-xgboost-v1"`. If it says `rule_based` with a `fallback_reason`, the artifact didn't load: check that the image contains `app/relapse/model_artifacts/`.
2. To guarantee ML in production, set `RELAPSE_MODEL_REQUIRED=true`; the container then fails to start if the model is unusable.
3. From the app (or with a test account's ID token), log a craving. The backend log should show no fallback error. The response `assessment_source` should be `machine_learning`.
4. With the worker running, an offline (pending) craving should get `assessmentSource: machine_learning` once re-scored.

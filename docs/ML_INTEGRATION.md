# ML relapse scoring

The active mode is `RELAPSE_PREDICTOR_MODE=ml`. The `candidate` spelling remains
an alias; `rule_based` explicitly selects the deterministic decision table.
Legacy `model` selects the older near-chance Random Forest and is not recommended.

## Inference

POST `/predict/relapse` requires a Firebase ID token. It runs the packaged
XGBoost pipeline, maps the predicted probability through the saved thresholds,
and returns `low`, `medium` or `high`. This is actual model inference, not a rule
score relabeled as ML. The worker uses the same predictor for pending logs.
The response includes `assessment_source=machine_learning`, `model_version`,
`imputed_features`, and `clinically_validated=false`.

Inputs are craving intensity (1?10, linearly rescaled to 0?10), ten mood ratings
(0?10), and optional motivation, confidence, discomfort (0?10) and cigarette
availability (1?3). The existing Flutter check-in sends these fields. Mood
sliders start at 5 and the form tells users unchanged values are submitted as 5.
Unanswered fields go through the fitted training-set median imputer. They are
not recorded as answered and the API lists which features were imputed. This
keeps old/offline logs scoreable without requiring newly added answers.
No synthetic training data or invented questionnaire responses were added.

## Artifact and dependencies

`backend/app/relapse/model_artifacts/app_candidate.joblib` and its adjacent
metadata are delivered together. Startup verifies the SHA-256 checksum and fails
if the artifact is missing or changed. Only load trusted project artifacts:
joblib contains Python-serialized objects. Install `backend/requirements.txt`,
including the pinned XGBoost 2.1.4 and scikit-learn 1.9.0 versions.

Run from `backend/`:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe tools/local_services.py --worker --notifications --usb
```

## Evaluation and limits

The candidate was selected using development participant-grouped cross-validation
average precision. Thresholds were selected using development out-of-fold
predictions, before scoring the held-out participants. The outcome is a lapse at
the next observed EMA within the same participant, not a guaranteed future relapse.
Dataset: EMASENS_ML v2.0.0, Olga Perski et al., DOI 10.5281/zenodo.10472386.
Held-out ROC-AUC: 0.8406; average precision: 0.2309; positive prevalence: 0.0510.
At the high-risk cutoff, precision was 0.1599 and recall was 0.7231.
These are study results, not measured app accuracy. They do not establish the
same performance for sparse check-ins or default midpoint mood answers.
The study involved UK adult cigarette quit attempts. Vaping, pouches, hookah,
the app population and prospective clinical usefulness remain unvalidated.
`docs/ML_CANDIDATE_EVALUATION.json` contains the full existing evaluation.
No clinical approval is claimed; this is an experimental support estimate.

## Reproduce

From `backend/`, install `ml/requirements.txt`, run `python -m ml.fetch_data`, then
`python -m ml.evaluate_candidate`. This recreates the candidate and evaluation
under ignored `ml/models` and `ml/outputs`. To release a retrained model, evaluate
it first, then replace the packaged artifact and regenerate its metadata/checksum
with a new model version. Merely retraining does not replace the delivered model.

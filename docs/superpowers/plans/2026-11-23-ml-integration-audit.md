# ML relapse-prediction integration audit (2026-11-23)

Audit only. **No code, configuration, model, Firebase or deployment changes were made.** Evidence came from the artifact, the training script, the local copy of the dataset, the Flutter code, and tests run through the real FastAPI endpoint (`/predict/relapse`) with the real model. Only Firebase auth was faked, and payloads matched exactly what `HttpRelapsePredictionClient` sends.

## A. Training data

- **Dataset: EMASENS_ML v2.0.0** (UK adult cigarette quit-attempt ecological momentary assessment study). Recorded in `app/relapse/model_artifacts/app_candidate_metadata.json`; produced by `backend/ml/evaluate_candidate.py`. **Not PATH**: the PATH download returned HTTP 403, and no PATH data was used.
- Analytic sample (loaded locally from `backend/ml/data`): **6,124 check-ins from 38 participants**.
- Outcome: lapse reported at the **next** check-in of the same participant (last check-ins excluded). Prevalence about 5–7%.
- Artifact: `app_candidate.joblib` = scikit-learn `Pipeline(SimpleImputer(median) → XGBClassifier)`, 15 features, `production_approved: False`, `clinically_validated: false`, version `emasens-xgboost-v1`, sha256-verified on load. Thresholds: low 0.0217, high 0.0433.
- Internal held-out metrics (study data, not app data): ROC-AUC 0.841, average precision 0.231, precision 0.16, recall 0.72.

## Features: model vs app

| Model feature (0–10 unless noted) | Training median | App source | Collected? |
| --- | --- | --- | --- |
| `craving_imp` | 6 | Intensity slider 1–10 → `(i−1)·10/9` | Always |
| 10 mood items (`happy` … `bored`) | 3–5 | Mood sliders on Log Craving | Always sent — **default 5, sent even if the user never moves them** |
| `motivation_imp`, `confidence_imp`, `pain_imp` | 7, 7, 0 | "Recovery check-in (optional)" sliders | Only if the user opens the collapsed section |
| `cigarette_availability_imp` (1–3) | 3 | Same section, dropdown 1/2/3 | Only if answered |

- **Scales match the training data** (verified on the dataset: every item 0–10, availability 1–3).
- Not used by the model (only the rule-based table uses them): categorical mood, trigger category, last-24 h count, location, activity, notes.
- Stored in Firestore: `cravingLogs` stores intensity, sliders, `recoveryContext` and `riskAssessmentPending` (codec verified), so the worker can re-score offline logs with the same inputs.

## B. Is the trained model actually used?

**Yes, when `RELAPSE_PREDICTOR_MODE=ml`.**
- Local `backend/.env` has `ml`; the live predictor is `CandidatePredictor` (`/ready`: `active=machine_learning`, `model_version=emasens-xgboost-v1`).
- All 500 audit requests returned `assessment_source="machine_learning"`.
- Fallback to rule-based happens only if the artifact fails to load, or on a model fault for a single request. Both are logged and labelled (`rule_based_fallback`).
- **The app ignores `assessment_source`**, so a user or demo audience can't see which scorer produced a result.
- Offline, the app doesn't score locally: logs are saved as "assessment pending" and re-scored by the worker.

## C. Valid predictions from real app data?

**Technically valid; practically not informative with typical app input.**

| Input as the app sends it | Result |
| --- | --- |
| Sliders untouched (5), no recovery check-in; intensity 1–10 × 5 moods × 5 triggers × 2 counts (500 requests) | **500/500 "medium"**. Probability only 0.0247 (intensity 1–4) or 0.0288 (5–10) |
| Random slider values, no recovery check-in (3,000) | 87% medium, 10% high, 3% low (p 0.020–0.077) |
| Random sliders **with** recovery check-in (3,000) | 59% high, 21% medium, 20% low (p 0.004–0.627) |
| "Stressed, intensity 9" vs "calm, intensity 2" (no check-in) | Both medium; the stressed case scored *lower* (0.0229 vs 0.0326) |
| Check-in "motivated, no cigarettes available" / "low motivation, cigarettes easy" | low / high |

- **Model feature importance (XGBoost gain):** motivation 27%, confidence 22%, happy 11%, cigarette availability 8%, anxious 7%, pain 6%, bored 5%, **craving intensity 3%**, others ≤3%.
- **63% of the model's signal comes from the four optional check-in items**, which the app usually leaves blank (they're then filled from training medians).
- **ML vs rule-based agreement** on app-default inputs: **15/500**.

## D. What is missing (and whether the app can collect it)

1. **Recovery check-in is optional and collapsed.** These four items drive the model. *Collectable with the existing UI*: it already exists; it would need to be prompted or expanded each time, or requested in a regular check-in.
2. **Untouched mood sliders are sent as "5".** This is a neutral value the user never gave, so the model's missing-value imputer is bypassed. *Fixable in the app*: send only sliders the user actually moved (the backend and model already accept missing values).
3. **The app doesn't show which scorer answered** (`assessment_source`, `model_version`, `imputed_features` are returned but discarded). *Fixable in the app.*
4. Categorical mood, trigger, recent-craving count, location and activity are **not model inputs**. They would need retraining; out of scope.
5. **Population/outcome limits:** UK adult cigarette smokers in one study (38 people); predicts next-check-in lapse; not validated for vaping/pouches/hookah or this app's users; not clinically validated.

## E. Recommendation for the FYP demonstration

- **Use `rule_based` for live scoring in the demo** until items D1–D3 are addressed. ML mode runs end-to-end without errors, but with the inputs users normally give it returns "medium" for almost everything and barely responds to craving intensity. Presenting that as working relapse prediction would be misleading.
- ML can be **shown honestly as an experimental component**:
  - it's integrated and verified (artifact, checksum, endpoint, worker);
  - it gives differentiated results when the recovery check-in is answered;
  - its internal held-out metrics are on study data (AUC 0.84), not on app users;
  - `production_approved: False`.
- **Not decided here:** `RELAPSE_PREDICTOR_MODE` and `REQUIRE_CLINICAL_REVIEW` remain owner decisions; nothing was changed.

## Possible next steps (await owner approval; none performed)

1. App: send only user-moved sliders; prompt the recovery check-in; show the scoring source on the result screen. Add tests.
2. Then re-run this audit to measure how output distribution and sensitivity change.
3. Keep the rule-based predictor as the fallback in every case (unchanged).

---

## Post-fix re-audit (2026-11-23, after the three ML integration fixes)

The original findings above are unchanged and kept for comparison. Fixes implemented (record: `2026-11-23-ml-integration-fixes-record.md`):

1. **Untouched mood sliders are no longer sent as "5".** Only sliders the user moved are saved and sent; the rest are missing, so the backend's fitted median imputer handles them.
2. **The recovery check-in is offered on every craving log** (an open card explaining why it helps the experimental ML estimate). It can be skipped; skipped or unanswered items are sent as missing.
3. **The result shows the backend-reported source:** "Scored by: ML (Experimental)", "Rule-based", or "Rule-based (ML unavailable)" for a fallback. Nothing is shown when the source is unknown or the assessment is pending.

Same method as the original audit: the real `/predict/relapse` endpoint and the real model, with only auth faked. Payloads are now in the **new** app shape. The model wasn't retrained or changed.

| Scenario | Before the fixes | After the fixes |
| --- | --- | --- |
| Nothing rated, check-in skipped (intensity 1–10 × 5 moods × 5 triggers × 2 counts) | 500/500 medium (sliders sent as 5; 4 inputs imputed) | **500/500 medium** (14 inputs genuinely imputed; probability 0.0256 for intensity 1–4, 0.0298 for 5–10) |
| Some moods rated, check-in skipped | 87% medium / 10% high / 3% low (all 10 sliders random) | **96% medium / 4% high / <1% low** (2–6 sliders rated) |
| Moods rated + check-in answered | 21% medium / 59% high / 20% low | **20% medium / 56% high / 24% low** |
| "Calm, craving 2, motivated, no cigarettes" vs "stressed, craving 9, low motivation, cigarettes easy" | low / high | **low (p=0.0067) / high (p=0.3395)** |
| Same two cases, check-in skipped | — | **medium / medium** (p=0.0326 / 0.0288) |
| ML vs rule-based agreement (nothing rated, check-in skipped) | 15/500 | 15/500 |
| Source reported | `machine_learning` on all ML responses (ignored by the app) | `machine_learning` on all 4,500+ responses, **now shown in the app**; the fallback is labelled `rule_based_fallback` (tested) |

### What changed and what didn't

- **Data honesty: fixed.** Unanswered items are no longer fabricated; the model receives either the user's answer or its own training median (verified: the missing-input probability equals the explicit-median probability and differs from the all-5 probability).
- **Transparency: fixed.** Users and examiners can see which method produced each result.
- **Meaningful predictions depend on the check-in.** With it answered, the model differentiates clearly (low vs high, probabilities 0.007–0.34). With it skipped, the model still returns "medium" for almost everything. That's a property of the trained model, which relies on motivation, confidence, cigarette availability and physical discomfort for about 63% of its signal and on craving intensity for only about 3%. The fix makes answering easy and visible; it can't make the model use inputs it was trained to weight lightly. How often real users answer the check-in hasn't been measured (no field data).

### Updated recommendation (E)

- **Demo with live scoring:** `rule_based` remains the safer default. Its result now shows "Scored by: Rule-based".
- **Demo of the ML path:** with ML mode on, answer the recovery check-in and the result shows "Scored by: ML (Experimental)" with a differentiated level. Skipping the check-in shows ML returning "medium". Present this as experimental. It was trained on EMASENS_ML v2.0.0 (6,124 check-ins from 38 UK adult cigarette smokers). The study's held-out ROC-AUC of 0.84 isn't real-world accuracy for Quit Companion users. It isn't clinically validated, isn't production-approved, and isn't validated for vaping, pouches or hookah.
- `RELAPSE_PREDICTOR_MODE` and `REQUIRE_CLINICAL_REVIEW` remain owner decisions and were not changed.

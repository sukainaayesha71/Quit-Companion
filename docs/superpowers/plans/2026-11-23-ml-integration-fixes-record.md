# ML integration fixes: implementation record (2026-11-23)

Follows `2026-11-23-ml-integration-audit.md` (findings D1–D3). The trained model (EMASENS_ML v2.0.0 XGBoost pipeline) was **not** retrained, replaced or altered. The rule-based predictor remains the fallback. `RELAPSE_PREDICTOR_MODE`, `REQUIRE_CLINICAL_REVIEW`, Firebase, credentials, deployment and Git were not touched.

## Fix 1 — mood sliders: send only real answers

**Before:** all ten 0–10 mood sliders started at 5 and were always saved and sent ("Unchanged ratings are submitted as 5 out of 10"), so the model received ratings the user never gave.

**Now:**
- The Log Craving screen tracks which sliders the user moved (`_ratedMoods`). Untouched sliders show "–" and a muted thumb.
- A note reads "Only the moods you rate are saved. Untouched sliders are left blank, not counted as 5", and "Clear mood ratings" resets them.
- Only moved sliders are passed to the controller.
- `CravingLogController.submitCraving` mood parameters are now `double?` (default `null`, previously 5).
- `null` values are omitted from the request (`'mood_x': ?value`, unchanged API) and stored as `null` in Firestore (fields were already nullable).
- The backend's fitted median imputer handles them. A test verifies that missing inputs equal the training medians, not 5.

## Fix 2 — recovery check-in offered on every craving log

**Before:** a collapsed "Recovery check-in (optional)" tile, placed between the "Rate your mood" heading and its sliders; easy to miss.

**Now:**
- An open card after the mood sliders explains: "Four quick questions. Answering them helps the experimental ML risk estimate; skipped questions are left blank, not guessed."
- It holds the same fields: motivation, confidence, physical discomfort, cigarette availability (1–3), and nicotine used since the last check-in.
- **Skip check-in** clears any answers and shows "Skipped — nothing will be sent for these questions" with an **Answer check-in** option. Skipping never blocks saving.
- The HTTP client sends `recovery_context` only when at least one item was answered.

## Fix 3 — show the prediction source

**Before:** the backend returned `assessment_source` (and `model_version`, `imputed_features`), but the app discarded them.

**Now:**
- `RelapsePredictionClient.predictDetailed` returns a `RelapsePrediction` (risk level, source, model version, imputed features). `predict` is kept for compatibility.
- `parsePredictionSource` maps `machine_learning` / `ModelPredictor` → **ML (Experimental)**; `RuleBasedPredictor` / `rule_based` → **Rule-based**; `rule_based_fallback` → **Rule-based (ML unavailable)**. A missing or unknown value maps to *unknown*, and no label is shown.
- The source is always the backend-reported value, never inferred from configuration.
- The controller stores `lastPredictionSource`. The new `PredictionSourceLabel` ("Scored by: …") appears on the Low/Medium result banner and on the High-risk alternatives screen. It's hidden while an assessment is pending (offline).

## Files changed

| File | Change |
| --- | --- |
| `mobile/lib/features/relapse/data/relapse_prediction_client.dart` | `PredictionSource`, `parsePredictionSource`, labels, `RelapsePrediction`, `predictDetailed` in the interface |
| `mobile/lib/features/relapse/data/http_relapse_prediction_client.dart` | `predictDetailed` parses source/version/imputed fields safely; `predict` delegates; `recovery_context` sent only if non-empty |
| `mobile/lib/features/relapse/data/fake_relapse_prediction_client.dart` | `fixedSource`, `lastRecoveryContext`, `predictDetailed` |
| `mobile/lib/features/craving/controllers/craving_log_controller.dart` | Nullable mood parameters (no default 5); uses `predictDetailed`; `lastPredictionSource` |
| `mobile/lib/features/craving/presentation/screens/log_craving_screen.dart` | Rated-slider tracking, "–" for unrated, honest note and clear button; recovery check-in card with explanation and skip/answer; passes the source to the result screens |
| `mobile/lib/features/craving/presentation/screens/widgets/prediction_source_label.dart` | **New** "Scored by: …" chip |
| `mobile/lib/features/craving/presentation/screens/widgets/risk_result_banner.dart` | Optional `predictionSource`, shown when not pending |
| `mobile/lib/features/craving/presentation/screens/high_risk_screen.dart` | Optional `predictionSource`, shown under the header |
| `mobile/test/features/craving/controllers/craving_log_controller_test.dart` | 2 tests updated: unanswered sliders are `null`, not 5 |
| `mobile/test/features/craving/presentation/log_craving_screen_test.dart` | 2 tests updated (same reason) + **12 new**: slider omission, clear button, check-in visible, answered vs unanswered, skip still saves, reopen, three source labels, no label when unknown or pending, high-risk label |
| `mobile/test/features/relapse/data/prediction_source_test.dart` | **New (6):** source mapping, omitted sliders/check-in in the HTTP body, parsing of source/version/imputed, fallback label, older backend without fields |
| `backend/tests/test_ml_missing_inputs.py` | **New (5):** only unanswered inputs imputed (real endpoint and model); missing = training medians ≠ 5; answered check-in not imputed; rule-based mode source; labelled fallback with partial inputs |
| `docs/superpowers/plans/2026-11-23-ml-integration-audit.md` | Post-fix re-audit appended (original kept) |
| `docs/FINAL_IMPLEMENTATION_STATUS.md` | Footnote ² on the relapse row (row status unchanged) |

No backend application code changed for these fixes; the API already accepted missing values.

## Verified results (2026-11-23)

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| Flutter suite (120 files) | **823 passed, 0 failed, 0 skipped** (exit code 0; 805 before + 18 new) |
| Backend pytest (incl. ML, worker) | **310 passed, 0 failed, 0 skipped** (305 before + 5 new) |
| Firestore rules tests | Not re-run (no rules or Firestore schema changes) |
| Post-fix endpoint audit (real `/predict/relapse` + real model, new payload shape, 5,004 requests) | Completed; results in the audit document |

## Before / after (real endpoint, same model)

| Scenario | Before | After |
| --- | --- | --- |
| Nothing rated, check-in skipped | 500/500 medium | 500/500 medium (now 14 genuinely imputed inputs) |
| Some moods rated, check-in skipped | 87% medium | 96% medium |
| Moods + check-in answered | 59% high / 21% medium / 20% low | 56% high / 20% medium / 24% low |
| Contrasting answered cases | low / high | low (p=0.0067) / high (p=0.3395) |

## Remaining limitations

- **Responsiveness depends on the check-in.** ML responds meaningfully only when the recovery check-in is answered. With it skipped, the model still returns "medium" for almost any input, because its signal comes mostly (~63%) from the check-in items and very little (~3%) from craving intensity. This is a property of the trained model and can't be fixed without retraining.
- **Answer rate unknown.** How often real users answer the check-in hasn't been measured.
- **Model limits:** trained on EMASENS_ML v2.0.0, **6,124 check-ins from 38 UK adult cigarette smokers**. The study's held-out ROC-AUC of 0.84 is **not** real-world accuracy for Quit Companion users. It isn't clinically validated, isn't production-approved (`production_approved: False`), and isn't validated for vaping, pouches or hookah.
- **Old records unaffected:** craving logs saved before this change keep their stored default-5 slider values.

## Manual phone checks

Progress on a physical phone (vivo V2022): see `2026-11-23-physical-device-ml-test-record.md`. Check 1 (nothing rated): PASS, with Medium and "Scored by: ML (Experimental)" confirmed by the owner. Check 2 (two moods + check-in): PASS, with backend 200 and the high-risk screen opened; label text not reported. Firestore values not inspected. Check 4 (skip check-in): PASS, with "Skipped" shown, the craving saved, and Medium plus "Scored by: ML (Experimental)". Check 3 (labels): the ML label is verified on the phone on both the result banner and the high-risk screen; the rule-based and fallback labels are automated-only. Offline check: PASS, with the pending message, no risk level or label, and no request reaching the backend.

1. Log a craving without touching the mood sliders or the check-in. In Firestore the `mood*` fields should be absent or null, and `recoveryContext` empty.
2. Rate two moods and answer the check-in. Only those fields are stored.
3. With the backend in `ml` mode: the result shows "Scored by: ML (Experimental)". In `rule_based` mode: "Scored by: Rule-based". Offline: no label, "Craving Saved".
4. Tap "Skip check-in", then save. The craving saves normally.

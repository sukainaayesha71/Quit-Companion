# Module 3 — Habit & Trigger Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Log Craving flow — capture a craving event (intensity, mood, trigger, location, activity, optional note), classify it into a categorical relapse-risk level (High/Medium/Low) via the SDD's rule-based fallback, persist it, and surface the result to the user — replacing the disabled "Log Craving" tile on the Dashboard with a working screen.

**Architecture:** Mirrors Module 2's split exactly, plus one new piece the SDD's own architecture diagram (§2, carried forward unchanged from the SRDS) requires: relapse-risk scoring runs through the existing FastAPI backend (`backend/`), not client-side Dart — `Flutter → FastAPI /predict/relapse → Rule-Based Decision Table (SRDS §5.5.1)`. Firestore I/O (reading recent craving history, persisting the new log) stays in Flutter, same as every other module; the backend endpoint is a stateless pure-function classifier, mirroring the existing OTP service's shape, not a new stateful service.

**Tech Stack:** Flutter/Dart (`provider`, `cloud_firestore`, `http` — all already dependencies), FastAPI (already the backend framework, extended with one new router), same test stack as Modules 1–2 (`flutter_test` + `pytest`, fakes-over-mocks on both sides).

## Global Constraints

- **FR5's output is categorical only** — High/Medium/Low, never a numeric score. The class diagram's `relapseRiskScore` attribute name is kept for the Firestore field, but its value is always one of the three category strings (matches how the SDD itself resolved the SRDS's internal numeric-vs-categorical conflict).
- **No ML model work.** SDD §10 is explicit: training/evaluating a real model is out of scope, blocked on deferred dataset validation (see `[[dataset_decision_relapse_prediction]]` memory). The rule-based decision table (SRDS §5.5.1) is the *only* relapse-prediction logic this plan implements — it must never be described as "the AI model" in code/comments, per SDD Document Control wording.
- **No cross-module feature invention.** The decision table's High-Risk actions reference features Module 3 does not own and that don't exist yet: "suggest alternative activity" / "suggest breathing exercise" (Alternatives & Habit Replacement — Mehreen's Module 1, FR7, confirmed unbuilt — see `docs/UI_Design/6a.png`), "send push notification" (Notification & Reminder, shared Module 9, unbuilt), "suggest community support" (Community & Peer Support — Mehreen's Module 4, FR11, unbuilt). Module 3 shows the risk level and a generic supportive message only — it must not fabricate working links into features that don't exist (see Open Decision 3).
- **"Cravings Resisted" counting is unconditional.** Per the SRDS pseudocode (`UPDATE Dashboard Statistics (CravingsResisted + 1)` runs on every craving log, not gated by risk level), and because relapse logging is Module 5/FR12 territory (separate, explicit act, Nicotine-Free-phase only) that doesn't exist yet — every craving log counts as "resisted" for now. No new ambiguity here.
- **Module 1/2 stay frozen**, with two narrow, additive exceptions this plan makes explicit up front rather than silently: (1) `CravingLogRepository`'s interface gains new methods alongside its existing `countCravingsResistedSince` — additive only, Module 2's `DashboardController` usage is untouched; (2) one Dashboard file, `quick_access_grid.dart`, gets its "Log Craving" tile enabled and wired to navigate — no other tile, no other Dashboard file, changes. `DashboardController`, `DashboardStateCalculator`, `CountdownStateView`, `NicotineFreeStateView`, and all Module 1 screens/controllers are not touched.
- **Firebase Phone Auth is not touched.** This module doesn't concern auth at all.
- **Firestore rules will need a new match block** (`nicotineUsers/{userId}/cravingLogs/{logId}`, mirroring the existing `usageLogs` block) — Firestore rules do not cascade to subcollections (confirmed the hard way during Module 2's physical-device testing: the identical gap on `usageLogs` produced a `PERMISSION_DENIED` that took a full diagnosis pass to find). This plan lists it as an implementation task; **no rules file changes are made during this planning pass.**

---

## SDD Traceability

**Module ownership (SDD §2.1):** Module 3 = "Habit & Trigger Tracking" (Sukaina), owning:
- **FR5** — categorical relapse risk level (High/Medium/Low) on each craving log, via the rule-based fallback (SRDS §5.5.1) until the deferred trained model is available
- **FR6** — craving/trigger logging (intensity, mood, trigger, location, activity)

**Source logic — SRDS §5.5.2 pseudocode (cleaner and more legible than the OCR'd §5.5.1 table; both describe the same rule set — see Open Decision 1 for the one place they diverge in emphasis):**

```
FUNCTION Log_Craving(User):
  INPUT Intensity (1-10), Mood, TriggerCategory, Location, Activity, Notes
  SAVE CravingLog to CravingLogs_Database with Timestamp
  RISK = CALL AI_Relapse_Prediction(User.CravingHistory, Intensity, Mood, TriggerCategory)
  IF RISK == 'High Risk' THEN
    DISPLAY Early Warning Alert on Dashboard
    CALL Get_Habit_Alternatives(User, TriggerCategory, Mood)   // NOT Module 3's — see constraint above
  ELSE
    DISPLAY 'Log Saved. Keep going!'
  ENDIF
  UPDATE Dashboard Statistics (CravingsResisted + 1)
END FUNCTION

FUNCTION AI_Relapse_Prediction(CravingHistory, Intensity, Mood, Trigger):
  IF Intensity >= 8 THEN RETURN 'High Risk'
  ELSE IF Mood == 'Stressed' AND Trigger == 'Social Pressure' THEN RETURN 'High Risk'
  ELSE IF COUNT(CravingHistory.last24hrs) >= 3 THEN RETURN 'High Risk'
  ELSE IF Intensity >= 5 AND Mood IN ['Anxious','Bored'] THEN RETURN 'Medium Risk'
  ELSE RETURN 'Low Risk'
END FUNCTION
```

**Architecture (SDD §2, unchanged from SRDS):**
```
Flutter Mobile Client --HTTPS/JSON--> FastAPI AI Server --Relapse scoring--> Relapse Prediction Service
  --fallback, active today--> Rule-Based Decision Table (SRDS §5.5.1)
  -.primary, deferred.-> Trained ML Model (PATH-dependent, NOT YET BUILT — out of scope, SDD §10)
```
This is why the classifier is a FastAPI endpoint, not a Dart function: the diagram already shows both the fallback and the (deferred) primary hanging off the same backend node, so today's rule-based logic occupies the exact slot the real model will later fill — no client-side rework needed when that unblocks. UC3 (SRDS §3.2.4) names the endpoint directly: `POST /predict/relapse`.

**Data model (SDD §6 + SRDS §5.2):** `CravingLog { logId, userId, cravingIntensity, mood, triggerCategory, locationContext, activity, timestamp, relapseRiskScore }`, plus `notes` (see Open Decision 2). Distinct from `UsageLog` (Module 2, daily totals) and `JournalEntry`/`RelapseEvent` (Module 5, Nicotine-Free-phase relapse only).

**Approved UI reference:** `docs/UI_Design/log craving 6.png` — intensity slider (1–10), mood chips (Stressed/Bored/Sad/Happy/Social — confirms the real mood vocabulary, see Open Decision 1), trigger chips (Stress/After Meal/Social Pressure/Boredom/Other), Location + Activity dropdowns, optional notes textarea, Submit button.

---

## Dependency check — what Modules 1–2 already provide

| Need | Already exists | Where |
|---|---|---|
| Signed-in `userId` | ✅ | Available wherever `DashboardScreen`/`main.dart`'s `_OnboardingFlow` already thread it |
| A narrow `CravingLogRepository` interface Module 2 already depends on | ✅ (needs additive extension, not replacement) | `lib/data/craving_log_repository.dart`, `lib/data/fake_craving_log_repository.dart` |
| A Dashboard entry point (currently disabled) | ✅ | `lib/screens/dashboard/widgets/quick_access_grid.dart` — "Log Craving" tile |
| Backend HTTP-client pattern to mirror (interface + Http + Fake, base-URL config) | ✅ | `lib/data/whatsapp_otp_backend_client.dart` / `http_whatsapp_otp_backend_client.dart` / `fake_whatsapp_otp_backend_client.dart`, `lib/config/otp_backend_config.dart` |
| Backend router/service pattern to mirror (APIRouter + Pydantic models + injectable service) | ✅ | `backend/app/routers/phone_auth.py`, `backend/app/otp/service.py`, `backend/app/dependencies.py` |
| Design tokens | ✅ | `lib/theme/app_theme.dart` |
| Firestore per-user subcollection pattern to mirror | ✅ | `lib/data/firestore_usage_log_repository.dart` (`nicotineUsers/{userId}/usageLogs/{logId}`) |

**Nothing Module 3 needs from Modules 1–2 is missing.** The one shared surface (`CravingLogRepository`) is designed for exactly this — Module 2's plan built it as a deliberately narrow interface so Module 3 could extend it without rework.

## Gap analysis — what's missing (all net-new except where marked)

Confirmed via search: no `CravingLog` model, no risk-classification logic (Flutter or backend), no Log Craving screen, no `cravingLogs` Firestore rule exist anywhere yet.

**Flutter:**
- `CravingLog` model + `Mood` / `TriggerCategory` / `RelapseRiskLevel` enums
- `CravingLogRepository` — **extend** (additive) with `logCraving(...)`, `countLoggedSince(userId, since)` (for the 24h-count rule input); Fake/Firestore implementations
- `RelapsePredictionClient` interface + `HttpRelapsePredictionClient` + `FakeRelapsePredictionClient` (new backend-client trio, mirrors the OTP one)
- `CravingLogController` (ChangeNotifier, mirrors `DashboardController`'s status-enum pattern)
- `LogCravingScreen` + supporting widgets (mood/trigger chip selector, risk-result banner)
- Wiring: `quick_access_grid.dart`'s "Log Craving" tile enabled; `main.dart` gets a new step/route to the screen, swaps `FakeCravingLogRepository` → `FirestoreCravingLogRepository`

**Backend:**
- `app/relapse/service.py` — pure rule-based classifier (mirrors `app/otp/service.py`'s shape)
- `app/routers/relapse.py` — `POST /predict/relapse` (mirrors `app/routers/phone_auth.py`)
- `app/main.py` — register the new router

**Config/infra:**
- `firestore.rules` — new `match /cravingLogs/{logId}` block under `nicotineUsers/{userId}` (task only, not executed this pass)

---

## Three open decisions — need your call before implementation (not silently resolving these)

**1. Reconciling the decision table's mood vocabulary against the approved UI's mood vocabulary.**
The SRDS decision table (§5.5.1) and its own pseudocode reference mood values — `Anxious`, `Depressed`, `Neutral`, `Positive`, `Motivated` — that don't exist anywhere else in the spec. The approved UI (`log craving 6.png`) and SRDS Use Case #3's own step list agree on a different, real 5-value set: **Stressed, Bored, Sad, Happy, Social**. Only `Stressed` and `Bored` overlap between the two lists. I'm not going to silently pick one — here's my proposed reconciliation, built from the pseudocode's cleaner IF-chain but substituting only mood values the UI can actually produce:

```
IF intensity >= 8                                    → High Risk
ELSE IF mood == Stressed AND trigger == SocialPressure → High Risk
ELSE IF cravingLogsInLast24h (incl. this one) >= 3    → High Risk
ELSE IF intensity in 5-7 AND mood == Bored            → Medium Risk
ELSE                                                   → Low Risk
```
This drops the unmappable mood values entirely (they can never occur given the real 5-option list) rather than guessing at a mapping. **Please confirm this table, or provide the mapping you'd prefer** — this is the one piece of business logic in this module I can't derive from unambiguous source material.

**2. Adding a `notes` field to `CravingLog`.**
The SRDS class diagram's `CravingLog` attribute list (§5.2) does **not** include a notes field, but SRDS Use Case #3 step 6 ("User optionally adds a free-text note") and the approved UI screenshot both show one. I'd treat the class diagram as incomplete here (it also omits nothing else UC3 describes) and add `notes: String?` — but flagging rather than silently adding it, since it's a data-model field not explicitly in the class diagram. **Confirm, or tell me to omit it** (in which case the UI's notes textarea would need removing too, contradicting the approved screenshot — so omitting seems like the worse option, but it's your call).

**3. What "Early Warning Alert" actually shows, given the real suggestion features don't exist yet.**
The decision table's High-Risk actions all point at unbuilt features (Alternatives, push notifications, Community — see Global Constraints). My proposal: show a plain risk banner ("This craving looks intense — you're not alone, keep going" or similar non-clinical, non-fabricated copy) with the risk level, and nothing that pretends to link into Alternatives/Community/push. **Confirm this minimal treatment, or tell me if you'd rather Module 3 wait/stub a visible-but-disabled link to Alternatives (matching the Quick Access grid's existing disabled-tile pattern from Module 2) so the hookup is a one-line change once that module lands.**

Everything else below is unambiguous and ready to build as soon as you approve.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/craving_log.dart` | New `CravingLog` entity (SDD §6 / SRDS §5.2) |
| `lib/models/mood.dart` | New enum: `stressed, bored, sad, happy, social` |
| `lib/models/trigger_category.dart` | New enum: `stress, afterMeal, socialPressure, boredom, other` |
| `lib/models/relapse_risk_level.dart` | New enum: `high, medium, low` |
| `lib/data/craving_log_repository.dart` | **Modify (additive):** add `logCraving(CravingLog)`, `countLoggedSince(userId, since)` alongside existing `countCravingsResistedSince` |
| `lib/data/fake_craving_log_repository.dart` | **Modify:** implement new methods in-memory |
| `lib/data/firestore_craving_log_repository.dart` | New real Firestore implementation (`nicotineUsers/{userId}/cravingLogs`), mirrors `firestore_usage_log_repository.dart` |
| `lib/data/relapse_prediction_client.dart` | New abstract interface: `Future<RelapseRiskLevel> predict({intensity, mood, trigger, last24hCount})` |
| `lib/data/http_relapse_prediction_client.dart` | New real implementation, calls `POST /predict/relapse`, mirrors `http_whatsapp_otp_backend_client.dart` |
| `lib/data/fake_relapse_prediction_client.dart` | New in-memory/scripted test double |
| `lib/config/otp_backend_config.dart` | Reused as-is for the base URL (same backend process) — no change needed |
| `lib/controllers/craving_log_controller.dart` | New ChangeNotifier: orchestrates count→predict→save, exposes status/result |
| `lib/screens/craving/log_craving_screen.dart` | New screen matching `log craving 6.png` |
| `lib/screens/craving/widgets/risk_result_banner.dart` | New: shows risk level + generic message (Open Decision 3) |
| `lib/screens/dashboard/widgets/quick_access_grid.dart` | **Modify:** enable "Log Craving" tile only, wire `onTap` |
| `lib/main.dart` | **Modify:** new step/route to `LogCravingScreen`; swap `FakeCravingLogRepository` → `FirestoreCravingLogRepository`; provide `CravingLogController` |
| `firestore.rules` | **Modify (task only, not this pass):** add `cravingLogs` subcollection rule |
| `backend/app/relapse/service.py` | New: pure rule-based classifier function |
| `backend/app/routers/relapse.py` | New: `POST /predict/relapse` |
| `backend/app/main.py` | **Modify:** register new router |

## Task Breakdown

### Task 1: `CravingLog` model + enums
**Files:** Create `lib/models/craving_log.dart`, `lib/models/mood.dart`, `lib/models/trigger_category.dart`, `lib/models/relapse_risk_level.dart`
Plain data classes/enums, mirrors `NicotineUser`/`ProductType`/`QuitStrategy`'s style.

### Task 2: Backend rule-based classifier + endpoint
**Files:** Create `backend/app/relapse/service.py`, `backend/app/routers/relapse.py`; Modify `backend/app/main.py`; Test: `backend/tests/test_relapse_service.py`, `backend/tests/test_relapse_router.py`
Pure function per the reconciled table (Open Decision 1, pending confirmation). Endpoint takes `{intensity, mood, triggerCategory, last24hCount}`, returns `{riskLevel}`. Table-driven tests over every branch.

### Task 3: `CravingLogRepository` extension + Firestore implementation
**Files:** Modify `lib/data/craving_log_repository.dart`, `lib/data/fake_craving_log_repository.dart`; Create `lib/data/firestore_craving_log_repository.dart`; Test: extend `test/data/fake_craving_log_repository_test.dart`
Additive only — `countCravingsResistedSince`'s existing signature/behavior untouched (Module 2 depends on it).

### Task 4: Relapse-prediction backend client (Flutter side)
**Files:** Create `lib/data/relapse_prediction_client.dart`, `lib/data/http_relapse_prediction_client.dart`, `lib/data/fake_relapse_prediction_client.dart`; Test: `test/data/http_relapse_prediction_client_test.dart`
Mirrors the WhatsApp OTP client trio exactly (same base-URL config, same error-surfacing pattern).

### Task 5: `CravingLogController`
**Files:** Create `lib/controllers/craving_log_controller.dart`; Test: `test/controllers/craving_log_controller_test.dart`
**Consumes:** `CravingLogRepository`, `RelapsePredictionClient`
**Produces:** `submitCraving({intensity, mood, trigger, location, activity, notes})` → counts last-24h logs, calls the predictor, saves the `CravingLog` (with returned risk level), exposes status/result (mirrors `DashboardController`'s status-enum pattern).

### Task 6: `LogCravingScreen` + risk banner
**Files:** Create `lib/screens/craving/log_craving_screen.dart`, `lib/screens/craving/widgets/risk_result_banner.dart`; Test: `test/screens/log_craving_screen_test.dart`
Matches `log craving 6.png`: intensity slider, mood/trigger chip selectors, location/activity dropdowns, optional notes, submit. Shows `RiskResultBanner` per Open Decision 3 on success.

### Task 7: Wire into Dashboard + app flow
**Files:** Modify `lib/screens/dashboard/widgets/quick_access_grid.dart` (enable "Log Craving" tile only), `lib/main.dart` (route + `FirestoreCravingLogRepository` swap + provider); Test: extend `test/screens/dashboard_screen_test.dart` to assert the tile navigates
No other Quick Access tile changes. No other Dashboard file changes.

### Task 8: Firestore rules
**Files:** Modify `firestore.rules` (add `cravingLogs` subcollection match block, mirroring `usageLogs`); deploy
Explicitly called out given the identical gap caused a production bug on `usageLogs` during Module 2's device testing — this task exists specifically so it isn't forgotten again.

---

## Which Dashboard features become functional

- **"Log Craving" Quick Access tile** — currently disabled/dimmed (Module 2 redesign) — becomes the only tile enabled by this module, navigating to `LogCravingScreen`.
- **"Cravings Resisted" stat** (Dashboard hero stats row, Module 2) — currently always 0 via `FakeCravingLogRepository` — becomes real once `FirestoreCravingLogRepository` is wired in `main.dart` (Task 7). No Module 2 UI code changes; the number simply starts reflecting real data through the same interface it already reads.
- All other Quick Access tiles (Alternatives, Health-Bot, Rewards, Community, Journal, Relapse Log, Knowledge Hub, My Goal) remain disabled — none of them are Module 3's FRs.

## Required tests summary

**Flutter:** model sanity (if any derived logic beyond plain fields), extended `fake_craving_log_repository_test.dart`, `http_relapse_prediction_client_test.dart`, `craving_log_controller_test.dart`, `log_craving_screen_test.dart`, extended `dashboard_screen_test.dart` (tile navigation).
**Backend:** `test_relapse_service.py` (every rule branch, table-driven), `test_relapse_router.py` (request/response shape, validation errors), mirroring `test_otp_service.py`/`test_phone_auth_router.py`.

## Self-review

- **Spec coverage:** FR5 (Task 2 classifier + Task 5 orchestration), FR6 (Task 1 model + Task 6 screen) — both covered. SRDS UC3's full field/step list mapped to Task 6's screen contents.
- **Placeholder scan:** the three flagged open decisions are explicit confirmation points, not silent guesses — no task proceeds by inventing mood-vocabulary mappings, undocumented fields, or working links into unbuilt modules.
- **Boundary check:** every reference to Alternatives/Push/Community/badges/streak-increment/restart-plan in the source pseudocode was traced to its actual owning module (confirmed via SDD §2.1's ownership table and, for Alternatives, the actual approved screenshot `6a.png`) and excluded from this plan's scope rather than half-built.
- **Type consistency:** `CravingLogRepository`/`RelapsePredictionClient`/`CravingLogController` names used consistently across Tasks 1–7; backend request/response field names match what Task 4's Flutter client sends/expects.

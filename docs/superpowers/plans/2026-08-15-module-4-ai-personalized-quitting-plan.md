# Module 4 — AI Personalized Quitting Plan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the two adaptation paths FR17 requires — a **scheduled weekly plan/goal update** (buildable and reachable end-to-end today, via the Dashboard's existing "My Goal" tile) and an **immediate restart-plan generator** (buildable and fully tested today, but **not reachable through any real user flow yet** — its trigger, Module 5's relapse-logging screen, doesn't exist).

**Architecture:** Unlike FR5 (Module 3), the SDD gives **no explicit implementation mechanism** for FR17 — the architecture diagram (§2) has no node for a "Quitting Plan Service," and §7.7's `AI_Adapt_Plan`/`AI_Generate_Restart_Plan` are unspecified black boxes. This plan proposes treating both as **pure Dart domain calculators** (mirroring `DashboardStateCalculator`/`QuitDateCalculator`'s existing style — deterministic, rule/template-based, no network call, no new backend endpoint) rather than a FastAPI service — see Open Decision 1 before building.

**Tech Stack:** Flutter/Dart only if Open Decision 1 is confirmed as proposed (`provider`, `cloud_firestore` — no new package). No backend/FastAPI work unless Open Decision 1 is decided the other way.

## Global Constraints

- **No live generative AI content.** Every other AI-adjacent feature in this codebase (FR5's relapse risk, FR7/FR8's alternatives/Health-Bot content) is explicitly constrained to fixed, pre-vetted, or rule-based output because no live clinical/medical advisor exists to review free-form output (SDD §4 NFR, repeated at FR7/FR8). FR17 isn't given the same explicit caveat in the SDD, but the reference screenshot's restart-plan content ("Try the 4-7-8 breathing technique," "Avoid your usual after-lunch smoke spot") reads as template-selected from trigger/mood inputs, not generated prose. This plan treats FR17 under the same no-fabrication constraint as the rest of the app's "AI" features — see Open Decision 4.
- **No cross-module feature invention.** The reference screenshot's "Check in with the community for extra support" suggestion points at Community & Peer Support (Mehreen's Module 4-numbered-differently... actually her Module 4 is Community & Peer Support, FR11 — unbuilt). Any such suggestion is data, not a working link — see Open Decision 4.
- **Module 5 dependency is real and unresolved.** SDD §7.7 states the immediate path is "invoked from Module 5's relapse-logging flow, not a separate mechanism" — Module 5 (Relapse Prevention & Reflection, FR12) doesn't exist. `docs/UI_Design/relapse 11.png` ("Let's Log This Moment") is **Module 5's** screen, not Module 4's — it is explicitly **not** built by this plan.
- **No data-model entity exists for this module's outputs.** SDD §6 lists only `NicotineUser`'s new attributes and the new `UsageLog` entity; it explicitly says all other SRDS entities (`CravingLog`, `HabitAlternative`, `JournalEntry`, `Badge`, `CommunityPost`, `HealthBotConversation`) are "unchanged" — meaning carried from a class diagram that **also never defined** a `RelapseEvent`, `QuitPlan`, or `WeeklyGoal` entity. §7.7's own pseudocode says `SAVE UpdatedGoals to User.Profile` (implying new fields on the existing `NicotineUser` document, not a new collection) but §7.4 never says whether the restart plan itself is persisted. See Open Decision 2.
- **Modules 1-3 stay frozen**, with the same kind of narrow, additive exception Module 3 took on `CravingLogRepository`: `NicotineUser` (Module 1's model) and `FirestoreUserRepository` (Module 1's repository) gain additive fields/mapping for weekly-goal data — nothing else in Module 1 changes. `DashboardController`/`DashboardStateCalculator` (Module 2) are read from, not modified, except enabling one Quick Access tile exactly as Module 3 did.
- **Firebase Phone Auth is not touched.** Unrelated to this module.
- **No new Firestore rule needed** (tentatively) — if weekly-goal data lives as fields on the existing `nicotineUsers/{userId}` document (Open Decision 2), the existing rule already covers it. If a restart-plan history subcollection is wanted instead, a new rule would be needed — flagged in that decision.

---

## SDD Traceability

**Module ownership (SDD §2.1):** Module 4 = "AI Personalized Quitting Plan" (Sukaina), owning:
- **FR17** — ongoing weekly goal/recommendation updates (both phases) + immediate restart-plan generation on Nicotine-Free-phase relapse. **Does not own FR3** (one-time onboarding Quit Strategy/Quit Day — Module 1's alone).

**Core logic spec — SDD §7.7 `Generate_Weekly_Plan_Update`, §7.4 `Log_Relapse`'s restart-plan call:**
```
FUNCTION Generate_Weekly_Plan_Update(User):
  // Runs on a weekly cadence for any user past onboarding, in either
  // Countdown or Nicotine-Free phase.
  Progress = COLLECT(User.UsageLogs, User.CravingLogs, User.lastRelapseDate, ReductionStreak)
  UpdatedGoals = AI_Adapt_Plan(User.quitStrategy, Progress)
  SAVE UpdatedGoals to User.Profile
  DISPLAY Updated weekly goals/recommendations
END FUNCTION
```
```
FUNCTION Log_Relapse(User):                              // Module 5 owns this whole function
  ...
  RESTART_PLAN = CALL AI_Generate_Restart_Plan(User.CravingHistory, RelapseTrigger)   // Module 4 owns only this call's target
  DISPLAY RESTART_PLAN with compassionate message
  ...
END FUNCTION
```
Two update paths (§7.7, explicit): **Immediate** (relapse-triggered, synchronous, invoked from Module 5) vs. **Scheduled** (weekly cadence, folds in Countdown-phase Reduction-Streak breaks rather than triggering instantly).

**Approved UI reference:** `docs/UI_Design/restart plan result screen 12.png` — headline "Recovery isn't linear. Let's try again.", subtext "Here's your adjusted plan, built just for you.", a plant/growth illustration, a white card titled "Your Restart Plan" with a checklist (green checkmark + short recommendation per line — 3 shown, list appears to continue below the visible fold), and a full-width "Back to Dashboard" button.

**No approved UI reference exists for the weekly-plan-update display.** All 14 numbered UI Design screenshots were inspected; none show a "weekly goals" screen. `docs/UI_Design/relapse 11.png` ("Let's Log This Moment" — a relapse-logging form: When/What/Trigger chips/Mood chips/notes/Submit) is Module 5's, not Module 4's — noted here only to rule it out. See Open Decision 3.

---

## Dependency check — what Modules 1-3 already provide

| Need | Already exists | Where |
|---|---|---|
| `quitStrategy`, `quitDate`, `lastRelapseDate` | ✅ | `lib/models/nicotine_user.dart`, `lib/data/firestore_user_repository.dart` |
| `UsageLog` history (Countdown-phase) | ✅ | `lib/data/usage_log_repository.dart` / `firestore_usage_log_repository.dart` |
| `CravingLog` history (both phases) | ✅ | `lib/data/craving_log_repository.dart` / `firestore_craving_log_repository.dart` — currently only exposes counts (`countCravingsResistedSince`, `countLoggedSince`); Progress collection needs the actual logs, not just counts — see Gap Analysis |
| Reduction Streak calculation | ✅ (logic lives in `DashboardStateCalculator`, not separately exposed) | `lib/domain/dashboard_state_calculator.dart` |
| A disabled Dashboard destination tile ready to enable | ✅ — "My Goal" tile, `Icons.outlined_flag_rounded`, index 8 | `lib/screens/dashboard/widgets/quick_access_grid.dart` |
| Design tokens | ✅ | `lib/theme/app_theme.dart` |
| Precedent for a "build ahead of an unbuilt caller" interface (mirrors this plan's restart-plan situation) | ✅ | `lib/data/craving_log_repository.dart`'s original narrow-interface pattern (Module 2 plan) |

**Gap found while checking dependencies:** `CravingLogRepository` has no method returning actual `CravingLog` records (mood/trigger/intensity history) — only aggregate counts. `Generate_Weekly_Plan_Update`'s `Progress = COLLECT(...)` needs real craving history (to notice patterns, e.g., repeated triggers) for anything beyond trivial goal adaptation. This plan adds one additive method (`getRecentLogs(userId, since)`) to the same interface Module 3 already established as extensible.

## Gap analysis — what's missing (all net-new)

- `WeeklyPlanCalculator` (or similar) — pure function implementing `Generate_Weekly_Plan_Update`'s adaptation logic
- `RestartPlanCalculator` — pure function implementing `AI_Generate_Restart_Plan`
- `AiPlanController` (ChangeNotifier) — loads progress data, computes/persists weekly goals, exposes state to the UI
- `WeeklyGoal`/similar model — new, since SDD defines none (Open Decision 2)
- `WeeklyPlanScreen` matching... **nothing** (no approved mockup — Open Decision 3)
- `RestartPlanScreen` matching `docs/UI_Design/restart plan result screen 12.png`
- `CravingLogRepository.getRecentLogs(...)` — additive extension
- `FirestoreUserRepository` — additive field mapping for persisted weekly-goal data (Open Decision 2)
- Wiring: enable Dashboard's "My Goal" tile → `WeeklyPlanScreen`. **No wiring for `RestartPlanScreen`** — nothing exists yet to navigate from (Module 5 doesn't exist); it will be built, tested, and left unrouted, exactly as `CravingLogRepository`'s interface sat unimplemented-by-a-real-caller until Module 3 landed.

---

## Four open decisions — need your call before implementation (not silently resolving these)

**1. Implementation mechanism: client-side Dart, or a new FastAPI backend service?**
FR5 (Module 3) has an explicit architecture mandate (§2's diagram routes relapse scoring through `FastAPI AI Server → Relapse Prediction Service`). FR17 has **no equivalent statement anywhere** — no diagram node, no "backend" language in §7.7, unlike FR5's UC3 which explicitly named a `POST /predict/relapse` endpoint. My proposal: implement both `AI_Adapt_Plan` and `AI_Generate_Restart_Plan` as pure Dart domain calculators (no network call), because (a) nothing in the SDD requires a backend round-trip here, (b) it avoids inventing infrastructure the spec doesn't ask for, and (c) if a real ML-driven personalization engine is ever built, swapping a Dart calculator for an HTTP call later is a small, contained change — same reasoning already applied to Module 3's rule-based classifier placement, just the other direction. **Confirm this, or tell me you want a FastAPI endpoint instead** (mirroring `backend/app/relapse/`).

**2. Data model: what gets persisted, and where?**
- **Weekly goals:** §7.7 says `SAVE UpdatedGoals to User.Profile` — I'd add fields directly to the `NicotineUser` document (e.g. `weeklyGoals: List<String>`, `weeklyGoalsUpdatedAt: DateTime`) rather than a new subcollection, matching that literal instruction. **Confirm this shape, or specify a different one.**
- **Restart plan:** §7.4 never says to persist it at all — just "DISPLAY RESTART_PLAN." I'd treat it as **computed on-demand, not persisted** (pure function output, shown once, not stored). **Confirm, or tell me it needs a history/audit trail** (which would need a new Firestore subcollection + rule, unlike the weekly-goals case).

**3. Where does the weekly-plan-update actually get shown, given no mockup exists?**
My proposal: enable the Dashboard's existing disabled **"My Goal"** Quick Access tile (`quick_access_grid.dart`, already present with a flag icon, doing nothing today) as the destination — it's the only tile whose label plausibly matches "weekly goals," and reusing it avoids inventing a screen with no visual reference. The screen itself would need a **plain, unreferenced layout** (list of current goals/recommendations, reusing existing card/typography patterns from Modules 2-3 — not copying any other module's specific mockup, since none fits). **Confirm this mapping and that a plain (non-mockup-matched) layout is acceptable here** — this is the one screen in this plan that can't follow a "match the screenshot" instruction because no screenshot exists.

**4. Content policy for both plan types — what can actually be recommended?**
The restart-plan mockup's third suggestion ("Check in with the community for extra support") points at Module 4-for-Mehreen (Community & Peer Support, unbuilt). My proposal: **only produce recommendations Module 4 can back with real, already-built functionality** — i.e., no suggestion type that would need a working link to Alternatives/Community/Health-Bot (none of which exist). Recommendation content itself (things like "try 4-7-8 breathing," "avoid your usual trigger spot") would be a **small fixed template library**, selected deterministically from `TriggerCategory`/`Mood`/streak-break patterns — same "fixed, pre-vetted content" posture as FR7. **Confirm this scope, or tell me which specific recommendation types you want included even without a working link** (shown as plain text, not a broken button, matching the disabled-tile precedent).

Everything else below is unambiguous and ready to build as soon as you approve.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/weekly_goal.dart` | New: weekly-goal data shape (pending Open Decision 2) |
| `lib/domain/weekly_plan_calculator.dart` | Pure function: `Generate_Weekly_Plan_Update` (§7.7) |
| `lib/domain/restart_plan_calculator.dart` | Pure function: `AI_Generate_Restart_Plan` (§7.4) |
| `lib/data/craving_log_repository.dart` | **Modify (additive):** add `getRecentLogs(userId, since)` |
| `lib/data/fake_craving_log_repository.dart` / `firestore_craving_log_repository.dart` | **Modify:** implement new method |
| `lib/data/user_repository.dart` / `firestore_user_repository.dart` | **Modify (additive):** persist/read weekly-goal fields on `NicotineUser` (pending Open Decision 2) |
| `lib/controllers/ai_plan_controller.dart` | New ChangeNotifier: loads progress, computes + persists weekly goals |
| `lib/screens/goals/weekly_plan_screen.dart` | New: "My Goal" destination (no mockup — Open Decision 3) |
| `lib/screens/relapse/restart_plan_screen.dart` | New: matches `docs/UI_Design/restart plan result screen 12.png`; built/tested, not yet routed (Module 5 dependency) |
| `lib/screens/dashboard/widgets/quick_access_grid.dart` | **Modify:** enable "My Goal" tile only, wire `onTap` |
| `lib/main.dart` | **Modify:** route/provider wiring for `AiPlanController` + `WeeklyPlanScreen` navigation |

## Task Breakdown

### Task 1: `WeeklyGoal` model (pending Open Decision 2)
**Files:** Create `lib/models/weekly_goal.dart`

### Task 2: `CravingLogRepository.getRecentLogs` extension
**Files:** Modify `lib/data/craving_log_repository.dart`, `fake_craving_log_repository.dart`, `firestore_craving_log_repository.dart`; Test: extend `test/data/fake_craving_log_repository_test.dart`
Additive only — existing methods' signatures untouched (Module 2/3 dependents unaffected).

### Task 3: `WeeklyPlanCalculator` (pure domain logic, §7.7)
**Files:** Create `lib/domain/weekly_plan_calculator.dart`; Test: `test/domain/weekly_plan_calculator_test.dart`
**Consumes:** `NicotineUser`, `List<UsageLog>`, `List<CravingLog>`, reduction-streak int (reuse `DashboardStateCalculator`'s existing streak computation rather than duplicating it — likely needs that method exposed, a small additive change to `DashboardStateCalculator`).
**Produces:** a small set of deterministic goal/recommendation strings from the fixed template library (Open Decision 4).

### Task 4: `RestartPlanCalculator` (pure domain logic, §7.4's call target)
**Files:** Create `lib/domain/restart_plan_calculator.dart`; Test: `test/domain/restart_plan_calculator_test.dart`
**Consumes:** `List<CravingLog>` (CravingHistory), `TriggerCategory` (RelapseTrigger) — both types already exist from Module 3.
**Produces:** the restart-plan checklist content, template-selected per Open Decision 4.

### Task 5: `AiPlanController`
**Files:** Create `lib/controllers/ai_plan_controller.dart`; Test: `test/controllers/ai_plan_controller_test.dart`
**Consumes:** `UserRepository`, `UsageLogRepository`, `CravingLogRepository`, `WeeklyPlanCalculator`
**Produces:** `loadWeeklyPlan(userId)`, exposes computed goals + status (mirrors `DashboardController`'s pattern).

### Task 6: `WeeklyPlanScreen`
**Files:** Create `lib/screens/goals/weekly_plan_screen.dart`; Test: `test/screens/weekly_plan_screen_test.dart`
Plain layout (Open Decision 3) reusing existing card/typography conventions from Modules 2-3.

### Task 7: `RestartPlanScreen`
**Files:** Create `lib/screens/relapse/restart_plan_screen.dart`; Test: `test/screens/restart_plan_screen_test.dart`
Matches `docs/UI_Design/restart plan result screen 12.png` exactly (illustration, headline, checklist card, "Back to Dashboard" button). **Not wired into any navigation flow this plan** — ready for Module 5 to call.

### Task 8: Wire "My Goal" into Dashboard
**Files:** Modify `lib/screens/dashboard/widgets/quick_access_grid.dart` (enable "My Goal" tile only), `lib/main.dart` (provider + navigation); Test: extend `test/screens/dashboard_screen_test.dart`
No other Quick Access tile changes. No other Dashboard file changes.

---

## Which Dashboard features become functional

- **"My Goal" Quick Access tile** — becomes the only tile enabled by this module, navigating to `WeeklyPlanScreen`.
- All other Quick Access tiles (Alternatives, Health-Bot, Rewards, Community, Journal, Relapse Log, Knowledge Hub) remain disabled — none are Module 4's FRs. "Log Craving" (Module 3) stays as already wired.

## Required tests summary

`weekly_plan_calculator_test.dart`, `restart_plan_calculator_test.dart` (both pure-function, table-driven over template selection), extended `fake_craving_log_repository_test.dart`, `ai_plan_controller_test.dart`, `weekly_plan_screen_test.dart`, `restart_plan_screen_test.dart`, extended `dashboard_screen_test.dart` (tile navigation). No backend tests unless Open Decision 1 goes the other way.

## Self-review

- **Spec coverage:** FR17's scheduled path (Tasks 1,3,5,6,8) fully wired end-to-end. FR17's immediate path (Tasks 4,7) built and tested but intentionally not wired — its caller is Module 5, not this module, per SDD §7.7's own wording.
- **Placeholder scan:** all four open decisions are explicit confirmation points, not silent guesses — no task proceeds by inventing a data schema, a backend that isn't specified, a UI with no reference, or working links into Community/Alternatives.
- **Boundary check:** `docs/UI_Design/relapse 11.png` traced to Module 5 and excluded. Restart-plan's "Check in with the community" suggestion traced to Mehreen's Module 4 (Community) and flagged rather than half-implemented.

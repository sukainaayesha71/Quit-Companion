# Module 2 — Dashboard & Progress Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the phase-aware Dashboard screen (Countdown vs. Nicotine-Free state) with Reduction Streak and Money Saved calculations, replacing the current `LoggedInScreen` placeholder as the app's post-auth/post-onboarding home.

**Architecture:** Pure-function domain calculator (mirrors `QuitDateCalculator`) computes dashboard state from a `NicotineUser` + `UsageLog` history; a `DashboardController` (ChangeNotifier, mirrors `OnboardingController`) loads the user via the existing `UserRepository` and usage logs via a new `UsageLogRepository`; a `DashboardScreen` renders whichever phase state the calculator returns. No new backend/FastAPI work — this is Firestore + Flutter only, per SDD §2's architecture (unchanged).

**Tech Stack:** Flutter/Dart, `provider` (ChangeNotifier), Firestore (`cloud_firestore`), same test stack as Module 1 (`flutter_test`, fakes-over-mocks).

## Global Constraints

- Reduction Streak (FR10) is **not** the engagement (daily check-in) streak and **not** `NicotineFreeDays` — SDD §7.6 requires these three stay visually and logically distinct anywhere they appear together.
- No badges/milestone logic here — that's FR9, a Gamification-module (Mehreen's) concern; Dashboard only *displays* phase-appropriate progress data.
- Countdown-phase usage is never a relapse; only `Log_Usage` (§7.5) semantics apply pre-`quitDate`.
- `NicotineFreeDays` is **derived, never stored** (SDD §6) — always computed from `MAX(quitDate, lastRelapseDate)` to `Today`.
- No live medical-advisor review exists — any health-recovery-timeline content must come from a fixed, pre-vetted source (same constraint SDD applies to FR7/FR8), never freely generated.
- Firebase Phone Auth and all Module 1 code are frozen — this plan creates new files and reads Module 1's existing `UserRepository`/`NicotineUser`; it does not modify Module 1 files.

---

## SDD Traceability

**Module ownership (SDD §2.1):** Module 2 = "Dashboard & Progress Analytics" (Sukaina), owning:
- **FR4** — phase-aware dashboard (Countdown / Nicotine-Free states)
- **FR10** — Reduction Streak (Gradual-strategy Countdown phase only)
- **FR16** — Money Saved (both phases, different formulas)

**Core logic spec — SDD §7.2 `Get_Dashboard_State`, §7.5 `Log_Usage`:**

```
FUNCTION Get_Dashboard_State(User):
  IF Today < User.quitDate THEN
    DaysUntilQuit = User.quitDate - Today
    IF User.quitStrategy == 'GRADUAL' THEN
      TodayTarget = User.reductionSchedule[Today]
      ReductionStreak = COUNT consecutive days actualUsage <= scheduledTarget   // FR10
      MoneySavedSoFar = SUM (baselineDailyUsage - actualDailyUsage) * costPerUnit   // FR16
      DISPLAY CountdownState(DaysUntilQuit, TodayTarget, ReductionStreak, MoneySavedSoFar)
    ELSE
      DISPLAY CountdownState(DaysUntilQuit)   // DATE_BASED: no usage-reduction data to show
    ENDIF
  ELSE
    EffectiveStart = MAX(User.quitDate, User.lastRelapseDate)
    NicotineFreeDays = Today - EffectiveStart
    MoneySaved = NicotineFreeDays * baselineDailyUsage * costPerUnit   // FR16
    DISPLAY NicotineFreeState(NicotineFreeDays, MoneySaved, CravingsResisted, HealthRecoveryTimeline)
  ENDIF
END FUNCTION

FUNCTION Log_Usage(User, ActualUsageToday):
  SAVE UsageLog(User.userId, Today, ActualUsageToday, User.reductionSchedule[Today])
  UPDATE ReductionStreak per §7.2
END FUNCTION
```

**Data model (SDD §6):** new entity `UsageLog { logId, userId, date, actualUsage, targetUsage }` — distinct from `CravingLog` (Module 3) and `RelapseEvent`/`JournalEntry` (Module 5).

---

## Dependency check — what Module 1 already provides

Confirmed by reading the actual code (not assumed):

| Need | Already exists | Where |
|---|---|---|
| Read the signed-in user's full profile (`quitStrategy`, `quitDate`, `reductionSchedule`, `baselineDailyUsage`, `costPerUnit`, `lastRelapseDate`) | ✅ | `lib/data/user_repository.dart` (`UserRepository.getUser`), `lib/data/firestore_user_repository.dart` |
| `NicotineUser` model with every field this module needs | ✅ | `lib/models/nicotine_user.dart` |
| `quitDate` + `reductionSchedule` already computed and persisted at onboarding | ✅ | `lib/domain/quit_date_calculator.dart`, called from `OnboardingController.submitQuitStrategy` |
| A landing point to replace | ✅ — `LoggedInScreen` (`lib/screens/auth/logged_in_screen.dart`) is an explicit placeholder ("Module 2 (Dashboard) is out of scope for Module 1") | |
| A dead-end after onboarding completes | ✅ — `OnboardingCompleteScreen` has no `onContinue`, terminal today | `lib/screens/onboarding/onboarding_complete_screen.dart` |
| Design tokens (`AppColors`, `AppTheme`) | ✅ | `lib/theme/app_theme.dart` |

**Nothing Module 2 needs from Module 1 is missing.** Module 1 is a clean dependency — no Module 1 changes required.

## Gap analysis — what's missing (all net-new)

Confirmed via search: zero dashboard/streak/money-saved/usage-log code exists anywhere in `lib/`. Everything below is new:

- `UsageLog` model + `UsageLogRepository` (interface + Fake + Firestore implementation)
- `DashboardStateCalculator` (pure function, mirrors `QuitDateCalculator`'s style) implementing `Get_Dashboard_State`
- `DashboardController` (ChangeNotifier) — loads user + usage logs, exposes calculated state, exposes a `logUsage()` action for Countdown-phase logging (§7.5)
- `DashboardScreen` + a `CountdownStateView` / `NicotineFreeStateView` pair
- Wiring: `OnboardingCompleteScreen` gets a "Continue" action into the Dashboard; `main.dart`'s `_Step.loggedIn` case renders `DashboardScreen` instead of the placeholder `LoggedInScreen`

## Two open decisions — need your call before implementation (not silently resolving these)

1. **`CravingsResisted` (part of `NicotineFreeState` display, §7.2).** Its data source is `CravingLog`, owned by **Module 3 (Habit & Trigger Tracking, FR5/FR6)**, which doesn't exist yet. Options:
   - (a) Build against a `CravingLogRepository` interface now (empty/Fake implementation returning 0), wire the real count in when Module 3 lands — matches how this codebase already abstracts repositories elsewhere.
   - (b) Omit the `CravingsResisted` stat from the Dashboard UI entirely for now, add it back when Module 3 exists.
   - I'd lean (a) — it's a two-line interface and means zero rework later — but this is your call.

2. **Health-Recovery-Timeline content** (also part of `NicotineFreeState`, e.g. "48 hours: blood oxygen normalizes"). The SDD cites this as coming from the SRDS but doesn't reproduce the actual milestone list, and it must be a fixed, pre-vetted source per the same no-free-form-medical-content constraint governing FR7/FR8 — I'm not going to invent this content myself. I attempted to pull it from `docs/SRDS_finale.pdf` directly but the PDF-rendering tool isn't available in this environment. Please either paste the milestone list from the SRDS (or wherever it's authoritative) or confirm a source, and I'll hard-code it as fixed content (same pattern as FR7's alternatives library).

Everything else below is unambiguous and ready to build as soon as you approve.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/usage_log.dart` | New `UsageLog` entity (SDD §6) |
| `lib/data/usage_log_repository.dart` | Abstract interface: `logUsage`, `getUsageLogs(userId)` |
| `lib/data/fake_usage_log_repository.dart` | In-memory test double |
| `lib/data/firestore_usage_log_repository.dart` | Real Firestore implementation |
| `lib/domain/dashboard_state_calculator.dart` | Pure function implementing §7.2's `Get_Dashboard_State` — no I/O, fully unit-testable |
| `lib/controllers/dashboard_controller.dart` | ChangeNotifier: loads `NicotineUser` + `UsageLog`s, exposes computed state + `logUsage()` |
| `lib/screens/dashboard/dashboard_screen.dart` | Top-level screen, picks Countdown vs. Nicotine-Free view based on controller state |
| `lib/screens/dashboard/widgets/countdown_state_view.dart` | Days-until-quit, (Gradual only) today's target/Reduction Streak/Money-Saved-so-far, usage-logging entry point |
| `lib/screens/dashboard/widgets/nicotine_free_state_view.dart` | Nicotine-free days, Money Saved, cravings resisted, health-recovery timeline |
| `lib/main.dart` | Modify: `_Step.loggedIn` renders `DashboardScreen` instead of `LoggedInScreen`; `OnboardingCompleteScreen` gets a continue action into it |
| `lib/screens/onboarding/onboarding_complete_screen.dart` | Modify: add `onContinue` callback + button (currently a dead-end) |

`LoggedInScreen` itself is left in place (still useful as visual reference / potentially reusable), just no longer routed to.

## Task Breakdown

### Task 1: `UsageLog` model + repository (interface, Fake, Firestore)
**Files:** Create `lib/models/usage_log.dart`, `lib/data/usage_log_repository.dart`, `lib/data/fake_usage_log_repository.dart`, `lib/data/firestore_usage_log_repository.dart`; Test: `test/data/fake_usage_log_repository_test.dart`
**Interfaces produced:** `UsageLog({logId, userId, date, actualUsage, targetUsage})`; `abstract class UsageLogRepository { Future<void> logUsage(UsageLog log); Future<List<UsageLog>> getUsageLogs(String userId); }`
Mirrors `UserRepository`/`FirestoreUserRepository`'s exact pattern (per-user Firestore subcollection, ISO date keys).

### Task 2: `DashboardStateCalculator` (pure domain logic, §7.2)
**Files:** Create `lib/domain/dashboard_state_calculator.dart`; Test: `test/domain/dashboard_state_calculator_test.dart`
**Consumes:** `NicotineUser`, `List<UsageLog>`, injectable `DateTime Function() now` (mirrors `QuitDateCalculator`'s testability pattern)
**Produces:** A sealed/union result type — `CountdownState` (with nullable Gradual-only fields: `todayTarget`, `reductionStreak`, `moneySavedSoFar`) or `NicotineFreeState` (`nicotineFreeDays`, `moneySaved`, plus placeholders for `cravingsResisted`/`healthRecoveryTimeline` pending the two open decisions above)
Test cases to cover: Cold Turkey → immediate Nicotine-Free; Date-Based Countdown (no reduction data); Gradual Countdown with a broken/unbroken Reduction Streak; Nicotine-Free after a relapse (`EffectiveStart` = `lastRelapseDate`, not `quitDate`) — this is the trickiest case and the one most likely to get silently wrong.

### Task 3: `DashboardController`
**Files:** Create `lib/controllers/dashboard_controller.dart`; Test: `test/controllers/dashboard_controller_test.dart`
**Consumes:** `UserRepository`, `UsageLogRepository`, `DashboardStateCalculator`
**Produces:** `loadDashboard(String userId)`, `logUsage(double actualUsage)` (Countdown-phase only, §7.5), exposes current computed state + loading/error status (mirrors `OnboardingController`'s status-enum pattern)

### Task 4: `DashboardScreen` + phase views
**Files:** Create `lib/screens/dashboard/dashboard_screen.dart`, `.../widgets/countdown_state_view.dart`, `.../widgets/nicotine_free_state_view.dart`; Test: `test/screens/dashboard_screen_test.dart`
Renders per `DashboardController`'s state; Countdown view includes the usage-logging entry point for Gradual strategy.

### Task 5: Wire into app flow
**Files:** Modify `lib/main.dart` (`_Step.loggedIn`), `lib/screens/onboarding/onboarding_complete_screen.dart` (add `onContinue`); Test: extend `test/app_flow_test.dart` to assert the full register→...→complete→dashboard path renders
No Module 1 screens/controllers change — only the routing switch and one new callback wire-up.

---

## Self-review

- **Spec coverage:** FR4 (Task 2 + 4), FR10 (Task 2, Reduction Streak branch), FR16 (Task 2, both formulas) — all covered. §7.5 `Log_Usage` covered by Task 3. §7.6 distinctness constraint enforced by keeping Reduction Streak/`NicotineFreeDays`/engagement-streak as separate fields, never merged, in Task 2's result type.
- **Placeholder scan:** the two flagged open items (`CravingsResisted`, health-recovery-timeline content) are explicit decision points for you, not implementation placeholders left in the plan — no task proceeds by guessing at them silently.
- **Type consistency:** `UsageLogRepository`/`UsageLog` names used consistently across Tasks 1–3; `DashboardController` method names (`loadDashboard`, `logUsage`) match what Task 4's screen will call.

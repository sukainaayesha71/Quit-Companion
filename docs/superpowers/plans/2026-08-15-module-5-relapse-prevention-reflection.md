# Module 5 — Relapse Prevention & Reflection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the "Let's Log This Moment" relapse-logging form (matching `docs/UI_Design/relapse 11.png`) and the "My Journal" list + entry screen (matching `docs/UI_Design/journal reflection 13.png`), and **wire the relapse flow into Module 4's already-built-but-unrouted `RestartPlanScreen`** — completing the exact dependency Module 4's plan flagged and deliberately left open: "built and tested now, ready for Module 5 to invoke later."

**Architecture:** This module's biggest architectural question — how `AI_Generate_Restart_Plan` is implemented — is **already resolved**, not open. Module 4's plan asked, and you confirmed: client-side Dart calculators, no backend. `RestartPlanCalculator` (`lib/domain/restart_plan_calculator.dart`) and `RestartPlanScreen` (`lib/screens/relapse/restart_plan_screen.dart`) already exist, fully tested. Module 5's job is almost entirely **collecting the relapse form's inputs and wiring them into what already exists** — CravingHistory comes from Module 3's `CravingLogRepository.getRecentLogs` (also already built for exactly this purpose), RelapseTrigger comes from the new form.

**Tech Stack:** Flutter/Dart only — `provider`, `cloud_firestore`. No backend/FastAPI work (confirmed by the Module 4 precedent this plan reuses). No new package.

## Global Constraints

- **FCM push notifications are explicitly out of scope.** SRDS UC9 step 9 ("System sends a motivational push notification within the next 24 hours") and SDD §7.4's matching line have no supporting infrastructure anywhere in this codebase — no `firebase_messaging` dependency, no notification permission handling, nothing. This plan does not add it. Same reasoning as Module 3/4 excluding Alternatives/Community links: don't half-build a cross-cutting module (Notification & Reminder, shared/Module 9) inside this one.
- **The SRDS's "AI detects high-risk behavior patterns → gentle check-in prompt" alternative flow is also out of scope** — no such detection logic is specified anywhere, and it would also need the same missing push infrastructure. Not built, not stubbed.
- **Relapse logging is phase-gated — this is an SDD requirement, not a design choice.** SDD §8 states explicitly: "Relapse Prevention & Reflection sequence (SRDS §5.3.5): now gated — only reachable in the Nicotine-Free phase per FR12; needs a precondition check added." FR12 itself: "A relapse event is only loggable... in the Nicotine-Free phase." This plan enforces it at both the UI layer (tile disabled during Countdown, matching the existing disabled-tile visual language already used for unbuilt features) and the controller layer (defense in depth, matching `DashboardController.logUsage`'s existing phase-guard pattern).
- **`NicotineFreeDays` reset behavior is already correct — no Module 2 change needed.** SDD §7.4: "`User.lastRelapseDate = Today` (was: RESET `User.NicotineFreeDays = 0` in SRDS)." `DashboardStateCalculator`'s `EffectiveStart = MAX(quitDate, lastRelapseDate)` (Module 2, already built) already reacts correctly the moment `lastRelapseDate` is updated — Module 5 only needs to call `NicotineUser.copyWith(lastRelapseDate: ...)` + `saveUser`, nothing else.
- **Modules 1-4 stay frozen**, with the same kind of narrow, additive exception every prior module has taken: `FirestoreUserRepository` gains no new fields this time (`lastRelapseDate` already exists, Module 1). `CravingLogRepository`/`RestartPlanCalculator`/`RestartPlanScreen` (Modules 3-4) are read from/reused, not modified. `DashboardStateCalculator`/`DashboardController` (Module 2) are not touched.
- **Firebase Phone Auth is not touched.** Unrelated to this module.
- **New Firestore rule needed**: `nicotineUsers/{userId}/journalEntries/{entryId}`, mirroring the `usageLogs`/`cravingLogs` pattern exactly (same reasoning: subcollection rules don't inherit the parent's).

---

## SDD Traceability

**Module ownership (SDD §2.1):** Module 5 = "Relapse Prevention & Reflection" (Sukaina), owning:
- **FR12** — journal entries and relapse logging, Nicotine-Free-phase only for the relapse-event effects.

**Core logic spec — SDD §7.4 `Log_Relapse`:**
```
FUNCTION Log_Relapse(User):
  // Only reachable in the Nicotine-Free phase (Today >= quitDate) — see FR12.
  // A pre-Quit-Day usage event is routed to Log_Usage() instead (§7.5), not here.
  INPUT RelapseTrigger, ProductUsed, Mood, Notes
  SAVE Relapse Event to Firebase
  User.lastRelapseDate = Today
  RESTART_PLAN = CALL AI_Generate_Restart_Plan(User.CravingHistory, RelapseTrigger)   // Module 4, already built
  DISPLAY RESTART_PLAN with compassionate message                                     // Module 4's RestartPlanScreen, already built
  SEND FCM Motivational Push Notification within 24 hours                             // out of scope, see Global Constraints
END FUNCTION
```

**SRDS UC9 (Use Case #9: Log Relapse & Get Restart Plan)** confirms the exact form fields: "date/time of relapse, type of product used, trigger category, emotional state, and notes" — matching the approved screenshot exactly.

**Approved UI references:**
- `docs/UI_Design/relapse 11.png` — "Let's Log This Moment": back arrow + title, cracked-cigarette illustration, "When did this happen?" date field, "What did you use?" dropdown, Trigger chips (**Stress, Social Pressure, Boredom, Other** — 4 of Module 3's 5 `TriggerCategory` values, notably omitting "After Meal"), Mood chips (**Guilty, Frustrated, Sad, Numb** — a completely different vocabulary from Module 3's craving-mood chips, only "Sad" overlaps), optional notes textarea, Submit button.
- `docs/UI_Design/journal reflection 13.png` — "My Journal": title + circular "+" add button, a decorative journal/tea illustration, a reverse-chronological list of entry cards (date badge + text preview), one shown with a small flag icon in the top-right corner — visually confirming `JournalEntry.relapseFlag` surfaces as a flag badge on relapse-tagged entries in this same list.
- **No approved UI reference exists for the "+" add-journal-entry screen.** All 14 numbered UI Design screenshots were inspected; none show a create/compose journal screen. Same situation as Module 4's "My Goal" — flagged, not invented around.

**Data model (SDD §6 / SRDS §5.2):** `JournalEntry(entryId, userId, entryText, entryDate, relapseFlag)` — this is the **only** entity the SDD/SRDS ever define for this module. There is **no separate `RelapseEvent` entity anywhere** in either document, despite §7.4's pseudocode and UC9 both describing relapse-specific structured inputs (`ProductUsed`, `RelapseTrigger`, `Mood`) that don't fit `JournalEntry`'s literal 5-field list. This is the same category of gap Module 3 hit with `CravingLog`'s `notes` field — see Open Decision 1.

---

## Dependency check — what Modules 1-4 already provide

| Need | Already exists | Where |
|---|---|---|
| `lastRelapseDate` field + phase-aware `EffectiveStart` logic | ✅ | `lib/models/nicotine_user.dart`, `lib/domain/dashboard_state_calculator.dart` |
| Current phase (Countdown vs. Nicotine-Free) exposed to the UI | ✅ | `DashboardController.state` (`CountdownState`/`NicotineFreeState`) |
| `CravingHistory` for the restart-plan call | ✅ | `CravingLogRepository.getRecentLogs(userId, since)` (built in Module 4 for exactly this) |
| `AI_Generate_Restart_Plan` | ✅, already built and tested | `lib/domain/restart_plan_calculator.dart` |
| Restart-plan result display | ✅, already built and tested, **not yet routed** | `lib/screens/relapse/restart_plan_screen.dart` |
| `TriggerCategory` enum (Stress/After Meal/Social Pressure/Boredom/Other) | ✅ — reusable for this form's Trigger chips (rendering only 4 of 5) | `lib/models/trigger_category.dart` |
| `ProductType` enum (Vape/Cigarettes/Pouches) | ✅ — reusable for this form's "What did you use?" dropdown | `lib/models/product_type.dart` |
| Two disabled Dashboard destination tiles ready to enable | ✅ — "Journal" (`Icons.menu_book_rounded`, index 5) and "Relapse Log" (`Icons.smoke_free_rounded`, index 6) | `lib/screens/dashboard/widgets/quick_access_grid.dart` |
| Precedent for phase-gated Dashboard functionality | ✅ | `CountdownStateView`'s Gradual-only usage-logging gate (Module 2) |
| Precedent for a "build ahead, wire later" screen | ✅ | `RestartPlanScreen` itself (Module 4) |
| Design tokens | ✅ | `lib/theme/app_theme.dart` |

**Nothing Module 5 needs from Modules 1-4 is missing.** This is the cleanest dependency chain of any module so far — Module 4 was built specifically anticipating this.

## Gap analysis — what's missing (all net-new)

- `RelapseMood` enum — new, since the relapse form's mood vocabulary (Guilty/Frustrated/Sad/Numb) shares only "Sad" with Module 3's `Mood` enum
- `JournalEntry` model — new, plus relapse-specific optional fields beyond the SDD's literal 5-field list (Open Decision 1)
- `JournalRepository` (interface + Fake + Firestore) — new, mirrors `CravingLogRepository`'s established pattern
- `RelapseController` — new (ChangeNotifier): collects form inputs, saves the entry, updates `lastRelapseDate`, calls `RestartPlanCalculator`
- `JournalController` — new (ChangeNotifier): loads/creates plain journal entries
- `RelapseLogScreen` — new, matches `docs/UI_Design/relapse 11.png`
- `JournalScreen` — new, matches `docs/UI_Design/journal reflection 13.png`
- `AddJournalEntryScreen` — new, no mockup (Open Decision 2)
- Wiring: enable "Journal" and "Relapse Log" Quick Access tiles; `RelapseLogScreen` → (on submit) → `RestartPlanScreen` (finally wiring Module 4's dependency)
- `firestore.rules` — new `journalEntries` subcollection block

---

## Three open decisions — need your call before implementation (not silently resolving these)

**1. Data model: extend `JournalEntry` with relapse-specific fields, or a separate entity?**
The SDD/SRDS define only `JournalEntry(entryId, userId, entryText, entryDate, relapseFlag)` — no `RelapseEvent` entity exists anywhere, yet §7.4/UC9 both require capturing `ProductUsed`, `RelapseTrigger`, `Mood` on a relapse log. My proposal: **extend `JournalEntry`** with `productUsed: ProductType?`, `triggerCategory: TriggerCategory?`, `mood: RelapseMood?` — all null for plain reflections, all populated when `relapseFlag == true`. This matches the approved UI directly: `journal reflection 13.png` shows relapse entries appearing **inside the same Journal list** (flagged with an icon), not in a separate view — meaning they're the same entity in the approved design, not two. Also mirrors the Module 3 precedent (extending `CravingLog` with `notes` beyond its class-diagram listing) rather than inventing a parallel entity the SDD never mentions. **Confirm this, or tell me you want a separate `RelapseEvent` entity instead** (which would also change how it shows up in the Journal list, since the reference shows one unified list).

**2. The "+" add-journal-entry screen has no approved mockup — what does it look like?**
Same situation as Module 4's "My Goal." My proposal: a plain form (date, defaulting to today; free-text `entryText`; Submit) reusing existing card/typography/input conventions from Modules 1-4 — not copying any other module's specific mockup, since none fits. **Confirm this is acceptable, or hold off on building this screen** (in which case "Journal" stays view-only this pass — you could still read entries, including relapse-flagged ones, just not compose a plain reflection from scratch yet).

**3. What text goes in `entryText` when a relapse is logged, if the optional Notes field was left blank?**
My proposal: **leave it null/empty, verbatim from the Notes field** — no auto-composed summary sentence (e.g., not "Relapse logged: Cigarettes, triggered by Stress"), since inventing summary prose isn't that different from inventing content, and the structured fields (`productUsed`/`triggerCategory`/`mood`) are already stored separately for the Journal list UI to render however it likes without needing fabricated text. **Confirm, or tell me you want a templated summary line** (and if so, roughly what it should say — I won't guess the wording).

Everything else below is unambiguous and ready to build as soon as you approve — including the phase-gating (SDD-mandated, not a judgment call) and the Trigger/Mood chip vocabularies (directly read off the approved screenshot).

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/relapse_mood.dart` | New enum: `guilty, frustrated, sad, numb` |
| `lib/models/journal_entry.dart` | New: `JournalEntry` (pending Open Decision 1's field shape) |
| `lib/data/journal_repository.dart` | New interface: `saveEntry(JournalEntry)`, `getEntries(userId)` |
| `lib/data/fake_journal_repository.dart` / `firestore_journal_repository.dart` | New Fake + real Firestore implementation, mirrors `CravingLogRepository`'s pattern |
| `lib/controllers/relapse_controller.dart` | New ChangeNotifier: submit relapse form → save entry → update `lastRelapseDate` → compute restart plan |
| `lib/controllers/journal_controller.dart` | New ChangeNotifier: load entries, create a plain entry |
| `lib/screens/relapse/relapse_log_screen.dart` | New: matches `docs/UI_Design/relapse 11.png` |
| `lib/screens/journal/journal_screen.dart` | New: matches `docs/UI_Design/journal reflection 13.png` |
| `lib/screens/journal/add_journal_entry_screen.dart` | New: no mockup (Open Decision 2) |
| `lib/screens/dashboard/widgets/quick_access_grid.dart` | **Modify:** enable "Journal" (always) and "Relapse Log" (Nicotine-Free phase only) tiles |
| `lib/screens/dashboard/dashboard_screen.dart` | **Modify:** pass phase info to `QuickAccessGrid`, wire navigation |
| `lib/main.dart` | **Modify:** provider wiring for `RelapseController`/`JournalController` |
| `firestore.rules` | **Modify:** add `journalEntries` subcollection rule |

## Task Breakdown

### Task 1: `RelapseMood` enum + `JournalEntry` model (pending Open Decision 1)
**Files:** Create `lib/models/relapse_mood.dart`, `lib/models/journal_entry.dart`

### Task 2: `JournalRepository` (interface, Fake, Firestore)
**Files:** Create `lib/data/journal_repository.dart`, `fake_journal_repository.dart`, `firestore_journal_repository.dart`; Test: `test/data/fake_journal_repository_test.dart`
Mirrors `CravingLogRepository`'s exact pattern (per-user Firestore subcollection).

### Task 3: `RelapseController`
**Files:** Create `lib/controllers/relapse_controller.dart`; Test: `test/controllers/relapse_controller_test.dart`
**Consumes:** `JournalRepository`, `UserRepository`, `CravingLogRepository`, `RestartPlanCalculator` (reused from Module 4, not modified)
**Produces:** `submitRelapse({userId, productUsed, triggerCategory, mood, notes})` → saves the flagged `JournalEntry`, updates `lastRelapseDate`, computes and exposes the `RestartPlan`. Guards against Countdown-phase calls (defense in depth per Global Constraints).

### Task 4: `JournalController`
**Files:** Create `lib/controllers/journal_controller.dart`; Test: `test/controllers/journal_controller_test.dart`
**Consumes:** `JournalRepository`
**Produces:** `loadEntries(userId)`, `addEntry({userId, entryText})` (plain reflection, `relapseFlag: false`).

### Task 5: `RelapseLogScreen`
**Files:** Create `lib/screens/relapse/relapse_log_screen.dart`; Test: `test/screens/relapse_log_screen_test.dart`
Matches `relapse 11.png` exactly. On successful submit, navigates to Module 4's `RestartPlanScreen` (same `pushReplacement` pattern Module 3 used for `HighRiskScreen`).

### Task 6: `JournalScreen` + `AddJournalEntryScreen`
**Files:** Create `lib/screens/journal/journal_screen.dart`, `add_journal_entry_screen.dart`; Test: `test/screens/journal_screen_test.dart`, `test/screens/add_journal_entry_screen_test.dart`
List matches `journal reflection 13.png` (date badges, text preview, flag icon on relapse entries). Add-entry screen per Open Decision 2.

### Task 7: Wire into Dashboard
**Files:** Modify `lib/screens/dashboard/widgets/quick_access_grid.dart` (enable both tiles, "Relapse Log" gated on phase), `lib/screens/dashboard/dashboard_screen.dart`, `lib/main.dart`; Test: extend `test/screens/dashboard_screen_test.dart`
No other Quick Access tile changes. No other Dashboard file changes.

### Task 8: Firestore rules
**Files:** Modify `firestore.rules` (add `journalEntries` subcollection block, mirroring `usageLogs`/`cravingLogs`); deploy

---

## Which Dashboard features become functional

- **"Journal" Quick Access tile** — always enabled (once onboarding is complete), navigating to `JournalScreen`.
- **"Relapse Log" Quick Access tile** — enabled only during the Nicotine-Free phase; dimmed/disabled during Countdown, matching the existing disabled-tile visual language. Navigates to `RelapseLogScreen`, which on submit hands off to Module 4's `RestartPlanScreen` — **finally completing Module 4's deliberately-left-open dependency.**
- All other Quick Access tiles (Alternatives, Health-Bot, Rewards, Community, Knowledge Hub) remain disabled — none are Module 5's FRs.

## Required tests summary

`fake_journal_repository_test.dart`, `relapse_controller_test.dart` (including the phase-guard), `journal_controller_test.dart`, `relapse_log_screen_test.dart` (including the RestartPlanScreen handoff), `journal_screen_test.dart`, `add_journal_entry_screen_test.dart`, extended `dashboard_screen_test.dart` (both tile navigations + phase-gating). No backend tests — no backend work this module.

## Self-review

- **Spec coverage:** FR12's relapse-logging half fully wired end-to-end, including the Module 4 handoff SDD §7.4 specifies. FR12's journal half covered by Tasks 4/6, scoped per Open Decision 2.
- **Placeholder scan:** all three open decisions are explicit confirmation points — no task proceeds by inventing a data schema, a UI with no reference, or fabricated entry text.
- **Boundary check:** FCM push and the "AI detects high-risk patterns" alternative flow traced to missing cross-cutting infrastructure (Module 9) and excluded rather than half-built, same standard applied to Community/Alternatives in Modules 3-4.
- **Reuse check:** `RestartPlanCalculator`, `RestartPlanScreen`, `CravingLogRepository.getRecentLogs`, `TriggerCategory`, `ProductType`, `DashboardStateCalculator`'s `EffectiveStart` logic — all Module 1-4 work — reused as-is, zero duplication.

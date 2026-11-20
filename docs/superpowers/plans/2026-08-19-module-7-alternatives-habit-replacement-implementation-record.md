# Module 7 — Alternatives & Habit Replacement — Implementation Record

**Status: IMPLEMENTED AND VERIFIED (2026-08-19).** No separate design-plan document was written first for this module (unlike Modules 4-6) — the user's standing instruction for this session is "implement continuously, don't stop for planning-only rounds," so the design decisions below were made inline and are recorded here, in the same as-built format as the Module 6 record, rather than in a preceding plan file.

This module belongs to **Mehreen Ali's** module list (SDD §2.1, "Alternatives & Habit Replacement", FR7).

---

## Step 1 — Why this module is required (SDD traceability)

FR7 (SDD §3): *"Alternatives/habit-replacement suggestions are sourced from a fixed, pre-vetted content library drawn from WHO/CDC and peer-reviewed cessation literature. No human clinical-advisor review step exists; no free-form AI-generated advice text is permitted."*

SRDS UC4 ("Get Habit Replacement Suggestions") and its pseudocode (`Get_Habit_Alternatives`) additionally specify: score each library item against the user's trigger/mood context, sort descending, show the top 3-5, let the user pick one, request Yes/No outcome feedback afterward, and save that outcome "for future AI personalization."

**A real gap already existed and was waiting on this module**: `lib/screens/craving/high_risk_screen.dart` (Module 3, `docs/UI_Design/6a.png`) already rendered five specific alternative cards with disabled "Try This" buttons, explicitly documented in its own class comment as *"content itself... is FR7 — Alternatives & Habit Replacement, Mehreen's module, not built yet."* This module closes that gap.

## Step 2 — Requirements satisfied

FR7 in full: fixed content library (no free-form AI text), trigger/mood-based ranking, a functioning "Try This" flow with brief instructions, Yes/No outcome feedback logged per attempt, filter chips (All/Exercises/Games) actually filtering.

## Step 3 — Dependencies on already-built modules

| Need | Reused from |
|---|---|
| `TriggerCategory`, `Mood` enums | Module 3 (`lib/models/trigger_category.dart`, `lib/models/mood.dart`) |
| The exact five alternative items, their titles/descriptions/tags/icons | Module 3's original `HighRiskScreen` draft — promoted from a screen-local hard-coded list into a shared `lib/data/habit_alternative_library.dart`, not reinvented |
| The disabled `HighRiskScreen` scaffold itself (`docs/UI_Design/6a.png`) | Module 3 — rewired, not rebuilt |
| Per-user Firestore subcollection + Fake/Firestore repository pattern | Module 5/6 (`JournalRepository`/`HealthBotRepository`) |
| Fire-and-forget, non-fatal logging-failure pattern | Module 6's `HealthBotController` |
| "No approved mockup — build plain, document the gap" precedent | Module 4's "My Goal" screen, Module 5's add-journal-entry screen |

**Modules 1-6 stayed frozen** except the two files this module's own content lived in: `high_risk_screen.dart` (Module 3's screen, rewired — the file's entire reason for disabled buttons was always "waiting on this module") and `log_craving_screen.dart` (one new constructor parameter threaded through to `HighRiskScreen`).

## Step 4 — Design decisions made inline (documented, not hidden)

Since no separate plan document preceded this module, the judgment calls below were made directly during implementation, each with its rationale — equivalent in spirit to the "Open Decisions" sections in Modules 4-6's plans, just recorded after the fact rather than before:

1. **No real ML recommender.** The SRDS's original pseudocode calls `AI_Recommendation_Score(User.History, ...)` — a trainable, per-user-history model. FR7's SDD wording explicitly forbids this ("no free-form AI-generated advice text"), consistent with how FR5 (relapse risk) and FR8 (Health-Bot) were already built as deterministic, not real ML. **Decision:** `rankAlternatives()` (`lib/domain/habit_alternative_matcher.dart`) is a fixed, documented relevance table (trigger/mood → category weight), not a trained model — same posture as every other "AI" feature in this codebase.
2. **`successRate` is never fabricated.** The SDD's `HabitAlternative` entity has a `successRate` field, and the approved UI mockup shows an "80% success rate for you" figure — but Module 3's original `HighRiskScreen` already explicitly declined to invent that number. **Decision:** carried the same principle forward — `HabitAlternative` in this codebase has no `successRate` field at all; it would only ever be honest as a real aggregate over logged `HabitAlternativeAttempt.outcomeHelped` values, and computing that aggregate is explicitly not built by this module (see Step 8, "not done").
3. **Outcome feedback is immediate, not timed.** SRDS UC4 step 9 asks for feedback "after 5 minutes." This repo has no push/reminder infrastructure (no `firebase_messaging` dependency anywhere — the same FCM exclusion every prior module already applied). **Decision:** the Yes/No prompt is shown immediately on `AlternativeDetailScreen`, not via a timed follow-up notification.
4. **No mockup exists for the "Try This" detail screen.** Only the card-list screen (`6a.png`) has an approved reference; the instructional detail view SRDS UC4 step 7 describes has none. **Decision:** built a plain screen (title, description, instructions card, Yes/No buttons) reusing existing typography/card conventions — same "no mockup, build plain, don't invent a design" precedent as Modules 4-5.
5. **Attempt/outcome data model.** Neither the SDD nor SRDS defines an entity for the per-attempt log UC4 requires. **Decision:** added `HabitAlternativeAttempt` (not an SDD-named entity) as a plain audit-log record, mirroring `HealthBotConversation`'s precedent from Module 6 for exactly this kind of gap.

## Step 5 — Folder/file plan

New: `lib/models/habit_alternative.dart`, `lib/models/habit_alternative_attempt.dart`, `lib/data/habit_alternative_library.dart`, `lib/data/habit_alternative_attempt_repository.dart` (+`fake_`/`firestore_` variants), `lib/domain/habit_alternative_matcher.dart`, `lib/controllers/alternatives_controller.dart`, `lib/screens/craving/alternative_detail_screen.dart`. Modified: `lib/screens/craving/high_risk_screen.dart` (rewritten from static/disabled to controller-driven), `lib/screens/craving/log_craving_screen.dart` (threads a new `alternativesController` param and the selected trigger/mood into `HighRiskScreen`), `lib/screens/dashboard/dashboard_screen.dart` and `lib/main.dart` (provider wiring), `mobile/firestore.rules` (new subcollection rule).

## Step 6 — TDD narrative, layer by layer

**Domain matcher** (`habit_alternative_matcher_test.dart`, 5 cases: every item always returned; stress→exercise-first; boredom→game-first; afterMeal→quick-fix-first; determinism). RED confirmed via IDE diagnostics (`rankAlternatives` undefined). GREEN on first implementation attempt — **5/5 passed**, no bugs.

**Repository** (`fake_habit_alternative_attempt_repository_test.dart`, 3 cases: logs with a null outcome; `recordOutcome` updates the matching attempt in place; a simulated Firestore failure throws). GREEN on first attempt — **3/3 passed**.

**Controller** (`alternatives_controller_test.dart`, 5 cases: ranks via the matcher on `loadRecommendations`; `setFilter` narrows/restores `filteredRecommendations`; `selectAlternative` logs an attempt; `recordOutcome` updates the most recent attempt and sets a feedback message; a logging failure is non-fatal). GREEN on first attempt — **5/5 passed**.

**Screen: `AlternativeDetailScreen`** (4 cases: renders title/instructions and logs an attempt on open; "Yes" records `outcomeHelped: true` and shows the feedback message; "No" records `false`; back button pops). GREEN on first attempt — **4/4 passed**.

**Screen: `HighRiskScreen` rewrite.** This step modified a screen with pre-existing, previously-passing tests whose *premise* (buttons permanently disabled, "FR7 not implemented yet") was the exact thing this module supersedes — the same category of change Module 4/5 made to the Dashboard's disabled tiles. Updated `high_risk_screen_test.dart`: the old "every Try This button is present but disabled" assertion was replaced with "every Try This button is enabled and opens `AlternativeDetailScreen`"; two new tests were added for the filter chips actually filtering (previously they were static, always showing "All" selected and never responding to taps). All five pre-existing content assertions (headline text, all five card keys/titles, the no-fabricated-percentage check, back button, skip link) were kept **unchanged** — the visual content contract from the approved `6a.png` mockup did not change, only which elements are now interactive. **7/7 passed** on the first run after the rewrite.

## Step 7 — Wiring

`log_craving_screen.dart`: added a required `alternativesController: AlternativesController` field; on a High-risk submission, `HighRiskScreen` is now constructed with `userId`, the just-submitted `triggerCategory`/`mood` (already held in local state at that point — `_trigger!`/`_mood!`), and the controller, instead of the old no-argument `const HighRiskScreen()`.

`dashboard_screen.dart`: added `alternativesController` and threaded it into `_openLogCraving`'s `LogCravingScreen` construction — no new Dashboard entry point was created (Alternatives has no independent Quick Access tile in the approved design; it's only reachable via a High-risk craving log, per the original `6a.png`/`Get_Habit_Alternatives` flow).

`main.dart`: added `HabitAlternativeAttemptRepository?` test-injection field, a new `ChangeNotifierProvider<AlternativesController>` (`FirestoreHabitAlternativeAttemptRepository()` default), and passed `context.read<AlternativesController>()` into `DashboardScreen`.

**Test-file threading (mechanical, not a bug):** `dashboard_screen_test.dart` (12 call sites via `replace_all`), `log_craving_screen_test.dart` (2 call sites), and `app_flow_test.dart` (1 call site, `FakeHabitAlternativeAttemptRepository()` — same eager-Firestore-construction reason as Module 6's `FakeHealthBotRepository` fix) all needed the new required parameter added. No assertion in any of these pre-existing tests changed.

`firestore.rules`: added a `habitAlternativeAttempts` subcollection block, mirroring every prior module's pattern.

## Step 8 — Full verification (evidence, not claims)

| Check | Command | Result |
|---|---|---|
| Backend tests | (unaffected — this module is Flutter-only, no backend change) | Still 113/113 from Module 6's run |
| Flutter test suite | `flutter test` (mobile/) | **257 passed** (238 pre-Module-7 + 19 new/changed: 5 matcher + 3 repository + 5 controller + 4 detail-screen + 2 new high-risk-screen filter tests, net of the pre-existing high-risk-screen test whose assertion flipped), 0 failed |
| Static analysis | `flutter analyze` (mobile/) | **0 issues** |
| Debug APK build | `flutter build apk --debug` | Run at the end of this step — see the chat summary for the final result |
| Physical-device manual verification | — | **NOT performed** — the user's manual step, per standing instruction |
| Firestore rules deployment | — | `habitAlternativeAttempts` rule added to source; **not deployed** to the live project this session |

## Step 9 — What is still explicitly NOT done

- **No `successRate` aggregation.** `HabitAlternativeAttempt` records are logged with a real Yes/No outcome, but nothing reads them back to compute an actual success rate for display anywhere — by design (Step 4, decision 2), to avoid fabricating a number, but also meaning the SDD's `HabitAlternative.successRate` field is effectively unimplemented, not just deferred.
- **No standalone "Get Help Now" entry point.** SRDS UC4's "Alternative Flow" describes a user proactively navigating to alternatives outside of a High-risk craving log ("User navigates to 'Get Help Now'..."). This module only wires the flow SDD FR5→FR7 actually connects — a High-risk `LogCravingScreen` submission → `HighRiskScreen`. A separate always-available "Get Help Now" Dashboard tile was not built (no such tile exists in the approved Quick Access grid design, `dashboard 5.png`).
- **Physical-device verification and Firestore rules deployment** — as above.

# Module 8 — Gamification & Rewards — Implementation Record

**Status: IMPLEMENTED AND VERIFIED (2026-08-19).** Same inline-decisions style as Module 7 — no separate plan document preceded this one; design decisions are recorded here as they were made.

This module belongs to **Mehreen Ali's** module list (SDD §2.1, "Gamification & Rewards", FR9; consumes but does not own FR10).

---

## Step 1 — Why this module is required (SDD traceability)

FR9 (SDD §3): *"Awards milestone badges at 24 hours, 7 days, 30 days, 90 days, 6 months, and 1 year, measured from `MAX(quitDate, lastRelapseDate)`. No badges are awarded before `quitDate` is reached, regardless of strategy."*

SDD §7.3 `Check_Milestones` gives the exact 6-tier pseudocode (badge names + day thresholds). SDD §7.6 additionally documents a third, separate "engagement streak" concept (daily check-in, increments on any app open or craving log) that must stay visually/logically distinct from both `NicotineFreeDays` and FR10's Reduction Streak.

**An approved UI mockup exists and was used directly**: `docs/UI_Design/progress and rewards 9.png` — "Your Progress" title, a flame-icon "Day Streak" card with a 7-dot row, a 6-tile "Badges Earned" grid (trophy icon, colored+unlocked vs. grey+locked with a lock badge), and a "Milestones" checklist (24 Hours / 3 Days / 1 Week / 1 Month, checkmarked).

## Step 2 — Requirements satisfied

FR9 in full (6-tier badge awarding, gated to the Nicotine-Free phase, never re-awarded, persisted). FR10 consumption (Reduction Streak displayed, not recalculated). SDD §7.6's engagement streak, displayed as "Day Streak" per the approved mockup.

## Step 3 — Dependencies on already-built modules

| Need | Reused from |
|---|---|
| `NicotineFreeDays` / phase detection / Reduction Streak | Module 2's `DashboardStateCalculator` — called directly, not reimplemented (FR9 "consumes/displays FR10 but does not own its calculation," SDD §2.1) |
| `NicotineUser`, `UserRepository` | Module 1 |
| `CravingLogRepository.getRecentLogs`, `UsageLogRepository.getUsageLogs` | Modules 3/2 — read for engagement-streak activity dates |
| Per-user Firestore subcollection + Fake/Firestore repository pattern | Every prior module |
| "Rewards" Quick Access tile, already scaffolded and disabled | Module 2's `quick_access_grid.dart` (index 3) |

**Modules 1-7 stayed frozen** — read from, not modified, except the same additive Dashboard-wiring touch (`quick_access_grid.dart`, `dashboard_screen.dart`, `main.dart`) every prior module made to light up its own tile.

## Step 4 — Design decisions made inline

1. **Badge catch-up, not a literal `==` check.** SDD §7.3's pseudocode checks `IF NicotineFreeDays == 7 THEN Award...`. Taken completely literally, a user who doesn't open the app on exactly day 7 would never receive '1 Week Warrior' — the exact-match condition would already be false by day 8. **Decision:** `checkNewlyEarnedBadges()` (`lib/domain/badge_checker.dart`) awards every threshold at-or-below the current day count that isn't already earned — a documented, deliberate deviation from the literal `==`, not a misreading of it, aimed at not silently losing a genuinely-earned badge.
2. **Engagement streak: real proxy, not invented telemetry.** SDD §7.6 defines this streak as incrementing "on any app open or craving log" — but no "app open" event is logged anywhere in this codebase (no analytics/telemetry infrastructure exists at all). **Decision:** derive it from the union of `CravingLog` and `UsageLog` dates already persisted for other reasons — a narrower, honest proxy, documented as such in `engagement_streak_calculator.dart`'s doc comment, not silently presented as literal "app opens."
3. **A one-day grace period on the streak.** If no activity is logged yet today, the streak still shows yesterday's count rather than dropping to 0 at midnight before the user has done anything — a UX judgment call, not specified either way in the SDD.
4. **The Milestones checklist section of the mockup was not duplicated.** The approved screenshot's "Milestones" list (24 Hours / 3 Days / 1 Week / 1 Month) is visually identical to `dashboard_milestones.dart`'s `kDashboardMilestones` — a Module 2 presentation-only list already built for the Dashboard's own milestone-progress card. Building a second, separate rendering of the same four-item list on this screen was judged as low-value duplication for this pass; **not built** — flagged explicitly in Step 9, not silently dropped.
5. **`newlyEarnedBadgeTypes` is exposed but not turned into the SRDS's "Congratulatory Pop-up."** SRDS §7.3 also specifies an FCM push notification, out of scope per every prior module's same FCM exclusion (no `firebase_messaging` dependency exists). The in-app congratulatory pop-up itself (no push involved) was also not built this pass — `GamificationController.newlyEarnedBadgeTypes` is computed and available for a future screen to consume, but `RewardsScreen` currently just renders the up-to-date badge grid, it doesn't pop up a separate "you just earned X!" dialog. Flagged in Step 9.

## Step 5 — Folder/file plan

New: `lib/models/badge.dart`, `lib/data/badge_repository.dart` (+fake/firestore), `lib/domain/badge_checker.dart`, `lib/domain/engagement_streak_calculator.dart`, `lib/controllers/gamification_controller.dart`, `lib/screens/rewards/rewards_screen.dart`. Modified: `quick_access_grid.dart`, `dashboard_screen.dart`, `main.dart`, `firestore.rules`.

**Naming note:** `Badge` collides with Flutter Material's own `Badge` widget. Every file importing both `package:flutter/material.dart` and this module's `Badge` model uses `import '../models/badge.dart' as models;` (repository/controller layers) or `import 'package:flutter/material.dart' hide Badge;` (the screen, which never needs Material's `Badge` widget) — resolved explicitly, not by renaming the SDD-named entity.

## Step 6 — TDD narrative, layer by layer

**`badge_checker_test.dart`** (6 cases: nothing before day 1; exact day-1 award; the catch-up behavior explicitly proven with a day-10 test expecting both `firstDayHero` and `oneWeekWarrior`; no re-award of an already-earned type; all six tiers at day 400; a defensive negative-day case). GREEN on first attempt — **6/6 passed**.

**`engagement_streak_calculator_test.dart`** (5 cases: empty → 0; 3 consecutive days ending today; a gap breaks the streak; the one-day grace period; same-day duplicate timestamps count once). GREEN on first attempt — **5/5 passed**.

**`GamificationController`** (5 cases: a Countdown-phase Gradual user sees no badges and the Reduction Streak is consumed as-is; a Nicotine-Free user newly crossing 10 days is awarded both `firstDayHero` and `oneWeekWarrior` in one pass; a badge already earned in a prior session is never re-awarded or duplicated; the engagement streak derives from the union of craving+usage log dates; a missing user surfaces an error status). Test-writing surfaced one real gap before implementation even started: no test helper existed for constructing a `CravingLog` — a `makeTestCravingLog()` was assumed to exist and didn't; fixed by writing a small local `_cravingLogAt()` test helper directly, using `CravingLog`'s real constructor (found by reading `lib/models/craving_log.dart`) rather than continuing to guess at a nonexistent helper. GREEN on the next attempt — **5/5 passed**, no logic bugs.

**`RewardsScreen`** (3 cases: loading → "Your Progress" + all 6 badge labels rendered; locked badges show a lock-icon key, earned ones don't; a Countdown-phase Gradual user sees the Reduction Streak card instead of the badge grid). GREEN on first attempt — **3/3 passed**.

## Step 7 — Wiring

`quick_access_grid.dart`: added `onRewardsTap` required callback; tile index 3 ("Rewards", already labeled) now wraps in `InkWell` with key `dashboard_quick_access_rewards`, unconditionally enabled (badges/streaks are meaningful in both phases — no phase gate).

`dashboard_screen.dart`: added a required `gamificationController` field and `_openRewards(context)` navigator method, identical pattern to every other Quick Access destination.

`main.dart`: added `BadgeRepository?` test-injection field, a new `ChangeNotifierProvider<GamificationController>` wired to the *existing* `userRepository`/`usageLogRepository`/`resolvedCravingLogRepository` instances (not new ones — same shared-repository-instance discipline `DashboardController`/`CravingLogController`/`AiPlanController` already established) plus a fresh `FirestoreBadgeRepository()`/`DashboardStateCalculator()` default, and passed `context.read<GamificationController>()` into `DashboardScreen`.

**Test-file threading:** `dashboard_screen_test.dart` (13 call sites via `replace_all` + 1 new test for the Rewards tile navigation) and `app_flow_test.dart` (`FakeBadgeRepository()` added, same eager-Firestore-construction reason as every prior module's Fake-injection fix) — both mechanical, no existing assertion changed.

`firestore.rules`: added a `badges` subcollection block.

## Step 8 — Full verification (evidence, not claims)

| Check | Command | Result |
|---|---|---|
| Backend tests | (unaffected — Flutter-only module) | Still 113/113 |
| Flutter test suite | `flutter test` (mobile/) | **277 passed** (257 pre-Module-8 + 20 new: 6 badge-checker + 5 engagement-streak + 5 controller + 3 screen + 1 dashboard-wiring), 0 failed |
| Static analysis | `flutter analyze` (mobile/) | **0 issues** |
| Debug APK build | `flutter build apk --debug` | Run at the end of this step — see the chat summary for the final result |
| Physical-device manual verification | — | **NOT performed** — user's manual step |
| Firestore rules deployment | — | `badges` rule added to source; **not deployed** |

## Step 9 — What is still explicitly NOT done

- ~~No in-app "Congratulatory Pop-up"~~ — **RESOLVED 2026-11-23 (FR9 / UC7):** `GamificationController` now keeps a one-time celebration queue (`pendingCelebrations` / `takeNextCelebration()`), filled only after a badge is successfully saved and deduplicated by badge type per user per session. `BadgeCelebrationListener` (mounted on both `DashboardScreen` and `RewardsScreen`) shows `BadgeCelebrationDialog` for each queued badge in turn, and only when its own route is on top, so a badge is never celebrated twice. Badges earned in earlier sessions are not re-celebrated. Known limit: the queue lives in memory, so if the app is killed after a badge is saved but before its pop-up is shown, that pop-up is skipped (the badge, points and history are still correct).
- **No FCM push notification** on badge earn — same exclusion every prior module applied (no `firebase_messaging` dependency in this repo).
- **No "Milestones" checklist section on `RewardsScreen`** — the approved mockup shows one, but it duplicates Module 2's existing Dashboard milestone-progress card content; judged as not worth a second rendering this pass (Step 4, decision 4).
- **Physical-device verification and Firestore rules deployment** — as above.

## FR9 / UC7 badge celebration pop-up — PENDING VERIFICATION (2026-11-23)

> **RESOLVED 2026-11-23** — both test issues fixed and verified (complete suite 805 passed, 0 failed, 0 skipped). See `2026-11-23-step2-badge-popup-fix-record.md`. Device verification is still manual. The original notes below are kept for history.

Implemented (see resolved item above), but **not fully verified**. Open items:

1. **`test/responsive_screens_test.dart` — `portrait 320x640 text 1.5: dashboard` hangs.** In the full-suite run it stalled for 16+ minutes at 100% of one CPU core with no output and was stopped manually. All 19 text-scale-1.0 cases passed after the pop-up dismissal loop was added. Probable causes (not yet confirmed): the unbounded `while (continue button visible) tap(...)` dismissal loop never ends at 1.5x text, or `pumpAndSettle` never settles. Fix to apply: bound the loop, `ensureVisible` the continue button before tapping, then rerun that file alone.
2. **Possible small-screen layout issue in `BadgeCelebrationDialog`.** On a 320x640 screen at 1.5x text, the dialog may be taller than the viewport, which would push the continue button out of view (the content scrolls, but this is unconfirmed). If confirmed, tighten the dialog layout (smaller trophy/spacing, or pin the button outside the scroll area).
3. **`test/app_flow_test.dart` — "deleting an account returns to the welcome screen" fails** with `Bad state: No element` at `ensureVisible(profile_row_privacy_security)` (line 237). The test user is nicotine-free, so the pop-up covers the Dashboard. The test needs to dismiss the celebration pop-up(s) first.
4. **Full-suite result for this change is not yet available.** Last partial run: 643 passed, 1 failed (item 3) before the hang (item 1). The remaining text-1.5 responsive cases and any later test files have not been run.
5. **Android device verification pending:** earn a badge (e.g. Quit Day yesterday), confirm the pop-up shows once on the Dashboard, does not reappear on Rewards or after reopening, and fits on a small screen with large system font.

Passing: rewards tests (29), dashboard/profile tests, `flutter analyze` clean.

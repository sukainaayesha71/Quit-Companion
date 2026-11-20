# Dashboard Redesign — Design

Date: 2026-09-01
Reference: `docs/UI_Design/dashboard 5.png` (approved reference art)
Scope: `mobile/lib/screens/dashboard/` and its widgets, plus additive changes to
`DashboardController` / `DashboardStateCalculator` / `CravingLogRepository` usage.

## Context

The Dashboard already implements most of the reference's structure (header,
streak/hero card with milestone timeline, money-saved/cravings-resisted stats
row, 3x3 Quick Access grid, milestone-progress card, bottom nav). What's
missing, per the reference image and user request:

1. No illustrated sunrise/countryside background — flat cream `Scaffold`.
2. The "This Week" card is a deliberate empty state — a prior change avoided
   fabricating a chart because no daily data series was wired up. Real data
   (`CravingLogRepository.getRecentLogs`) makes an honest chart possible.
3. No entrance animations.
4. Small deltas: no red dot on the notification bell, no "log completed"
   checkmark badge on the Log Craving tile, milestone-progress card is
   positioned above Quick Access instead of near the bottom as in the
   reference.

Not in scope: `CountdownState` (pre-quit) visual redesign — the reference
image depicts the `NicotineFreeState` view only. The shared chrome (header,
background, Quick Access, bottom nav) applies to both states since they're
already shared in `DashboardScreen`; `CountdownStateView`'s own content is
untouched.

## A. Background & card shell

Two new static image assets, produced once via a Python/PIL script (not
shipped, run during implementation) that crops the top sky band (sun, clouds,
birds) and bottom hills band (trees, path, flowers) directly out of
`dashboard 5.png`, preserving their proportions/reveal relative to the full
image height. Saved as:

- `mobile/assets/images/dashboard_bg_top.png`
- `mobile/assets/images/dashboard_bg_bottom.png`

Registered in `pubspec.yaml` next to the existing hero assets
(`welcome_hero_full.png`, `register_hero.png`), following the same
"reference art, only what's not needed erased/cropped" convention already
used on those screens.

`DashboardScreen.build` wraps its `Scaffold` body in a `Stack`:
- Bottom layer: the two band images, pinned full-width to the top and bottom
  of the screen (`Positioned(top: 0, ...)` / `Positioned(bottom: 0, ...)`),
  wrapped in `IgnorePointer` — static images, no repaint cost, no interaction.
- Top layer: the existing `SafeArea` + `SingleChildScrollView` content,
  rendered inside a rounded cream card (`AppColors.background`/`surface`,
  large `BorderRadius`) with enough top/bottom margin that the band images
  peek through exactly as in the reference. The bottom nav bar sits as part
  of the same card, matching the reference (no visible gap between content
  card and nav bar).

This keeps runtime cost to two decoded PNGs — no custom painting, no
per-frame gradient computation.

## B. Header

Add a small red dot (`Container`, 8x8, `AppColors.terracotta` or `error`,
positioned top-right of the bell icon via `Stack`) to `DashboardHeader`. Purely
presentational — no "has unread notifications" state exists yet, so it's
always shown, matching the reference's static bell-with-dot.

## C/D. Streak card, milestone timeline, stats row

No structural changes — already match the reference's layout, colors, and
copy. Left as-is.

## E. Quick Access grid — Log Craving badge

`QuickAccessGrid` gains an optional `loggedCravingToday: bool` parameter. When
true, the "Log Craving" tile renders a small green checkmark badge
(`Positioned` circle, top-right corner of the tile), matching the reference.

Data: `DashboardController` gains a `todaysCravingLogged` bool, computed via
`CravingLogRepository.countLoggedSince(userId, todayMidnight) > 0` — reusing
an existing repository method, computed alongside the existing
`countCravingsResistedSince` call in `loadDashboard`. Additive: no existing
field or method signature changes.

## F. "This Week" chart

`WeeklyProgressCard` replaces its empty state with:
- A smooth area/line chart via a single `CustomPainter` (no new chart package
  dependency, matching this project's existing "no extra deps unless needed"
  pattern) showing 7 daily points, green gradient fill under the line, small
  dot markers, styled after the reference's curve.
- A badge next to the "This Week" heading: `"N% better than last week"` in
  terracotta/positive styling when this week's craving-log count is lower
  than last week's; `"N% more than last week"` in muted/neutral styling when
  it's higher or equal; the badge is omitted entirely when
  `pctBetterThanLastWeek` is null (no prior-week data to compare against).

Data flow (additive, same pattern as existing `NicotineFreeState` fields):
- `DashboardController.loadDashboard` calls
  `CravingLogRepository.getRecentLogs(userId, fourteenDaysAgo)` once.
- A new pure helper (alongside `DashboardStateCalculator`, or a method on it)
  buckets those logs into this-week's 7 daily counts and last-week's 7 daily
  counts, from which it derives `weeklyTrend: List<int>` (7 values, oldest
  first) and `pctBetterThanLastWeek: double?` (null if last week has zero
  logs to compare against, avoiding a divide-by-zero/infinite percentage).
- `NicotineFreeState` gains `weeklyTrend` and `pctBetterThanLastWeek` fields.
  "Better" = fewer total craving logs this week vs last week (fewer logged
  urges reads as improvement, consistent with every log already representing
  a resisted craving — more resisted-but-never-relapsed events isn't on its
  own better or worse, but fewer urges firing at all is).

Error handling: if `getRecentLogs` throws, it surfaces through the same
try/catch already in `loadDashboard` (existing `DashboardStatus.error` path)
— no new error handling needed.

## G. Milestone progress card

Reordered in `NicotineFreeStateView`/`DashboardScreen` to appear after the
"This Week" chart, matching the reference's bottom-of-scroll placement. Add a
small sparkle icon decoration next to the trophy icon (`Stack` with a small
`Icons.auto_awesome` glyph offset top-right of the trophy circle).

`HealthRecoveryCard` (existing functionality, not part of the reference) stays
in the scroll, placed after the milestone-progress card so it doesn't disrupt
the reference's visual flow for the primary content.

## H. Bottom nav

No changes — already matches (raised terracotta Health-Bot FAB, active-tab
styling).

## I. Entrance animations

A single `AnimationController` (600-800ms) on `DashboardScreen`, driving a
staggered fade + slight upward slide on each major card (`Interval`-based
`CurvedAnimation` per card, offset start times) on first successful load.
Runs once per screen mount, not on every `setState` from controller updates
(guarded so re-renders from `loadUsage`/reminder sync don't re-trigger it).
Purely presentational; widget tests can `pumpAndSettle()` past it or tests
can pump a fixed duration if `pumpAndSettle` doesn't terminate due to a
repeating animation (it won't — this is a one-shot forward animation).

## Staged rollout

- **Stage 1**: full visual layout — background assets + shell, reordered
  cards, chart *shape* rendering off the existing/static data path already
  used elsewhere in the screen, badges, animations. No controller/calculator
  changes yet. User confirms visual match against the reference.
- **Stage 2**: wire `weeklyTrend`, `pctBetterThanLastWeek`, and
  `todaysCravingLogged` into `DashboardController`/`DashboardStateCalculator`/
  repository calls, replacing the Stage 1 placeholder values.

## Testing

- Extend `dashboard_state_calculator_test.dart` with cases for the weekly
  bucketing/percentage helper (even split, all-zero last week, more logs this
  week vs fewer).
- Extend `dashboard_controller_test.dart` for `todaysCravingLogged` and the
  new `NicotineFreeState` fields being populated from `loadDashboard`.
- Extend `dashboard_screen_test.dart` for the checkmark badge visibility and
  chart rendering with sample data.
- No test coverage needed for the background images themselves (static
  assets) beyond confirming the screen still builds/golden-tests (if any)
  aren't newly flaky from the animation — pump past it explicitly in tests.

# Step 3 — FR4 / UC6 Dashboard improvements: implementation record (2026-11-23)

## Scope

1. High-risk banner on the Dashboard, leading to Habit Alternatives.
2. First-craving empty state when the user has no craving records.
3. 7-day / 30-day toggle on the Dashboard progress chart.

## Existing pieces checked first (to avoid duplicates)

- `HighRiskScreen` (Module 7) was reachable only from a high-risk craving log (`LogCravingScreen` redirect) and the neutral Alternatives Quick Access tile. The Dashboard had no risk banner.
- The Dashboard "This Week" card showed a 7-day chart only. Track has a *calendar-month* summary list (`MonthlyProgressCard`) but no rolling 30-day chart, so the toggle is not a duplicate.
- No empty state existed: a user with no cravings saw a flat all-zero line, which reads like a perfect record rather than "no data yet".

## Design

- **Data (reused, no new Firestore collections or queries):** `DashboardController.loadDashboard` already called `getRecentLogs`; its window widened from 14 to 60 days, so one call now feeds both chart ranges (30 days plus the 30 compared against) and the banner. In production `OfflineCravingLogRepository` already fetches the full history and filters locally, so there are no extra network reads.
- **`WeeklyTrendCalculator.calculateRange(logs, days:)`:** a generic N-day bucketing method. The existing `calculate()` now delegates to it with `days: 7` (same output; still used by Track via `weeklyTrend`).
- **New controller fields:** `monthlyTrend` (30), `pctBetterThanLastMonth`, `hasAnyCravingLogs` (defaults true so the prompt never flashes before data loads; uses `countLoggedSince(userId, 1970)` only when the 60-day window is empty), `recentHighRiskLog`. All are reset in `clearSession()`.
- **Banner rule:** shown when the user's *newest* craving log is `RelapseRiskLevel.high`, logged within the last 24 h, and not `riskAssessmentPending`. A later lower-risk log clears it. The action opens `HighRiskScreen` with that log's real trigger and mood (personalized, like the post-log redirect), not the neutral pair used by the Quick Access tile.
- **Toggle:** the range is a view choice kept in `WeeklyProgressCard` state (ChoiceChips "7 days" / "30 days"). The title switches between "This Week" and "Last 30 Days", and the comparison badge between "...than last week" and "...than previous 30 days". The badge is omitted when there is nothing to compare. The chart painter now accepts any length; above 7 points only today's dot is drawn.
- **Empty state:** when `hasAnyCravingLogs` is false, the chart and toggle are replaced by a "Log your first craving" prompt with a button to `LogCravingScreen`.
- **Reload after Log Craving:** `_openLogCraving` reloads the dashboard on return (same pattern as Journal and Relapse Log). *Correction (2026-11-23, Step 8):* this record originally said no repository implements `LiveCravingLogRepository`. That was wrong: production's `OfflineCravingLogRepository` does, so the Dashboard already refreshed on a new craving. The extra reload is harmless (one redundant load) and still helps test/fake repositories that aren't live.

## Files

- `mobile/lib/features/tracking/domain/weekly_trend_calculator.dart` — `calculateRange`.
- `mobile/lib/features/dashboard/controllers/dashboard_controller.dart` — new fields, 60-day fetch, banner rule.
- `mobile/lib/features/dashboard/presentation/screens/widgets/high_risk_banner.dart` — new.
- `mobile/lib/features/dashboard/presentation/screens/widgets/weekly_progress_card.dart` — toggle and empty state (backwards-compatible constructor).
- `mobile/lib/features/dashboard/presentation/screens/widgets/weekly_trend_chart_painter.dart` — any length.
- `mobile/lib/features/dashboard/presentation/screens/dashboard_screen.dart` — banner placement, wiring, reload after Log Craving.
- Tests: `weekly_trend_calculator_test.dart` (+4), `dashboard_controller_test.dart` (+8), `widgets/weekly_progress_card_test.dart` (new, 5, including a 320 px / 1.5x text layout check), `dashboard_screen_test.dart` (+4).

## Verification

- `flutter analyze`: no issues.
- `test/features/dashboard` + `test/features/tracking`: 107 passed (86 existing + 21 new).
- Full-suite result: see the session report. Step 2's known pending items (Module 8 record, "PENDING VERIFICATION") are unrelated to this step and remain open.

## Manual Android verification still required

- New account with no cravings: the Dashboard shows the "Log your first craving" prompt; logging one replaces it with the chart on return.
- Log a craving that scores high risk, skip the alternatives, and go back to the Dashboard: the banner shows; "Try an alternative" opens alternatives ranked for that craving's trigger/mood. Then log a lower-risk craving: the banner disappears.
- Toggle 7/30 days on a small phone with a large system font.

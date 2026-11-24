import 'package:quit_companion/features/craving/models/craving_log.dart';

/// Buckets craving logs into a 7-day trend for the Dashboard's "This Week"
/// chart, plus a week-over-week comparison. Pure — no I/O; DashboardController
/// fetches the logs and passes them in, mirroring DashboardStateCalculator's
/// style. Not tied to NicotineFreeState: craving-log activity (and therefore
/// the chart) is meaningful in the Countdown phase too.
class WeeklyTrendCalculator {
  final DateTime Function() now;

  WeeklyTrendCalculator({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// [recentLogs] should cover at least the last 14 days; anything older is
  /// ignored. Returns 7 daily counts (oldest first, ending today) for
  /// [weeklyTrend], and the percentage change in total craving-log count vs.
  /// the prior 7 days for [pctBetterThanLastWeek] — positive means fewer
  /// logs this week (improvement), negative means more. Null when the prior
  /// week has zero logs, since there's nothing honest to compare against.
  ({List<int> weeklyTrend, double? pctBetterThanLastWeek}) calculate(
    List<CravingLog> recentLogs,
  ) {
    final result = calculateRange(recentLogs, days: 7);
    return (
      weeklyTrend: result.trend,
      pctBetterThanLastWeek: result.pctBetterThanPreviousPeriod,
    );
  }

  /// FR4/UC6 7-day / 30-day Dashboard toggle: the same bucketing as
  /// [calculate], generalized to any [days]-long window. Returns [days]
  /// daily counts (oldest first, ending today) and the percentage change
  /// vs. the [days] immediately before it — null when that earlier window
  /// has no logs. [recentLogs] should cover at least the last `2 * days`
  /// days; anything older is ignored.
  ({List<int> trend, double? pctBetterThanPreviousPeriod}) calculateRange(
    List<CravingLog> recentLogs, {
    required int days,
  }) {
    assert(days > 0);
    final today = _dateOnly(now());
    final counts = <DateTime, int>{};
    for (final log in recentLogs) {
      final day = _dateOnly(log.timestamp);
      counts[day] = (counts[day] ?? 0) + 1;
    }

    final trend = <int>[
      for (var i = days - 1; i >= 0; i--)
        counts[today.subtract(Duration(days: i))] ?? 0,
    ];
    final currentTotal = trend.fold<int>(0, (sum, v) => sum + v);

    var previousTotal = 0;
    for (var i = days; i < days * 2; i++) {
      previousTotal += counts[today.subtract(Duration(days: i))] ?? 0;
    }

    final pct = previousTotal == 0
        ? null
        : ((previousTotal - currentTotal) / previousTotal) * 100;

    return (trend: trend, pctBetterThanPreviousPeriod: pct);
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

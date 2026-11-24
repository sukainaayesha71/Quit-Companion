import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/domain/weekly_trend_calculator.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

CravingLog _logAt(DateTime timestamp, {String id = 'log'}) {
  return CravingLog(
    logId: id,
    userId: 'u1',
    cravingIntensity: 5,
    mood: Mood.stressed,
    triggerCategory: TriggerCategory.stress,
    locationContext: 'Home',
    activity: 'Watching TV',
    timestamp: timestamp,
    relapseRiskScore: RelapseRiskLevel.low,
  );
}

void main() {
  // "Today" for every test: 2026-08-13. The 7-day window is Aug 7-13
  // inclusive; the prior week is Jul 31-Aug 6 inclusive.
  final today = DateTime(2026, 8, 13);

  WeeklyTrendCalculator buildCalculator() =>
      WeeklyTrendCalculator(now: () => today);

  test('buckets this-week logs into 7 daily counts, oldest first', () {
    final logs = [
      _logAt(DateTime(2026, 8, 7, 9)),
      _logAt(DateTime(2026, 8, 7, 20)),
      _logAt(DateTime(2026, 8, 9, 12)),
      _logAt(DateTime(2026, 8, 13, 8)),
    ];

    final result = buildCalculator().calculate(logs);

    expect(result.weeklyTrend, [2, 0, 1, 0, 0, 0, 1]);
  });

  test('returns null pctBetterThanLastWeek when last week has zero logs', () {
    final logs = [_logAt(DateTime(2026, 8, 10))];

    final result = buildCalculator().calculate(logs);

    expect(result.pctBetterThanLastWeek, isNull);
  });

  test('positive pct when this week logged fewer cravings than last week', () {
    final logs = [
      // last week (Jul 31 - Aug 6): 4 logs
      _logAt(DateTime(2026, 8, 1), id: 'a'),
      _logAt(DateTime(2026, 8, 2), id: 'b'),
      _logAt(DateTime(2026, 8, 3), id: 'c'),
      _logAt(DateTime(2026, 8, 4), id: 'd'),
      // this week: 2 logs
      _logAt(DateTime(2026, 8, 8), id: 'e'),
      _logAt(DateTime(2026, 8, 9), id: 'f'),
    ];

    final result = buildCalculator().calculate(logs);

    // (4 - 2) / 4 * 100 = 50
    expect(result.pctBetterThanLastWeek, 50);
  });

  test('negative pct when this week logged more cravings than last week', () {
    final logs = [
      _logAt(DateTime(2026, 8, 1), id: 'a'),
      _logAt(DateTime(2026, 8, 8), id: 'b'),
      _logAt(DateTime(2026, 8, 9), id: 'c'),
      _logAt(DateTime(2026, 8, 10), id: 'd'),
    ];

    final result = buildCalculator().calculate(logs);

    // (1 - 3) / 1 * 100 = -200
    expect(result.pctBetterThanLastWeek, -200);
  });

  test('logs older than 14 days are ignored', () {
    final logs = [_logAt(DateTime(2026, 7, 1))];

    final result = buildCalculator().calculate(logs);

    expect(result.weeklyTrend, [0, 0, 0, 0, 0, 0, 0]);
    expect(result.pctBetterThanLastWeek, isNull);
  });

  group('FR4/UC6 calculateRange', () {
    test('30-day range returns 30 daily counts ending today, oldest first', () {
      final result = buildCalculator().calculateRange([
        _logAt(DateTime(2026, 7, 15, 9), id: 'first-day'), // 29 days ago
        _logAt(DateTime(2026, 8, 13, 9), id: 'today'),
        _logAt(DateTime(2026, 8, 13, 18), id: 'today2'),
        _logAt(DateTime(2026, 7, 14, 9), id: 'previous-window'),
      ], days: 30);

      expect(result.trend, hasLength(30));
      expect(result.trend.first, 1);
      expect(result.trend.last, 2);
      expect(result.trend.fold<int>(0, (a, b) => a + b), 3);
    });

    test('compares against the 30 days immediately before', () {
      final result = buildCalculator().calculateRange([
        _logAt(DateTime(2026, 8, 1), id: 'a'),
        _logAt(DateTime(2026, 7, 10), id: 'b'), // previous window
        _logAt(DateTime(2026, 7, 1), id: 'c'), // previous window
        _logAt(DateTime(2026, 6, 1), id: 'too-old'), // ignored
      ], days: 30);

      expect(result.pctBetterThanPreviousPeriod, 50);
    });

    test('no logs in the previous window gives a null comparison', () {
      final result = buildCalculator().calculateRange([
        _logAt(DateTime(2026, 8, 12)),
      ], days: 30);

      expect(result.pctBetterThanPreviousPeriod, isNull);
    });

    test('a 7-day range matches calculate()', () {
      final logs = [
        _logAt(DateTime(2026, 8, 13), id: 'a'),
        _logAt(DateTime(2026, 8, 6), id: 'b'),
        _logAt(DateTime(2026, 8, 5), id: 'c'),
      ];
      final range = buildCalculator().calculateRange(logs, days: 7);
      final week = buildCalculator().calculate(logs);

      expect(range.trend, week.weeklyTrend);
      expect(range.pctBetterThanPreviousPeriod, week.pctBetterThanLastWeek);
    });
  });
}

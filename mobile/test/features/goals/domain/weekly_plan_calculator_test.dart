import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/goals/domain/weekly_plan_calculator.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';

void main() {
  final fixedToday = DateTime(2026, 8, 15);

  WeeklyPlanCalculator buildCalculator() =>
      WeeklyPlanCalculator(now: () => fixedToday);

  UsageLog usageLog(
    DateTime date, {
    required double actual,
    required double target,
  }) {
    return UsageLog(
      logId: date.toIso8601String(),
      userId: 'u1',
      date: date,
      actualUsage: actual,
      targetUsage: target,
    );
  }

  CravingLog cravingLog(DateTime timestamp, {required RelapseRiskLevel risk}) {
    return CravingLog(
      logId: timestamp.toIso8601String(),
      userId: 'u1',
      cravingIntensity: 5,
      mood: Mood.stressed,
      triggerCategory: TriggerCategory.stress,
      locationContext: 'Home',
      activity: 'Home',
      timestamp: timestamp,
      relapseRiskScore: risk,
    );
  }

  test(
    'GRADUAL Countdown user with repeated over-target days gets a get-back-on-track goal',
    () {
      final user = const NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.gradual,
      ).copyWith(quitDate: DateTime(2026, 8, 25));
      final usageLogs = [
        usageLog(DateTime(2026, 8, 13), actual: 8, target: 5),
        usageLog(DateTime(2026, 8, 14), actual: 7, target: 4),
      ];

      final plan = buildCalculator().generate(
        user: user,
        usageLogs: usageLogs,
        cravingLogs: const [],
      );

      expect(plan.goals, contains(contains('get back under')));
      expect(plan.generatedAt, fixedToday);
    },
  );

  test(
    'GRADUAL Countdown user consistently under target gets a consistency goal',
    () {
      final user = const NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.gradual,
      ).copyWith(quitDate: DateTime(2026, 8, 25));
      final usageLogs = [usageLog(DateTime(2026, 8, 14), actual: 2, target: 5)];

      final plan = buildCalculator().generate(
        user: user,
        usageLogs: usageLogs,
        cravingLogs: const [],
      );

      expect(plan.goals, contains(contains('consistency')));
    },
  );

  test(
    'Repeated High-risk cravings in the last 7 days get a breathing-technique goal',
    () {
      final user = const NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.dateBased,
      ).copyWith(quitDate: DateTime(2026, 8, 25));
      final cravingLogs = [
        cravingLog(DateTime(2026, 8, 13), risk: RelapseRiskLevel.high),
        cravingLog(DateTime(2026, 8, 14), risk: RelapseRiskLevel.high),
      ];

      final plan = buildCalculator().generate(
        user: user,
        usageLogs: const [],
        cravingLogs: cravingLogs,
      );

      expect(plan.goals, contains(contains('breathing')));
    },
  );

  test('weekly actions reflect the most common recent craving trigger', () {
    final user = const NicotineUser(
      userId: 'u1',
      email: 'a@b.com',
      quitStrategy: QuitStrategy.dateBased,
    ).copyWith(quitDate: DateTime(2026, 8, 25));
    final cravingLogs = [
      cravingLog(DateTime(2026, 8, 13), risk: RelapseRiskLevel.low),
      cravingLog(DateTime(2026, 8, 14), risk: RelapseRiskLevel.low),
    ];

    final plan = buildCalculator().generate(
      user: user,
      usageLogs: const [],
      cravingLogs: cravingLogs,
    );

    expect(plan.goals, contains(contains('Stress was a common trigger')));
  });

  test(
    'a craving log older than 7 days is excluded from this week\'s analysis',
    () {
      final user = const NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.dateBased,
      ).copyWith(quitDate: DateTime(2026, 8, 25));
      final cravingLogs = [
        cravingLog(DateTime(2026, 8, 1), risk: RelapseRiskLevel.high),
        cravingLog(DateTime(2026, 8, 2), risk: RelapseRiskLevel.high),
      ];

      final plan = buildCalculator().generate(
        user: user,
        usageLogs: const [],
        cravingLogs: cravingLogs,
      );

      expect(plan.goals, isNot(contains(contains('breathing'))));
    },
  );

  test(
    'Nicotine-Free user recently relapsed gets a getting-back-on-track goal',
    () {
      final user =
          const NicotineUser(
            userId: 'u1',
            email: 'a@b.com',
            quitStrategy: QuitStrategy.coldTurkey,
          ).copyWith(
            quitDate: DateTime(2026, 8, 1),
            lastRelapseDate: DateTime(2026, 8, 13),
          );

      final plan = buildCalculator().generate(
        user: user,
        usageLogs: const [],
        cravingLogs: const [],
      );

      expect(plan.goals, contains(contains('setback')));
    },
  );

  test(
    'Nicotine-Free user with no recent relapse gets a keep-the-streak-going goal',
    () {
      final user = const NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
      ).copyWith(quitDate: DateTime(2026, 8, 1));

      final plan = buildCalculator().generate(
        user: user,
        usageLogs: const [],
        cravingLogs: const [],
      );

      expect(plan.goals, contains(contains('streak')));
    },
  );

  test(
    'DATE_BASED Countdown user with zero logged activity gets the fallback encouragement-to-log goal',
    () {
      final user = const NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.dateBased,
      ).copyWith(quitDate: DateTime(2026, 8, 25));

      final plan = buildCalculator().generate(
        user: user,
        usageLogs: const [],
        cravingLogs: const [],
      );

      expect(plan.goals, hasLength(1));
      expect(plan.goals.single, contains('Log your usage and cravings'));
    },
  );

  test(
    'throws if quitDate is not yet set (mirrors DashboardStateCalculator\'s FR3 precondition)',
    () {
      const user = NicotineUser(userId: 'u1', email: 'a@b.com');

      expect(
        () => buildCalculator().generate(
          user: user,
          usageLogs: const [],
          cravingLogs: const [],
        ),
        throwsStateError,
      );
    },
  );
}

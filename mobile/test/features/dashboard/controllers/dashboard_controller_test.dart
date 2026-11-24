import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  final fixedToday = DateTime(2026, 8, 13);

  DashboardController buildController({
    required FakeUserRepository userRepository,
    FakeUsageLogRepository? usageLogRepository,
  }) {
    return DashboardController(
      userRepository,
      usageLogRepository ?? FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
  }

  CravingLog logAt(DateTime timestamp, {String id = 'log'}) {
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

  test(
    'loadDashboard computes weeklyTrend and pctBetterThanLastWeek from real craving logs',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final cravingLogRepository = FakeCravingLogRepository();
      // fixedToday = Aug 13, 2026. This week is Aug 7-13 (1 log, on the 13th).
      // Last week is Jul 31-Aug 6 (2 logs, both on the 6th).
      await cravingLogRepository.logCraving(
        logAt(DateTime(2026, 8, 13, 9), id: 'a'),
      );
      await cravingLogRepository.logCraving(
        logAt(DateTime(2026, 8, 6, 9), id: 'b'),
      );
      await cravingLogRepository.logCraving(
        logAt(DateTime(2026, 8, 6, 20), id: 'c'),
      );
      final controller = DashboardController(
        userRepository,
        FakeUsageLogRepository(),
        cravingLogRepository,
        DashboardStateCalculator(now: () => fixedToday),
        now: () => fixedToday,
      );

      await controller.loadDashboard('u1');

      expect(controller.weeklyTrend, [0, 0, 0, 0, 0, 0, 1]);
      // (lastWeekTotal=2 - thisWeekTotal=1) / lastWeekTotal=2 * 100 = 50
      expect(controller.pctBetterThanLastWeek, 50);
    },
  );

  test(
    'loadDashboard sets todaysCravingLogged true when a craving was logged today',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final cravingLogRepository = FakeCravingLogRepository();
      await cravingLogRepository.logCraving(logAt(DateTime(2026, 8, 13, 9)));
      final controller = DashboardController(
        userRepository,
        FakeUsageLogRepository(),
        cravingLogRepository,
        DashboardStateCalculator(now: () => fixedToday),
        now: () => fixedToday,
      );

      await controller.loadDashboard('u1');

      expect(controller.todaysCravingLogged, isTrue);
    },
  );

  test(
    'loadDashboard sets todaysCravingLogged false when nothing was logged today',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await controller.loadDashboard('u1');

      expect(controller.todaysCravingLogged, isFalse);
    },
  );

  test('loadDashboard loads a Countdown state for a GRADUAL user', () async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.gradual,
        quitDate: DateTime(2026, 8, 20),
        baselineDailyUsage: 10,
        costPerUnit: 2,
        reductionSchedule: {DateTime(2026, 8, 13): 6},
      ),
    );
    final controller = buildController(userRepository: userRepository);

    await controller.loadDashboard('u1');

    expect(controller.status, DashboardStatus.loaded);
    expect(controller.state, isA<CountdownState>());
  });

  test(
    'loadDashboard loads a Nicotine-Free state and passes cravingsResisted through',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await controller.loadDashboard('u1');

      expect(controller.status, DashboardStatus.loaded);
      final state = controller.state as NicotineFreeState;
      expect(
        state.cravingsResisted,
        0,
      ); // FakeCravingLogRepository always returns 0
      expect(state.healthRecoveryTimeline, hasLength(5));
      expect(
        state.healthRecoveryTimeline.last.timeframe,
        'Product-specific recovery',
      );
    },
  );

  test(
    'loadDashboard sets an error state when the user does not exist',
    () async {
      final controller = buildController(userRepository: FakeUserRepository());

      await controller.loadDashboard('missing-user');

      expect(controller.status, DashboardStatus.error);
      expect(controller.errorMessage, isNotNull);
      expect(controller.state, isNull);
    },
  );

  test(
    'loadDashboard sets an error state when onboarding is incomplete (no quitDate)',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        const NicotineUser(userId: 'u1', email: 'a@b.com'),
      );
      final controller = buildController(userRepository: userRepository);

      await controller.loadDashboard('u1');

      expect(controller.status, DashboardStatus.error);
    },
  );

  test(
    'loadDashboard keeps the loaded user (for the header greeting) even with no quitDate yet',
    () async {
      // Regression test: this previously discarded the whole user object
      // whenever quitDate was missing, so the Dashboard header fell back to
      // a generic "Hi there" greeting instead of the user's real name for
      // any account without a completed quit plan (e.g. every phone/OTP
      // sign-up, which currently never runs onboarding at all).
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        const NicotineUser(userId: 'u1', email: 'a@b.com', name: 'Aisha'),
      );
      final controller = buildController(userRepository: userRepository);

      await controller.loadDashboard('u1');

      expect(controller.status, DashboardStatus.error);
      expect(controller.user?.name, 'Aisha');
    },
  );

  test(
    'logUsage during Countdown persists a log and refreshes the Reduction Streak',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.gradual,
          quitDate: DateTime(2026, 8, 20),
          baselineDailyUsage: 10,
          costPerUnit: 2,
          reductionSchedule: {DateTime(2026, 8, 13): 6},
        ),
      );
      final usageLogRepository = FakeUsageLogRepository();
      final controller = buildController(
        userRepository: userRepository,
        usageLogRepository: usageLogRepository,
      );
      await controller.loadDashboard('u1');

      final success = await controller.logUsage(5);

      expect(success, isTrue);
      final logs = await usageLogRepository.getUsageLogs('u1');
      expect(logs, hasLength(1));
      expect(logs.first.actualUsage, 5);
      expect(logs.first.targetUsage, 6);
      final state = controller.state as CountdownState;
      expect(state.reductionStreak, 1);
    },
  );

  test(
    'logUsage is rejected once the user is in the Nicotine-Free phase',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final usageLogRepository = FakeUsageLogRepository();
      final controller = buildController(
        userRepository: userRepository,
        usageLogRepository: usageLogRepository,
      );
      await controller.loadDashboard('u1');

      final success = await controller.logUsage(5);

      expect(success, isFalse);
      expect(await usageLogRepository.getUsageLogs('u1'), isEmpty);
    },
  );

  test('logUsage before loadDashboard is called is rejected', () async {
    final controller = buildController(userRepository: FakeUserRepository());

    final success = await controller.logUsage(5);

    expect(success, isFalse);
  });

  group('FR4/UC6 dashboard improvements', () {
    Future<(DashboardController, FakeCravingLogRepository)> setUp() async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final cravingLogRepository = FakeCravingLogRepository();
      final controller = DashboardController(
        userRepository,
        FakeUsageLogRepository(),
        cravingLogRepository,
        DashboardStateCalculator(now: () => fixedToday),
        now: () => fixedToday,
      );
      return (controller, cravingLogRepository);
    }

    CravingLog riskLog(
      DateTime timestamp,
      RelapseRiskLevel risk, {
      String id = 'risk',
      bool pending = false,
    }) {
      return CravingLog(
        logId: id,
        userId: 'u1',
        cravingIntensity: 9,
        mood: Mood.social,
        triggerCategory: TriggerCategory.socialPressure,
        locationContext: 'Party',
        activity: 'Socialising',
        timestamp: timestamp,
        relapseRiskScore: risk,
        riskAssessmentPending: pending,
      );
    }

    test('computes a 30-day trend and comparison from the same logs', () async {
      final (controller, logs) = await setUp();
      // fixedToday = Aug 13. Last 30 days: Jul 15-Aug 13; previous: Jun 15-Jul 14.
      await logs.logCraving(logAt(DateTime(2026, 8, 13, 9), id: 'a'));
      await logs.logCraving(logAt(DateTime(2026, 7, 20, 9), id: 'b'));
      await logs.logCraving(logAt(DateTime(2026, 7, 1, 9), id: 'c'));
      await logs.logCraving(logAt(DateTime(2026, 6, 20, 9), id: 'd'));
      await logs.logCraving(logAt(DateTime(2026, 6, 16, 9), id: 'e'));
      await logs.logCraving(logAt(DateTime(2026, 6, 15, 9), id: 'f'));

      await controller.loadDashboard('u1');

      expect(controller.monthlyTrend, hasLength(30));
      expect(controller.monthlyTrend.last, 1);
      expect(controller.monthlyTrend.fold<int>(0, (a, b) => a + b), 2);
      // (4 previous - 2 current) / 4 = 50% better.
      expect(controller.pctBetterThanLastMonth, 50);
      // The 7-day series is unchanged by the wider fetch.
      expect(controller.weeklyTrend, [0, 0, 0, 0, 0, 0, 1]);
    });

    test(
      'hasAnyCravingLogs is false for a user who has never logged a craving',
      () async {
        final (controller, _) = await setUp();

        await controller.loadDashboard('u1');

        expect(controller.hasAnyCravingLogs, isFalse);
        expect(controller.recentHighRiskLog, isNull);
      },
    );

    test(
      'hasAnyCravingLogs stays true when the only logs are older than the chart window',
      () async {
        final (controller, logs) = await setUp();
        await logs.logCraving(logAt(DateTime(2026, 1, 1), id: 'old'));

        await controller.loadDashboard('u1');

        expect(controller.hasAnyCravingLogs, isTrue);
        expect(controller.monthlyTrend.every((v) => v == 0), isTrue);
      },
    );

    test(
      'recentHighRiskLog is the latest log when it was high risk within 24h',
      () async {
        final (controller, logs) = await setUp();
        await logs.logCraving(
          riskLog(DateTime(2026, 8, 12, 9), RelapseRiskLevel.low, id: 'older'),
        );
        await logs.logCraving(
          riskLog(DateTime(2026, 8, 12, 21), RelapseRiskLevel.high, id: 'hi'),
        );

        await controller.loadDashboard('u1');

        expect(controller.recentHighRiskLog?.logId, 'hi');
      },
    );

    test('a later lower-risk log clears the banner', () async {
      final (controller, logs) = await setUp();
      await logs.logCraving(
        riskLog(DateTime(2026, 8, 12, 9), RelapseRiskLevel.high, id: 'hi'),
      );
      await logs.logCraving(
        riskLog(DateTime(2026, 8, 12, 21), RelapseRiskLevel.medium, id: 'm'),
      );

      await controller.loadDashboard('u1');

      expect(controller.recentHighRiskLog, isNull);
    });

    test(
      'a high-risk log older than 24 hours does not raise the banner',
      () async {
        final (controller, logs) = await setUp();
        await logs.logCraving(
          riskLog(DateTime(2026, 8, 11, 20), RelapseRiskLevel.high),
        );

        await controller.loadDashboard('u1');

        expect(controller.recentHighRiskLog, isNull);
      },
    );

    test('a still-pending risk assessment does not raise the banner', () async {
      final (controller, logs) = await setUp();
      await logs.logCraving(
        riskLog(
          DateTime(2026, 8, 12, 21),
          RelapseRiskLevel.high,
          pending: true,
        ),
      );

      await controller.loadDashboard('u1');

      expect(controller.recentHighRiskLog, isNull);
    });

    test('clearSession resets the Step 3 dashboard data', () async {
      final (controller, logs) = await setUp();
      await logs.logCraving(
        riskLog(DateTime(2026, 8, 12, 21), RelapseRiskLevel.high),
      );
      await controller.loadDashboard('u1');
      expect(controller.recentHighRiskLog, isNotNull);

      controller.clearSession();

      expect(controller.recentHighRiskLog, isNull);
      expect(controller.monthlyTrend, List.filled(30, 0));
      expect(controller.pctBetterThanLastMonth, isNull);
      expect(controller.hasAnyCravingLogs, isTrue);
    });
  });
}

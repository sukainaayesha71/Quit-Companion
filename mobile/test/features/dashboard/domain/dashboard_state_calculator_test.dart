import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';

void main() {
  DashboardStateCalculator buildCalculator(DateTime today) {
    return DashboardStateCalculator(now: () => today);
  }

  test(
    'COLD_TURKEY is immediately Nicotine-Free on day one (quitDate == today)',
    () {
      final today = DateTime(2026, 8, 13);
      final calculator = buildCalculator(today);
      final user = NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 13),
        baselineDailyUsage: 10,
        costPerUnit: 2,
      );

      final state = calculator.calculate(
        user: user,
        usageLogs: const [],
        cravingsResisted: 0,
      );

      expect(state, isA<NicotineFreeState>());
      final nf = state as NicotineFreeState;
      expect(nf.nicotineFreeDays, 0);
      expect(nf.moneySaved, 0);
    },
  );

  test('DATE_BASED Countdown shows only daysUntilQuit, no reduction data', () {
    final today = DateTime(2026, 8, 13);
    final calculator = buildCalculator(today);
    final user = NicotineUser(
      userId: 'u1',
      email: 'a@b.com',
      quitStrategy: QuitStrategy.dateBased,
      quitDate: DateTime(2026, 8, 20),
      baselineDailyUsage: 10,
      costPerUnit: 2,
    );

    final state = calculator.calculate(
      user: user,
      usageLogs: const [],
      cravingsResisted: 0,
    );

    expect(state, isA<CountdownState>());
    final countdown = state as CountdownState;
    expect(countdown.daysUntilQuit, 7);
    expect(countdown.plannedQuitDate, DateTime(2026, 8, 20));
    expect(countdown.healthRecoveryTimeline, hasLength(5));
    expect(countdown.todayTarget, isNull);
    expect(countdown.reductionStreak, isNull);
    expect(countdown.moneySavedSoFar, isNull);
  });

  test('GRADUAL Countdown with an unbroken streak counts every logged day', () {
    final today = DateTime(2026, 8, 13);
    final calculator = buildCalculator(today);
    final user = NicotineUser(
      userId: 'u1',
      email: 'a@b.com',
      quitStrategy: QuitStrategy.gradual,
      quitDate: DateTime(2026, 8, 20),
      baselineDailyUsage: 10,
      costPerUnit: 2,
      reductionSchedule: {DateTime(2026, 8, 13): 6},
    );
    final usageLogs = [
      UsageLog(
        logId: '1',
        userId: 'u1',
        date: DateTime(2026, 8, 11),
        actualUsage: 7,
        targetUsage: 8,
      ),
      UsageLog(
        logId: '2',
        userId: 'u1',
        date: DateTime(2026, 8, 12),
        actualUsage: 6,
        targetUsage: 7,
      ),
      UsageLog(
        logId: '3',
        userId: 'u1',
        date: DateTime(2026, 8, 13),
        actualUsage: 5,
        targetUsage: 6,
      ),
    ];

    final state = calculator.calculate(
      user: user,
      usageLogs: usageLogs,
      cravingsResisted: 0,
    );

    final countdown = state as CountdownState;
    expect(countdown.todayTarget, 6);
    expect(countdown.reductionStreak, 3);
    // (10-7)*2 + (10-6)*2 + (10-5)*2 = 6+8+10 = 24
    expect(countdown.moneySavedSoFar, 24);
  });

  test(
    'GRADUAL Countdown streak breaks at the first over-target day counting backward',
    () {
      final today = DateTime(2026, 8, 13);
      final calculator = buildCalculator(today);
      final user = NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.gradual,
        quitDate: DateTime(2026, 8, 20),
        baselineDailyUsage: 10,
        costPerUnit: 2,
        reductionSchedule: {DateTime(2026, 8, 13): 6},
      );
      final usageLogs = [
        UsageLog(
          logId: '1',
          userId: 'u1',
          date: DateTime(2026, 8, 11),
          actualUsage: 9,
          targetUsage: 8,
        ), // over target
        UsageLog(
          logId: '2',
          userId: 'u1',
          date: DateTime(2026, 8, 12),
          actualUsage: 6,
          targetUsage: 7,
        ),
        UsageLog(
          logId: '3',
          userId: 'u1',
          date: DateTime(2026, 8, 13),
          actualUsage: 5,
          targetUsage: 6,
        ),
      ];

      final state = calculator.calculate(
        user: user,
        usageLogs: usageLogs,
        cravingsResisted: 0,
      );

      final countdown = state as CountdownState;
      expect(countdown.reductionStreak, 2); // only the 12th and 13th
    },
  );

  test('GRADUAL Countdown streak breaks on a missing (ungapped) day', () {
    final today = DateTime(2026, 8, 13);
    final calculator = buildCalculator(today);
    final user = NicotineUser(
      userId: 'u1',
      email: 'a@b.com',
      quitStrategy: QuitStrategy.gradual,
      quitDate: DateTime(2026, 8, 20),
      baselineDailyUsage: 10,
      costPerUnit: 2,
      reductionSchedule: {DateTime(2026, 8, 13): 6},
    );
    final usageLogs = [
      // no log for the 11th — gap
      UsageLog(
        logId: '2',
        userId: 'u1',
        date: DateTime(2026, 8, 12),
        actualUsage: 6,
        targetUsage: 7,
      ),
      UsageLog(
        logId: '3',
        userId: 'u1',
        date: DateTime(2026, 8, 13),
        actualUsage: 5,
        targetUsage: 6,
      ),
    ];

    final state = calculator.calculate(
      user: user,
      usageLogs: usageLogs,
      cravingsResisted: 0,
    );

    final countdown = state as CountdownState;
    expect(
      countdown.reductionStreak,
      2,
    ); // 12th and 13th only; nothing before the gap counts
  });

  test(
    'Nicotine-Free after a relapse anchors to lastRelapseDate, not quitDate',
    () {
      final today = DateTime(2026, 9, 1);
      final calculator = buildCalculator(today);
      final user = NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
        lastRelapseDate: DateTime(2026, 8, 20),
        baselineDailyUsage: 10,
        costPerUnit: 2,
      );

      final state = calculator.calculate(
        user: user,
        usageLogs: const [],
        cravingsResisted: 3,
      );

      final nf = state as NicotineFreeState;
      expect(nf.nicotineFreeDays, 12); // Sept 1 - Aug 20, not Aug 1
      expect(nf.moneySaved, 12 * 10 * 2);
      expect(nf.cravingsResisted, 3);
    },
  );

  test(
    'cigarette recovery timeline includes only sourced cigarette milestones',
    () {
      final today = DateTime(2026, 8, 13);
      final calculator = buildCalculator(today);
      final user = NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        productType: ProductType.cigarettes,
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 13),
        baselineDailyUsage: 10,
        costPerUnit: 2,
      );

      final state = calculator.calculate(
        user: user,
        usageLogs: const [],
        cravingsResisted: 0,
      );

      final nf = state as NicotineFreeState;
      expect(nf.healthRecoveryTimeline, hasLength(9));
      expect(
        nf.healthRecoveryTimeline.first.sourceTitle,
        'National Cancer Institute: Nicotine Withdrawal',
      );
      expect(
        nf.healthRecoveryTimeline.last.sourceTitle,
        'CDC: Benefits of Quitting Smoking',
      );
      expect(
        nf.healthRecoveryTimeline.every(
          (milestone) =>
              milestone.sourceTitle.isNotEmpty &&
              milestone.sourceUrl.startsWith('https://'),
        ),
        isTrue,
      );
    },
  );

  test(
    'vaping uses its own evidence note and not the cigarette recovery dates',
    () {
      final calculator = buildCalculator(DateTime(2026, 8, 13));
      final user = NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        productType: ProductType.vape,
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 13),
      );

      final state =
          calculator.calculate(
                user: user,
                usageLogs: const [],
                cravingsResisted: 0,
              )
              as NicotineFreeState;

      expect(state.healthRecoveryTimeline, hasLength(5));
      expect(
        state.healthRecoveryTimeline.any(
          (milestone) => milestone.timeframe == 'Vaping-specific recovery',
        ),
        isTrue,
      );
      expect(
        state.healthRecoveryTimeline.any(
          (milestone) => milestone.timeframe == 'Minutes',
        ),
        isFalse,
      );
    },
  );

  test('calculate throws if quitDate is not yet set', () {
    final calculator = buildCalculator(DateTime(2026, 8, 13));
    final user = NicotineUser(userId: 'u1', email: 'a@b.com');

    expect(
      () => calculator.calculate(
        user: user,
        usageLogs: const [],
        cravingsResisted: 0,
      ),
      throwsStateError,
    );
  });

  test(
    'productType field is untouched by dashboard calculation (sanity: model fields unrelated to FR4 stay independent)',
    () {
      final today = DateTime(2026, 8, 13);
      final calculator = buildCalculator(today);
      final user = NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        productType: ProductType.vape,
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 13),
        baselineDailyUsage: 10,
        costPerUnit: 2,
      );

      final state = calculator.calculate(
        user: user,
        usageLogs: const [],
        cravingsResisted: 0,
      );

      expect(state, isA<NicotineFreeState>());
    },
  );
}

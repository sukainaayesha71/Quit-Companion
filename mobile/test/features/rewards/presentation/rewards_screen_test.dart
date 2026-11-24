import 'package:material_ui/material_ui.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/rewards/data/fake_badge_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/rewards/presentation/screens/rewards_screen.dart';

/// Taps through any FR9/UC7 celebration pop-ups so tests that are about the
/// underlying screen can inspect it unobstructed.
Future<void> dismissCelebrations(WidgetTester tester) async {
  // Bounded (Step 2 fix): a dialog that won't close must fail the test,
  // never loop forever.
  final button = find.byKey(const Key('badge_celebration_continue'));
  for (var i = 0; i < 3 && button.evaluate().isNotEmpty; i++) {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
  expect(button, findsNothing, reason: 'celebration dialog did not close');
}

void main() {
  final fixedToday = DateTime(2026, 8, 19);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required NicotineUser user,
    GamificationController? controller,
    bool dismissCelebrationPopups = true,
  }) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(user);
    final resolvedController =
        controller ??
        GamificationController(
          userRepository,
          FakeUsageLogRepository(),
          FakeCravingLogRepository(),
          FakeBadgeRepository(),
          DashboardStateCalculator(now: () => fixedToday),
          now: () => fixedToday,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: RewardsScreen(
          userId: user.userId,
          controller: resolvedController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (dismissCelebrationPopups) await dismissCelebrations(tester);
  }

  testWidgets(
    'shows a loading indicator, then "Your Progress" with the nicotine-free streak and badge grid',
    (tester) async {
      await pumpScreen(
        tester,
        user: NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(
            2026,
            8,
            9,
          ), // 10 days before fixedToday -> Nicotine-Free
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );

      expect(find.text('Your Progress'), findsOneWidget);
      expect(find.text('Badges Earned'), findsOneWidget);
      expect(find.text('First Day Hero'), findsNWidgets(2));
      expect(find.text('1 Week Warrior'), findsNWidgets(2));
      expect(find.text('Rewards History'), findsOneWidget);
      expect(
        find.byKey(const Key('rewards_history_u1_firstDayHero')),
        findsOneWidget,
      );
      expect(find.text('2026-08-19'), findsWidgets);
      expect(find.text('30 Day Champion'), findsOneWidget);
      expect(find.text('90 Day Legend'), findsOneWidget);
      expect(find.text('6 Month Hero'), findsOneWidget);
      expect(find.text('1 Year Champion'), findsOneWidget);
      expect(find.byKey(const Key('rewards_back_button')), findsOneWidget);
      expect(
        find.byKey(const Key('rewards_weekly_streak_row')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'nicotine-free streak matches the dashboard count without activity logs',
    (tester) async {
      await pumpScreen(
        tester,
        user: NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 16), // 3 nicotine-free days
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );

      final streak = tester.widget<Text>(
        find.byKey(const Key('rewards_day_streak_value')),
      );
      expect(streak.data, '3');
      expect(find.text('Nicotine-Free Streak'), findsOneWidget);
    },
  );

  testWidgets('tapping the back button pops the screen', (tester) async {
    final userRepository = FakeUserRepository();
    final user = NicotineUser(
      userId: 'u1',
      email: 'a@b.com',
      quitStrategy: QuitStrategy.coldTurkey,
      quitDate: DateTime(2026, 8, 9),
      baselineDailyUsage: 10,
      costPerUnit: 2,
    );
    await userRepository.saveUser(user);
    final controller = GamificationController(
      userRepository,
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      FakeBadgeRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RewardsScreen(userId: 'u1', controller: controller),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await dismissCelebrations(tester);
    expect(find.byType(RewardsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('rewards_back_button')));
    await tester.pumpAndSettle();

    expect(find.byType(RewardsScreen), findsNothing);
  });

  testWidgets('locked badges show a lock icon, earned badges do not', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      user: NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(
          2026,
          8,
          9,
        ), // 10 days -> only First Day Hero + 1 Week Warrior earned
        baselineDailyUsage: 10,
        costPerUnit: 2,
      ),
    );

    expect(
      find.byKey(const Key('badge_locked_thirtyDayChampion')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('badge_locked_firstDayHero')), findsNothing);
  });

  testWidgets(
    'a Countdown-phase Gradual user sees the Reduction Streak instead of badges',
    (tester) async {
      await pumpScreen(
        tester,
        user: NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.gradual,
          quitDate: DateTime(2026, 8, 25),
          baselineDailyUsage: 10,
          costPerUnit: 2,
          reductionSchedule: {DateTime(2026, 8, 19): 6},
        ),
      );

      expect(find.byKey(const Key('rewards_reduction_streak')), findsOneWidget);
      for (final badge in [
        'First Day Hero',
        '1 Week Warrior',
        '30 Day Champion',
      ]) {
        expect(
          find.byKey(Key('badge_locked_${badge.replaceAll(' ', '')}')),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'a Countdown-phase Cold-Turkey/Date-Based user sees an explanatory hint, not a bare empty screen',
    (tester) async {
      // Regression test: previously this combination (Countdown phase, no
      // reduction streak since that's Gradual-only) showed just the streak
      // card with nothing explaining why no badges appeared yet — easy to
      // mistake for a broken/empty Rewards screen.
      await pumpScreen(
        tester,
        user: NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(
            2026,
            8,
            25,
          ), // after fixedToday -> still Countdown
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );

      expect(
        find.byKey(const Key('rewards_badges_locked_hint')),
        findsOneWidget,
      );
      expect(
        find.text('Badges unlock once you reach your Quit Day — keep going!'),
        findsOneWidget,
      );
      expect(find.text('Badges Earned'), findsNothing);
      expect(find.byKey(const Key('rewards_reduction_streak')), findsNothing);
    },
  );
}

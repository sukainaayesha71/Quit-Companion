import 'package:material_ui/material_ui.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/rewards/data/fake_badge_repository.dart';
import 'package:quit_companion/features/rewards/models/badge.dart' as models;
import 'package:quit_companion/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:quit_companion/features/rewards/presentation/widgets/badge_celebration_dialog.dart';
import 'package:quit_companion/features/rewards/presentation/widgets/badge_celebration_listener.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';

const _dialog = Key('badge_celebration_dialog');
const _continue = Key('badge_celebration_continue');
const _label = Key('badge_celebration_label');

void main() {
  final fixedToday = DateTime(2026, 8, 19);

  Future<GamificationController> buildController({
    required DateTime quitDate,
    FakeBadgeRepository? badgeRepository,
  }) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: quitDate,
        baselineDailyUsage: 10,
        costPerUnit: 2,
      ),
    );
    return GamificationController(
      userRepository,
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      badgeRepository ?? FakeBadgeRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
  }

  String? shownLabel(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(_label)).data;

  group('BadgeCelebrationDialog', () {
    testWidgets('shows the badge name, points and a themed continue button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => BadgeCelebrationDialog.show(
                  context,
                  models.Badge(
                    badgeId: 'u1_thirtyDayChampion',
                    userId: 'u1',
                    badgeType: models.BadgeType.thirtyDayChampion,
                    dateEarned: fixedToday,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsOneWidget);
      expect(find.text('Congratulations!'), findsOneWidget);
      expect(shownLabel(tester), '30 Day Champion');
      expect(find.text('+150 reward points'), findsOneWidget);
      expect(
        find.text("You've been nicotine-free for 30 days. Keep it up!"),
        findsOneWidget,
      );
      expect(find.text('Keep going'), findsOneWidget);

      await tester.tap(find.byKey(_continue));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialog), findsNothing);
    });

    testWidgets(
      'several badges earned together share one dialog with a points total',
      (tester) async {
        models.Badge badge(models.BadgeType type) => models.Badge(
          badgeId: 'u1_${type.name}',
          userId: 'u1',
          badgeType: type,
          dateEarned: fixedToday,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BadgeCelebrationDialog(
                badges: [
                  badge(models.BadgeType.firstDayHero),
                  badge(models.BadgeType.oneWeekWarrior),
                  badge(models.BadgeType.thirtyDayChampion),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('You unlocked 3 new badges'), findsOneWidget);
        for (final type in [
          models.BadgeType.firstDayHero,
          models.BadgeType.oneWeekWarrior,
          models.BadgeType.thirtyDayChampion,
        ]) {
          expect(
            find.byKey(Key('badge_celebration_item_${type.name}')),
            findsOneWidget,
          );
        }
        expect(find.text('+210 reward points'), findsOneWidget);
        expect(find.text('Keep going'), findsOneWidget);
      },
    );

    testWidgets(
      'on a 320x640 screen at 1.5x text the button stays visible and works',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => BadgeCelebrationDialog.showAll(context, [
                    for (final type in models.BadgeType.values.take(5))
                      models.Badge(
                        badgeId: 'u1_${type.name}',
                        userId: 'u1',
                        badgeType: type,
                        dateEarned: fixedToday,
                      ),
                  ]),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final button = tester.getRect(find.byKey(_continue));
        expect(
          button.bottom,
          lessThanOrEqualTo(640),
          reason: 'button must be on screen',
        );
        expect(button.top, greaterThanOrEqualTo(0));

        await tester.tap(find.byKey(_continue));
        await tester.pumpAndSettle();
        expect(find.byKey(_dialog), findsNothing);
      },
    );
  });

  group('BadgeCelebrationListener on RewardsScreen', () {
    testWidgets(
      'celebrates badges earned together in one dialog, then never again on reopen',
      (tester) async {
        final controller = await buildController(
          quitDate: DateTime(2026, 8, 9), // 10 days -> 2 new badges
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RewardsScreen(userId: 'u1', controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_dialog), findsOneWidget);
        expect(find.text('You unlocked 2 new badges'), findsOneWidget);
        expect(
          find.byKey(const Key('badge_celebration_item_firstDayHero')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('badge_celebration_item_oneWeekWarrior')),
          findsOneWidget,
        );
        expect(find.text('+60 reward points'), findsOneWidget);

        await tester.tap(find.byKey(_continue));
        await tester.pumpAndSettle();
        expect(
          find.byKey(_dialog),
          findsNothing,
          reason: 'one dismissal is enough',
        );
        // Existing reward data is untouched by the celebration flow.
        expect(find.text('60 reward points'), findsOneWidget);

        // Reopen the screen with the same (app-scoped) controller.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpWidget(
          MaterialApp(
            home: RewardsScreen(userId: 'u1', controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_dialog), findsNothing);
        expect(find.text('60 reward points'), findsOneWidget);
      },
    );

    testWidgets('badges already saved before this session are not celebrated', (
      tester,
    ) async {
      final badgeRepository = FakeBadgeRepository();
      for (final type in [
        models.BadgeType.firstDayHero,
        models.BadgeType.oneWeekWarrior,
      ]) {
        await badgeRepository.saveBadge(
          models.Badge(
            badgeId: 'u1_${type.name}',
            userId: 'u1',
            badgeType: type,
            dateEarned: DateTime(2026, 8, 16),
          ),
        );
      }
      final controller = await buildController(
        quitDate: DateTime(2026, 8, 9),
        badgeRepository: badgeRepository,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RewardsScreen(userId: 'u1', controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsNothing);
      expect(find.text('60 reward points'), findsOneWidget);
    });
  });

  testWidgets(
    'when two listeners are mounted, only the one on the top route shows the pop-up, once',
    (tester) async {
      final controller = await buildController(
        quitDate: DateTime(2026, 8, 18), // 1 day -> First Day Hero only
      );
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: BadgeCelebrationListener(
            controller: controller,
            child: const Scaffold(body: Text('below')),
          ),
        ),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => BadgeCelebrationListener(
            controller: controller,
            child: const Scaffold(body: Text('top')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await controller.loadRewards('u1');
      await tester.pumpAndSettle();

      expect(find.byKey(_dialog), findsOneWidget);
      await tester.tap(find.byKey(_continue));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialog), findsNothing);

      // Going back to the lower screen must not replay it.
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await controller.loadRewards('u1');
      await tester.pumpAndSettle();
      expect(find.text('below'), findsOneWidget);
      expect(find.byKey(_dialog), findsNothing);
    },
  );
}

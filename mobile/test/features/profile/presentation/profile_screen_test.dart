import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/rewards/data/fake_badge_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/goals/domain/weekly_plan_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/presentation/screens/profile_screen.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';

void main() {
  final fixedToday = DateTime(2026, 9, 2);

  Future<DashboardController> buildLoadedController(
    FakeUserRepository userRepository,
  ) async {
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        name: 'Mehreen',
        productType: ProductType.cigarettes,
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
        baselineDailyUsage: 10,
      ),
    );
    final controller = DashboardController(
      userRepository,
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
    await controller.loadDashboard('u1');
    return controller;
  }

  AiPlanController buildAiPlanController({FakeUserRepository? userRepository}) {
    return AiPlanController(
      userRepository ?? FakeUserRepository(),
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      WeeklyPlanCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
  }

  ReminderController buildReminderController() {
    return ReminderController(
      FakeReminderSettingsRepository(),
      FakeReminderNotificationService(),
    );
  }

  GamificationController buildGamificationController({
    FakeUserRepository? userRepository,
  }) {
    return GamificationController(
      userRepository ?? FakeUserRepository(),
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      FakeBadgeRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
  }

  testWidgets(
    'shows the user name, product type, and Log Out triggers onLogout',
    (tester) async {
      final userRepository = FakeUserRepository();
      final dashboardController = await buildLoadedController(userRepository);
      var loggedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            userId: 'u1',
            dashboardController: dashboardController,
            profileController: ProfileController(userRepository),
            aiPlanController: buildAiPlanController(
              userRepository: userRepository,
            ),
            reminderController: buildReminderController(),
            gamificationController: buildGamificationController(
              userRepository: userRepository,
            ),
            onLogout: () => loggedOut = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mehreen'), findsOneWidget);
      expect(find.byKey(const Key('profile_avatar_female')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('profile_log_out_button')),
      );
      await tester.tap(find.byKey(const Key('profile_log_out_button')));
      await tester.pump();

      expect(loggedOut, isTrue);
    },
  );

  testWidgets('the header Edit Profile action opens the full profile editor', (
    tester,
  ) async {
    final userRepository = FakeUserRepository();
    final dashboardController = await buildLoadedController(userRepository);
    final profileController = ProfileController(userRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          userId: 'u1',
          dashboardController: dashboardController,
          profileController: profileController,
          aiPlanController: buildAiPlanController(
            userRepository: userRepository,
          ),
          reminderController: buildReminderController(),
          gamificationController: buildGamificationController(
            userRepository: userRepository,
          ),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile_edit_button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.byKey(const Key('profile_product_type_field')), findsOneWidget);
    expect(find.byKey(const Key('profile_daily_usage_field')), findsOneWidget);
    expect(
      find.byKey(const Key('profile_primary_motivation_field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('profile_name_field')),
      'Sukaina',
    );
    await tester.enterText(
      find.byKey(const Key('profile_daily_usage_field')),
      '15',
    );
    await tester.enterText(
      find.byKey(const Key('profile_primary_motivation_field')),
      'Family',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile_save_button')));
    await tester.tap(find.byKey(const Key('profile_save_button')));
    await tester.pumpAndSettle();

    final saved = await userRepository.getUser('u1');
    expect(saved!.name, 'Sukaina');
    expect(saved.baselineDailyUsage, 15);
    expect(saved.primaryMotivation, 'Family');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Sukaina'), findsOneWidget);
  });

  testWidgets(
    'SRDS 4.2: the Crisis Support row opens the Crisis Support screen',
    (tester) async {
      final userRepository = FakeUserRepository();
      final dashboardController = await buildLoadedController(userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            userId: 'u1',
            dashboardController: dashboardController,
            profileController: ProfileController(userRepository),
            aiPlanController: buildAiPlanController(
              userRepository: userRepository,
            ),
            reminderController: buildReminderController(),
            gamificationController: buildGamificationController(
              userRepository: userRepository,
            ),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('profile_row_crisis_support'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(CrisisSupportScreen), findsOneWidget);
    },
  );
}

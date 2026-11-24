import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
import 'package:quit_companion/features/auth/data/auth_repository.dart';
import 'package:quit_companion/features/auth/data/fake_auth_repository.dart';
import 'package:quit_companion/features/rewards/data/fake_badge_repository.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/auth/data/fake_account_deletion_repository.dart';
import 'package:quit_companion/features/auth/data/fake_biometric_lock_service.dart';
import 'package:quit_companion/app/quit_companion_app.dart';

void main() {
  testWidgets('restored session requires the opted-in device biometric', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      currentUserId: 'u1',
      currentEmail: 'a@b.com',
    );
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        name: 'Ahsan',
        productType: ProductType.cigarettes,
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 1, 1),
        baselineDailyUsage: 5,
      ),
    );
    final biometricService = FakeBiometricLockService(
      available: true,
      enabledUserId: 'u1',
      authenticationResult: false,
    );

    await tester.pumpWidget(
      QuitCompanionApp(
        authRepository: authRepository,
        userRepository: userRepository,
        usageLogRepository: FakeUsageLogRepository(),
        cravingLogRepository: FakeCravingLogRepository(),
        journalRepository: FakeJournalRepository(),
        healthBotRepository: FakeHealthBotRepository(),
        habitAlternativeAttemptRepository:
            FakeHabitAlternativeAttemptRepository(),
        badgeRepository: FakeBadgeRepository(),
        communityPostRepository: FakeCommunityPostRepository(),
        articleBookmarkRepository: FakeArticleBookmarkRepository(),
        reminderSettingsRepository: FakeReminderSettingsRepository(),
        reminderNotificationService: FakeReminderNotificationService(),
        biometricLockService: biometricService,
        accountDeletionRepository: FakeAccountDeletionRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('biometric_unlock_title')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_nicotine_free_days')), findsNothing);

    biometricService.authenticationResult = true;
    await tester.tap(find.byKey(const Key('biometric_unlock_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard_nicotine_free_days')),
      findsOneWidget,
    );
    expect(biometricService.authenticationReasons, hasLength(2));
  });

  testWidgets(
    'register -> consent -> product selection -> quantity -> goal -> habit summary -> dashboard',
    (tester) async {
      // The Product Selection/Quantity/Goal screens (Tasks 5-7) use tall header
      // illustrations inside OnboardingScaffold that don't fit the default
      // 800x600 test surface — their own widget tests already work around this
      // with a larger physicalSizeTestValue (see e.g.
      // test/features/onboarding/presentation/screens/goal_selection_screen_test.dart),
      // and this end-to-end test now walks through those screens too.
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);

      // Injects fakes so this widget test never touches live Firebase — main()'s
      // real entry point wires FirebaseAuthRepository/FirestoreUserRepository/
      // FirestoreUsageLogRepository instead.
      await tester.pumpWidget(
        QuitCompanionApp(
          authRepository: FakeAuthRepository()
            ..googleSignInResult = GoogleAuthResult(
              userId: 'google-u1',
              email: 'a@b.com',
              name: 'Ahsan',
            ),
          userRepository: FakeUserRepository(),
          usageLogRepository: FakeUsageLogRepository(),
          cravingLogRepository: FakeCravingLogRepository(),
          journalRepository: FakeJournalRepository(),
          healthBotRepository: FakeHealthBotRepository(),
          habitAlternativeAttemptRepository:
              FakeHabitAlternativeAttemptRepository(),
          badgeRepository: FakeBadgeRepository(),
          communityPostRepository: FakeCommunityPostRepository(),
          articleBookmarkRepository: FakeArticleBookmarkRepository(),
          reminderSettingsRepository: FakeReminderSettingsRepository(),
          reminderNotificationService: FakeReminderNotificationService(),
        ),
      );

      await tester.tap(find.byKey(const Key('welcome_register_button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('register_google_button')),
      );
      await tester.tap(find.byKey(const Key('register_google_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('consent_checkbox')), findsOneWidget);
      await tester.tap(find.byKey(const Key('consent_checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('consent_continue_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gender_option_female')), findsOneWidget);
      await tester.tap(find.byKey(const Key('gender_option_female')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('gender_continue_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('product_option_cigarettes')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('product_option_cigarettes')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_option_cigarettes')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('product_selection_continue_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quantity_slider')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quantity_continue_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('goal_option_coldTurkey')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('goal_option_coldTurkey')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal_option_coldTurkey')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('goal_generate_plan_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('onboarding_complete_summary')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('onboarding_complete_continue_button')),
      );
      await tester.pumpAndSettle();

      // COLD_TURKEY sets quitDate = today, so the Dashboard is immediately
      // in the Nicotine-Free state (SDD §7.2).
      expect(
        find.byKey(const Key('dashboard_nicotine_free_days')),
        findsOneWidget,
      );
    },
  );

  testWidgets('deleting an account returns to the welcome screen', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      currentUserId: 'u1',
      currentEmail: 'a@b.com',
    );
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        name: 'Ahsan',
        productType: ProductType.cigarettes,
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 1, 1),
        baselineDailyUsage: 5,
      ),
    );
    final deletionRepository = FakeAccountDeletionRepository();

    await tester.pumpWidget(
      QuitCompanionApp(
        authRepository: authRepository,
        userRepository: userRepository,
        usageLogRepository: FakeUsageLogRepository(),
        cravingLogRepository: FakeCravingLogRepository(),
        journalRepository: FakeJournalRepository(),
        healthBotRepository: FakeHealthBotRepository(),
        habitAlternativeAttemptRepository:
            FakeHabitAlternativeAttemptRepository(),
        badgeRepository: FakeBadgeRepository(),
        communityPostRepository: FakeCommunityPostRepository(),
        articleBookmarkRepository: FakeArticleBookmarkRepository(),
        reminderSettingsRepository: FakeReminderSettingsRepository(),
        reminderNotificationService: FakeReminderNotificationService(),
        biometricLockService: FakeBiometricLockService(),
        accountDeletionRepository: deletionRepository,
      ),
    );
    await tester.pumpAndSettle();

    // Quit date 2026-01-01: several badge tiers are earned at once on the
    // first Dashboard load. FR9 shows them in ONE celebration dialog
    // (previously one modal per badge blocked the screen); dismiss it.
    expect(find.byKey(const Key('badge_celebration_dialog')), findsOneWidget);
    expect(find.textContaining('new badges'), findsOneWidget);
    await tester.tap(find.byKey(const Key('badge_celebration_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badge_celebration_dialog')), findsNothing);

    await tester.tap(find.byKey(const Key('dashboard_bottom_nav_profile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('profile_row_privacy_security')),
    );
    await tester.tap(find.byKey(const Key('profile_row_privacy_security')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('delete_account_button')));
    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete_account_confirmation_field')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_delete_account_button')));
    await tester.pumpAndSettle();

    expect(deletionRepository.deleteCount, 1);
    expect(authRepository.currentUserId, isNull);
    expect(find.byKey(const Key('welcome_register_button')), findsOneWidget);
    expect(find.byKey(const Key('welcome_login_button')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_nicotine_free_days')), findsNothing);
  });
}

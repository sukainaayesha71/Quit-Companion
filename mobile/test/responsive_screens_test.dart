import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
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
import 'package:quit_companion/app/quit_companion_app.dart';

import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';

void main() {
  final destinations = <String>[
    'dashboard',
    'dashboard_quick_access_log_craving',
    'dashboard_quick_access_alternatives',
    'dashboard_quick_access_health_bot',
    'dashboard_quick_access_rewards',
    'dashboard_quick_access_community',
    'dashboard_quick_access_journal',
    'dashboard_quick_access_relapse_log',
    'dashboard_quick_access_knowledge_hub',
    'dashboard_quick_access_my_quit_plan',
    'dashboard_bottom_nav_track',
    'dashboard_bottom_nav_profile',
    'dashboard_notifications_button',
    'dashboard_quick_access_journal>journal_add_button',
    'dashboard_quick_access_community>community_new_post_button',
    'dashboard_bottom_nav_profile>profile_edit_button',
    'dashboard_bottom_nav_profile>profile_row_privacy_security',
    'dashboard_bottom_nav_profile>profile_row_help_support',
    'dashboard_bottom_nav_profile>profile_row_about',
  ];
  for (final scale in [1.0, 1.5]) {
    for (final destination in destinations) {
      testWidgets('portrait 320x640 text $scale: $destination', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.setSurfaceSize(null);
        });
        final originalErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          originalErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalErrorHandler);
        final users = FakeUserRepository();
        await users.saveUser(
          NicotineUser(
            userId: 'responsive-user',
            email: 'test@example.com',
            name: 'A longer display name',
            productType: ProductType.cigarettes,
            quitStrategy: QuitStrategy.coldTurkey,
            quitDate: DateTime.now().subtract(const Duration(days: 8)),
            baselineDailyUsage: 10,
          ),
        );
        await tester.pumpWidget(
          QuitCompanionApp(
            authRepository: FakeAuthRepository(
              currentUserId: 'responsive-user',
              currentEmail: 'test@example.com',
            ),
            userRepository: users,
            usageLogRepository: FakeUsageLogRepository(),
            cravingLogRepository: FakeCravingLogRepository(),
            relapsePredictionClient: FakeRelapsePredictionClient(),
            journalRepository: FakeJournalRepository(),
            healthBotClient: FakeHealthBotClient(),
            healthBotRepository: FakeHealthBotRepository(),
            habitAlternativeAttemptRepository:
                FakeHabitAlternativeAttemptRepository(),
            badgeRepository: FakeBadgeRepository(),
            communityPostRepository: FakeCommunityPostRepository(),
            articleBookmarkRepository: FakeArticleBookmarkRepository(),
            reminderSettingsRepository: FakeReminderSettingsRepository(),
            reminderNotificationService: FakeReminderNotificationService(),
            accountDeletionRepository: FakeAccountDeletionRepository(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // FR9/UC7: this user is 8 days nicotine-free, so the Dashboard
        // opens with ONE celebration dialog (badges earned together are
        // combined). It has just been laid out at this size/text scale
        // (checked above). Its button must be on screen and close it in a
        // single tap — bounded so a regression fails instead of hanging.
        final celebrationContinue = find.byKey(
          const Key('badge_celebration_continue'),
        );
        expect(celebrationContinue, findsOneWidget);
        final buttonRect = tester.getRect(celebrationContinue);
        expect(buttonRect.bottom, lessThanOrEqualTo(640));
        await tester.tap(celebrationContinue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(celebrationContinue, findsNothing);
        if (destination != 'dashboard') {
          for (final key in destination.split('>')) {
            final target = find.byKey(Key(key));
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        // Lay out lazily built cards further down each screen too.
        final vertical = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        if (vertical.evaluate().isNotEmpty) {
          for (var step = 0; step < 4; step++) {
            await tester.drag(vertical.first, const Offset(0, -380));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/relapse/controllers/relapse_controller.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
import 'package:quit_companion/features/rewards/data/fake_badge_repository.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/relapse/domain/restart_plan_calculator.dart';
import 'package:quit_companion/features/goals/domain/weekly_plan_calculator.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/presentation/screens/high_risk_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/log_craving_screen.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_background.dart';
import 'package:quit_companion/features/goals/presentation/screens/weekly_plan_screen.dart';
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_screen.dart';
import 'package:quit_companion/features/journal/presentation/screens/journal_screen.dart';
import 'package:quit_companion/features/community/presentation/screens/community_screen.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/knowledge_hub_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/profile_screen.dart';
import 'package:quit_companion/features/relapse/presentation/screens/relapse_log_screen.dart';
import 'package:quit_companion/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:quit_companion/features/reminders/presentation/screens/reminder_settings_screen.dart';
import 'package:quit_companion/features/tracking/presentation/screens/track_screen.dart';

void main() {
  final fixedToday = DateTime(2026, 8, 13);

  DashboardController buildController({
    required FakeUserRepository userRepository,
    FakeUsageLogRepository? usageLogRepository,
    FakeCravingLogRepository? cravingLogRepository,
  }) {
    return DashboardController(
      userRepository,
      usageLogRepository ?? FakeUsageLogRepository(),
      cravingLogRepository ?? FakeCravingLogRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
  }

  CravingLogController buildCravingLogController() {
    return CravingLogController(
      FakeCravingLogRepository(),
      FakeRelapsePredictionClient(),
    );
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

  JournalController buildJournalController() {
    return JournalController(FakeJournalRepository(), now: () => fixedToday);
  }

  RelapseController buildRelapseController({
    FakeUserRepository? userRepository,
  }) {
    return RelapseController(
      FakeJournalRepository(),
      userRepository ?? FakeUserRepository(),
      FakeCravingLogRepository(),
      RestartPlanCalculator(),
      now: () => fixedToday,
    );
  }

  HealthBotController buildHealthBotController() {
    return HealthBotController(
      FakeHealthBotClient(),
      FakeHealthBotRepository(),
      now: () => fixedToday,
    );
  }

  AlternativesController buildAlternativesController() {
    return AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
      now: () => fixedToday,
    );
  }

  CommunityController buildCommunityController() {
    return CommunityController(
      FakeCommunityPostRepository(),
      now: () => fixedToday,
    );
  }

  KnowledgeHubController buildKnowledgeHubController() {
    return KnowledgeHubController(FakeArticleBookmarkRepository());
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

  TrackController buildTrackController({FakeUserRepository? userRepository}) {
    return TrackController(
      FakeCravingLogRepository(),
      FakeJournalRepository(),
      userRepository ?? FakeUserRepository(),
    );
  }

  ProfileController buildProfileController() {
    return ProfileController(FakeUserRepository());
  }

  testWidgets(
    'shows the Countdown state for a GRADUAL user, including usage logging',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard_days_until_quit')),
        findsOneWidget,
      );
      expect(find.text('7 days to go'), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard_reduction_streak')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard_usage_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('dashboard_usage_field')),
        '5',
      );
      await tester.ensureVisible(
        find.byKey(const Key('dashboard_log_usage_button')),
      );
      await tester.tap(find.byKey(const Key('dashboard_log_usage_button')));
      await tester.pumpAndSettle();

      final logs = await usageLogRepository.getUsageLogs('u1');
      expect(logs, hasLength(1));
      expect(logs.first.actualUsage, 5);

      await tester.ensureVisible(find.text('Nicotine Recovery Timeline'));
      expect(
        find.byKey(const Key('health_recovery_phase_context')),
        findsOneWidget,
      );
      expect(find.textContaining('Your planned Quit Day is'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the Nicotine-Free state with cravings resisted and a pending health timeline',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard_nicotine_free_days')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dashboard_cravings_resisted')),
        findsOneWidget,
      );
      expect(
        find.textContaining('General information, not a prediction'),
        findsOneWidget,
      );
      expect(find.text('Nicotine Recovery Timeline'), findsOneWidget);
      expect(
        find.textContaining('National Cancer Institute: Nicotine Withdrawal'),
        findsWidgets,
      );
    },
  );

  testWidgets('renders the illustrated background behind the content card', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          userId: 'u1',
          controller: controller,
          cravingLogController: buildCravingLogController(),
          aiPlanController: buildAiPlanController(),
          journalController: buildJournalController(),
          relapseController: buildRelapseController(),
          healthBotController: buildHealthBotController(),
          alternativesController: buildAlternativesController(),
          gamificationController: buildGamificationController(),
          communityController: buildCommunityController(),
          knowledgeHubController: buildKnowledgeHubController(),
          reminderController: buildReminderController(),
          trackController: buildTrackController(),
          profileController: buildProfileController(),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard_background')), findsOneWidget);
    expect(find.byType(DashboardBackground), findsOneWidget);
    // Existing chrome must still be present on top of the background.
    expect(
      find.byKey(const Key('dashboard_nicotine_free_days')),
      findsOneWidget,
    );
  });

  testWidgets('shows an unread-notification dot on the bell', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          userId: 'u1',
          controller: controller,
          cravingLogController: buildCravingLogController(),
          aiPlanController: buildAiPlanController(),
          journalController: buildJournalController(),
          relapseController: buildRelapseController(),
          healthBotController: buildHealthBotController(),
          alternativesController: buildAlternativesController(),
          gamificationController: buildGamificationController(),
          communityController: buildCommunityController(),
          knowledgeHubController: buildKnowledgeHubController(),
          reminderController: buildReminderController(),
          trackController: buildTrackController(),
          profileController: buildProfileController(),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard_notifications_dot')),
      findsOneWidget,
    );
  });

  testWidgets('shows the This Week chart with a comparison badge', (
    tester,
  ) async {
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
    // fixedToday = Aug 13, 2026 — this log falls in "last week" (Jul 31-Aug
    // 6), giving a non-null pctBetterThanLastWeek so the badge renders.
    await cravingLogRepository.logCraving(
      CravingLog(
        logId: 'log1',
        userId: 'u1',
        cravingIntensity: 5,
        mood: Mood.stressed,
        triggerCategory: TriggerCategory.stress,
        locationContext: 'Home',
        activity: 'Watching TV',
        timestamp: DateTime(2026, 8, 6, 9),
        relapseRiskScore: RelapseRiskLevel.low,
      ),
    );
    final controller = DashboardController(
      userRepository,
      FakeUsageLogRepository(),
      cravingLogRepository,
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          userId: 'u1',
          controller: controller,
          cravingLogController: buildCravingLogController(),
          aiPlanController: buildAiPlanController(),
          journalController: buildJournalController(),
          relapseController: buildRelapseController(),
          healthBotController: buildHealthBotController(),
          alternativesController: buildAlternativesController(),
          gamificationController: buildGamificationController(),
          communityController: buildCommunityController(),
          knowledgeHubController: buildKnowledgeHubController(),
          reminderController: buildReminderController(),
          trackController: buildTrackController(),
          profileController: buildProfileController(),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard_weekly_progress_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard_weekly_trend_chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard_weekly_comparison_badge')),
      findsOneWidget,
    );
  });

  testWidgets('greets the user by first name when NicotineUser.name is set', (
    tester,
  ) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        name: 'Sukaina Ayesha',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
        baselineDailyUsage: 10,
        costPerUnit: 2,
      ),
    );
    final controller = buildController(userRepository: userRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          userId: 'u1',
          controller: controller,
          cravingLogController: buildCravingLogController(),
          aiPlanController: buildAiPlanController(),
          journalController: buildJournalController(),
          relapseController: buildRelapseController(),
          healthBotController: buildHealthBotController(),
          alternativesController: buildAlternativesController(),
          gamificationController: buildGamificationController(),
          communityController: buildCommunityController(),
          knowledgeHubController: buildKnowledgeHubController(),
          reminderController: buildReminderController(),
          trackController: buildTrackController(),
          profileController: buildProfileController(),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi Sukaina!'), findsOneWidget);
  });

  testWidgets(
    'falls back to the generic greeting when NicotineUser.name is missing',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hi there 👋'), findsOneWidget);
    },
  );

  testWidgets('shows an error message when the user has no quit plan set up', (
    tester,
  ) async {
    final controller = buildController(userRepository: FakeUserRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          userId: 'missing-user',
          controller: controller,
          cravingLogController: buildCravingLogController(),
          aiPlanController: buildAiPlanController(),
          journalController: buildJournalController(),
          relapseController: buildRelapseController(),
          healthBotController: buildHealthBotController(),
          alternativesController: buildAlternativesController(),
          gamificationController: buildGamificationController(),
          communityController: buildCommunityController(),
          knowledgeHubController: buildKnowledgeHubController(),
          reminderController: buildReminderController(),
          trackController: buildTrackController(),
          profileController: buildProfileController(),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard_error_text')), findsOneWidget);
  });

  testWidgets(
    'DATE_BASED Countdown does not show the usage-logging entry point',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(2026, 8, 20),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard_days_until_quit')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard_usage_field')), findsNothing);
      expect(find.byKey(const Key('dashboard_reduction_streak')), findsNothing);
    },
  );

  testWidgets(
    'tapping the Log Craving tile navigates to LogCravingScreen (Module 3)',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_log_craving')),
      );
      await tester.tap(
        find.byKey(const Key('dashboard_quick_access_log_craving')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LogCravingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the My Quit Plan tile navigates to WeeklyPlanScreen (Module 4)',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(
              userRepository: userRepository,
            ),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_my_quit_plan')),
      );
      await tester.tap(
        find.byKey(const Key('dashboard_quick_access_my_quit_plan')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeeklyPlanScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Journal tile navigates to JournalScreen (Module 5), in any phase',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(
            2026,
            8,
            20,
          ), // Countdown phase — Journal should still work
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_journal')),
      );
      await tester.tap(find.byKey(const Key('dashboard_quick_access_journal')));
      await tester.pumpAndSettle();

      expect(find.byType(JournalScreen), findsOneWidget);
    },
  );

  testWidgets(
    'the Relapse Log tile is disabled during the Countdown phase (FR12 precondition)',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(2026, 8, 20),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard_quick_access_relapse_log')),
        findsNothing,
      );
      // Regression: previously the disabled tile gave no indication why it
      // was unresponsive, which reads as "this feature is broken" rather
      // than "not unlocked yet."
      expect(
        find.byKey(const Key('dashboard_quick_access_relapse_log_locked_hint')),
        findsOneWidget,
      );
      expect(find.text('Unlocks on Quit Day'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Relapse Log tile navigates to RelapseLogScreen when Nicotine-Free',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1), // Nicotine-Free phase
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(
              userRepository: userRepository,
            ),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_relapse_log')),
      );
      await tester.tap(
        find.byKey(const Key('dashboard_quick_access_relapse_log')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RelapseLogScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Health-Bot Quick Access tile navigates to HealthBotScreen (Module 6), in any phase',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(
            2026,
            8,
            20,
          ), // Countdown phase — Health-Bot should still work
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_health_bot')),
      );
      await tester.tap(
        find.byKey(const Key('dashboard_quick_access_health_bot')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HealthBotScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the bottom-nav Health-Bot button navigates to HealthBotScreen (Module 6)',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('dashboard_bottom_nav_health_bot')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HealthBotScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Rewards Quick Access tile navigates to RewardsScreen (Module 8), in any phase',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(
            2026,
            8,
            20,
          ), // Countdown phase — Rewards should still work
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(
              userRepository: userRepository,
            ),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_rewards')),
      );
      await tester.tap(find.byKey(const Key('dashboard_quick_access_rewards')));
      await tester.pumpAndSettle();

      expect(find.byType(RewardsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Alternatives Quick Access tile navigates to HighRiskScreen (Module 7)',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(2026, 8, 20),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(
              userRepository: userRepository,
            ),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_alternatives')),
      );
      await tester.tap(
        find.byKey(const Key('dashboard_quick_access_alternatives')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HighRiskScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Community Quick Access tile navigates to CommunityScreen (Module 9)',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_community')),
      );
      await tester.tap(
        find.byKey(const Key('dashboard_quick_access_community')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CommunityScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the bottom-nav Community button navigates to CommunityScreen (Module 9)',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard_bottom_nav_community')));
      await tester.pumpAndSettle();

      expect(find.byType(CommunityScreen), findsOneWidget);
    },
  );

  testWidgets('tapping the bottom-nav Track button navigates to TrackScreen', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          userId: 'u1',
          controller: controller,
          cravingLogController: buildCravingLogController(),
          aiPlanController: buildAiPlanController(),
          journalController: buildJournalController(),
          relapseController: buildRelapseController(),
          healthBotController: buildHealthBotController(),
          alternativesController: buildAlternativesController(),
          gamificationController: buildGamificationController(),
          communityController: buildCommunityController(),
          knowledgeHubController: buildKnowledgeHubController(),
          reminderController: buildReminderController(),
          trackController: buildTrackController(userRepository: userRepository),
          profileController: buildProfileController(),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_bottom_nav_track')));
    await tester.pumpAndSettle();

    expect(find.byType(TrackScreen), findsOneWidget);
  });

  testWidgets(
    'tapping the bottom-nav Profile button navigates to ProfileScreen',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard_bottom_nav_profile')));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Knowledge Hub Quick Access tile navigates to KnowledgeHubScreen (Module 10)',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(
            2026,
            8,
            20,
          ), // Countdown phase — Knowledge Hub should still work
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_knowledge_hub')),
      );
      await tester.tap(
        find.byKey(const Key('dashboard_quick_access_knowledge_hub')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KnowledgeHubScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the notification bell navigates to ReminderSettingsScreen (Module 11)',
    (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: controller,
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard_notifications_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ReminderSettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'FR9/UC7: a badge newly earned on the Dashboard is celebrated once, and not replayed on Rewards',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: fixedToday.subtract(const Duration(days: 2)),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: buildController(userRepository: userRepository),
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(
              userRepository: userRepository,
            ),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('badge_celebration_dialog')), findsOneWidget);
      expect(find.byKey(const Key('badge_celebration_label')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('badge_celebration_label')))
            .data,
        'First Day Hero',
      );
      await tester.tap(find.byKey(const Key('badge_celebration_continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('badge_celebration_dialog')), findsNothing);

      await tester.ensureVisible(
        find.byKey(const Key('dashboard_quick_access_rewards')),
      );
      await tester.tap(find.byKey(const Key('dashboard_quick_access_rewards')));
      await tester.pumpAndSettle();

      expect(find.byType(RewardsScreen), findsOneWidget);
      expect(find.byKey(const Key('badge_celebration_dialog')), findsNothing);
    },
  );

  group('FR4/UC6 dashboard improvements', () {
    Future<void> pumpDashboard(
      WidgetTester tester, {
      required FakeCravingLogRepository cravingLogRepository,
    }) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: fixedToday.add(
            const Duration(days: 7),
          ), // Countdown: no badge pop-ups
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            userId: 'u1',
            controller: buildController(
              userRepository: userRepository,
              cravingLogRepository: cravingLogRepository,
            ),
            cravingLogController: buildCravingLogController(),
            aiPlanController: buildAiPlanController(),
            journalController: buildJournalController(),
            relapseController: buildRelapseController(),
            healthBotController: buildHealthBotController(),
            alternativesController: buildAlternativesController(),
            gamificationController: buildGamificationController(
              userRepository: userRepository,
            ),
            communityController: buildCommunityController(),
            knowledgeHubController: buildKnowledgeHubController(),
            reminderController: buildReminderController(),
            trackController: buildTrackController(),
            profileController: buildProfileController(),
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    CravingLog riskLog(RelapseRiskLevel risk) => CravingLog(
      logId: 'risk',
      userId: 'u1',
      cravingIntensity: 9,
      mood: Mood.social,
      triggerCategory: TriggerCategory.socialPressure,
      locationContext: 'Party',
      activity: 'Socialising',
      timestamp: fixedToday.subtract(const Duration(hours: 2)),
      relapseRiskScore: risk,
    );

    testWidgets(
      'a recent high-risk craving shows the banner, which opens Habit Alternatives with that craving\'s context',
      (tester) async {
        final logs = FakeCravingLogRepository();
        await logs.logCraving(riskLog(RelapseRiskLevel.high));

        await pumpDashboard(tester, cravingLogRepository: logs);

        expect(
          find.byKey(const Key('dashboard_high_risk_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('dashboard_first_craving_prompt')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('dashboard_high_risk_banner_action')),
        );
        await tester.pumpAndSettle();

        final screen = tester.widget<HighRiskScreen>(
          find.byType(HighRiskScreen),
        );
        expect(screen.triggerCategory, TriggerCategory.socialPressure);
        expect(screen.mood, Mood.social);
      },
    );

    testWidgets('a low-risk latest craving shows no banner', (tester) async {
      final logs = FakeCravingLogRepository();
      await logs.logCraving(riskLog(RelapseRiskLevel.low));

      await pumpDashboard(tester, cravingLogRepository: logs);

      expect(find.byKey(const Key('dashboard_high_risk_banner')), findsNothing);
      expect(
        find.byKey(const Key('dashboard_weekly_trend_chart')),
        findsOneWidget,
      );
    });

    testWidgets(
      'a user with no cravings sees the first-craving prompt, which opens Log Craving',
      (tester) async {
        await pumpDashboard(
          tester,
          cravingLogRepository: FakeCravingLogRepository(),
        );

        final prompt = find.byKey(const Key('dashboard_first_craving_button'));
        expect(prompt, findsOneWidget);
        expect(
          find.byKey(const Key('dashboard_weekly_trend_chart')),
          findsNothing,
        );

        await tester.ensureVisible(prompt);
        await tester.tap(prompt);
        await tester.pumpAndSettle();

        expect(find.byType(LogCravingScreen), findsOneWidget);
      },
    );

    testWidgets('the progress card toggles between 7 and 30 days', (
      tester,
    ) async {
      final logs = FakeCravingLogRepository();
      await logs.logCraving(riskLog(RelapseRiskLevel.low));
      await pumpDashboard(tester, cravingLogRepository: logs);

      final monthChip = find.byKey(const Key('dashboard_progress_range_month'));
      await tester.ensureVisible(monthChip);
      await tester.tap(monthChip);
      await tester.pumpAndSettle();

      expect(find.text('Last 30 Days'), findsOneWidget);
    });
  });
}

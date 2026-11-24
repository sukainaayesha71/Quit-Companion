import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/tracking/presentation/screens/track_screen.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  testWidgets('loads and shows the stat tiles', (tester) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
        baselineDailyUsage: 10,
      ),
    );
    final cravingLogRepository = FakeCravingLogRepository();
    final dashboardController = DashboardController(
      userRepository,
      FakeUsageLogRepository(),
      cravingLogRepository,
      DashboardStateCalculator(),
    );
    await dashboardController.loadDashboard('u1');
    final trackController = TrackController(
      cravingLogRepository,
      FakeJournalRepository(),
      userRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrackScreen(
          userId: 'u1',
          trackController: trackController,
          dashboardController: dashboardController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track Your Progress'), findsOneWidget);
    expect(find.byKey(const Key('track_total_cravings_tile')), findsOneWidget);
    expect(find.byKey(const Key('track_resisted_tile')), findsOneWidget);
    expect(find.byKey(const Key('track_longest_streak_tile')), findsOneWidget);
    expect(find.text('Trigger Breakdown'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Monthly Summary'), findsOneWidget);
    expect(
      find.byKey(const Key('track_monthly_summary_empty')),
      findsOneWidget,
    );
    expect(find.text('Relapse-risk History'), findsOneWidget);
    expect(find.byKey(const Key('track_risk_history_empty')), findsOneWidget);
  });

  testWidgets('shows monthly totals and persisted risk levels', (tester) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
        baselineDailyUsage: 10,
      ),
    );
    final cravingLogRepository = FakeCravingLogRepository();
    await cravingLogRepository.logCraving(
      CravingLog(
        logId: 'c1',
        userId: 'u1',
        cravingIntensity: 7,
        mood: Mood.stressed,
        triggerCategory: TriggerCategory.stress,
        locationContext: 'Home',
        activity: 'Home',
        timestamp: DateTime(2026, 8, 18),
        relapseRiskScore: RelapseRiskLevel.high,
      ),
    );
    final dashboardController = DashboardController(
      userRepository,
      FakeUsageLogRepository(),
      cravingLogRepository,
      DashboardStateCalculator(),
    );
    await dashboardController.loadDashboard('u1');
    final trackController = TrackController(
      cravingLogRepository,
      FakeJournalRepository(),
      userRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrackScreen(
          userId: 'u1',
          trackController: trackController,
          dashboardController: dashboardController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('1 craving · 0 relapses'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('track_risk_history')),
        matching: find.text('Stress'),
      ),
      findsOneWidget,
    );
    expect(find.text('High Risk'), findsOneWidget);
    expect(find.byKey(const Key('track_risk_history_empty')), findsNothing);
  });
}

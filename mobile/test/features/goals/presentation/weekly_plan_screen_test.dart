import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/goals/domain/weekly_plan_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/goals/presentation/screens/weekly_plan_screen.dart';

class _DelayedUserRepository extends FakeUserRepository {
  final result = Completer<NicotineUser?>();
  @override
  Future<NicotineUser?> getUser(String userId) => result.future;
}

void main() {
  final fixedToday = DateTime(2026, 8, 15);

  AiPlanController buildController(FakeUserRepository userRepository) {
    return AiPlanController(
      userRepository,
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      WeeklyPlanCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
  }

  testWidgets('animates while preparing the plan and stops when loaded', (
    tester,
  ) async {
    final repository = _DelayedUserRepository();
    final controller = buildController(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyPlanScreen(userId: 'u1', controller: controller),
      ),
    );
    await tester.pump();
    expect(find.text('Preparing your quit plan'), findsOneWidget);
    final animation = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byKey(const Key('weekly_plan_loading')),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale;
    final initial = animation.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(animation.value, isNot(initial));
    repository.result.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly_plan_loading')), findsNothing);
    expect(find.byKey(const Key('weekly_plan_goal_0')), findsOneWidget);
  });

  testWidgets('shows a loading indicator, then the computed weekly goals', (
    tester,
  ) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
        primaryMotivation: 'Be healthier for my family',
        personalChallenges: 'Stress at work',
        pastQuitAttempts: 'I need more support',
      ),
    );
    final controller = buildController(userRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyPlanScreen(userId: 'u1', controller: controller),
      ),
    );

    expect(find.byKey(const Key('weekly_plan_loading')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly_plan_loading')), findsNothing);
    expect(find.text('My Quit Plan'), findsOneWidget);
    expect(find.byKey(const Key('quit_plan_overview')), findsOneWidget);
    expect(find.text('Quit all at once'), findsOneWidget);
    expect(find.byKey(const Key('quit_plan_motivation')), findsOneWidget);
    expect(find.byKey(const Key('quit_plan_challenges')), findsOneWidget);
    expect(find.byKey(const Key('quit_plan_past_attempts')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('weekly_plan_actions_heading')),
    );
    expect(find.byKey(const Key('weekly_plan_goal_0')), findsOneWidget);
    expect(find.byKey(const Key('weekly_plan_goal_0')), findsOneWidget);
  });

  testWidgets('shows a generic starter plan when no profile is available', (
    tester,
  ) async {
    final controller = buildController(FakeUserRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyPlanScreen(userId: 'missing-user', controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly_plan_error_text')), findsNothing);
    expect(
      find.text(
        'Starter plan: log your activity to personalize your next steps.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('weekly_plan_goal_0')), findsOneWidget);
  });

  testWidgets('the back button pops the screen', (tester) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
      ),
    );
    final controller = buildController(userRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    WeeklyPlanScreen(userId: 'u1', controller: controller),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('weekly_plan_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(WeeklyPlanScreen), findsNothing);
  });
}

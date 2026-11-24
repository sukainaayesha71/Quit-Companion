import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/relapse/controllers/relapse_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/relapse/domain/restart_plan_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/relapse/presentation/screens/relapse_log_screen.dart';
import 'package:quit_companion/features/relapse/presentation/screens/restart_plan_screen.dart';

void main() {
  final fixedToday = DateTime(2026, 8, 15);

  RelapseController buildController({
    required FakeUserRepository userRepository,
  }) {
    return RelapseController(
      FakeJournalRepository(),
      userRepository,
      FakeCravingLogRepository(),
      RestartPlanCalculator(),
      now: () => fixedToday,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    RelapseController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RelapseLogScreen(userId: 'u1', controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectTrigger(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  testWidgets('renders every field from the approved UI reference', (
    tester,
  ) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
      ),
    );
    await pumpScreen(tester, buildController(userRepository: userRepository));

    expect(find.byKey(const Key('relapse_date_field')), findsOneWidget);
    expect(find.byKey(const Key('relapse_product_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('relapse_trigger_stress')), findsOneWidget);
    expect(
      find.byKey(const Key('relapse_trigger_socialPressure')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('relapse_trigger_boredom')), findsOneWidget);
    expect(find.byKey(const Key('relapse_trigger_other')), findsOneWidget);
    expect(
      find.byKey(const Key('relapse_trigger_afterMeal')),
      findsNothing,
    ); // omitted per approved reference
    expect(find.byKey(const Key('relapse_mood_guilty')), findsOneWidget);
    expect(find.byKey(const Key('relapse_mood_frustrated')), findsOneWidget);
    expect(find.byKey(const Key('relapse_mood_sad')), findsOneWidget);
    expect(find.byKey(const Key('relapse_mood_numb')), findsOneWidget);
    expect(find.byKey(const Key('relapse_notes_field')), findsOneWidget);
    expect(find.byKey(const Key('relapse_submit_button')), findsOneWidget);
  });

  testWidgets(
    'submitting without a trigger/mood selected shows a validation error',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
        ),
      );
      await pumpScreen(tester, buildController(userRepository: userRepository));

      await tester.ensureVisible(
        find.byKey(const Key('relapse_submit_button')),
      );
      await tester.tap(find.byKey(const Key('relapse_submit_button')));
      await tester.pump();

      expect(find.byKey(const Key('relapse_validation_error')), findsOneWidget);
    },
  );

  testWidgets(
    'a successful submission navigates to Module 4\'s RestartPlanScreen',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
        ),
      );
      await pumpScreen(tester, buildController(userRepository: userRepository));

      await selectTrigger(tester, const Key('relapse_trigger_stress'));
      await selectTrigger(tester, const Key('relapse_mood_guilty'));
      await tester.ensureVisible(
        find.byKey(const Key('relapse_submit_button')),
      );
      await tester.tap(find.byKey(const Key('relapse_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(RestartPlanScreen), findsOneWidget);
      expect(
        find.byType(RelapseLogScreen),
        findsNothing,
      ); // pushReplacement, not push
    },
  );

  testWidgets('Back to Dashboard works after the relapse form is disposed', (
    tester,
  ) async {
    final users = FakeUserRepository();
    await users.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
      ),
    );
    final controller = buildController(userRepository: users);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            key: const Key('dashboard_route'),
            body: ElevatedButton(
              key: const Key('open_relapse'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      RelapseLogScreen(userId: 'u1', controller: controller),
                ),
              ),
              child: const Text('Log Relapse'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_relapse')));
    await tester.pumpAndSettle();
    await selectTrigger(tester, const Key('relapse_trigger_stress'));
    await selectTrigger(tester, const Key('relapse_mood_guilty'));
    await tester.ensureVisible(find.byKey(const Key('relapse_submit_button')));
    await tester.tap(find.byKey(const Key('relapse_submit_button')));
    await tester.pumpAndSettle();
    expect(find.byType(RelapseLogScreen), findsNothing);
    expect(find.byType(RestartPlanScreen), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('restart_plan_back_to_dashboard_button')),
    );
    await tester.tap(
      find.byKey(const Key('restart_plan_back_to_dashboard_button')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('dashboard_route')), findsOneWidget);
    expect(find.byType(RestartPlanScreen), findsNothing);
  });

  testWidgets(
    'a Countdown-phase user sees the FR12 precondition error, not a crash',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(2026, 8, 25),
        ),
      );
      await pumpScreen(tester, buildController(userRepository: userRepository));

      await selectTrigger(tester, const Key('relapse_trigger_stress'));
      await selectTrigger(tester, const Key('relapse_mood_guilty'));
      await tester.ensureVisible(
        find.byKey(const Key('relapse_submit_button')),
      );
      await tester.tap(find.byKey(const Key('relapse_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('relapse_error_text')), findsOneWidget);
      expect(find.byType(RestartPlanScreen), findsNothing);
    },
  );
}

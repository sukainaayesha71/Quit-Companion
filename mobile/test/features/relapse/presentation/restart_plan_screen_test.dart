import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/relapse/models/restart_plan.dart';
import 'package:quit_companion/features/relapse/presentation/screens/restart_plan_screen.dart';

void main() {
  const plan = RestartPlan(
    steps: [
      'Try the 4-7-8 breathing technique when cravings hit.',
      'Avoid your usual after-meal smoke spot for the next few days.',
      "Be kind to yourself — one setback doesn't undo your progress.",
    ],
  );

  testWidgets(
    'matches the approved reference: headline, subtext, and every restart-plan step',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RestartPlanScreen(plan: plan, onBackToDashboard: () {}),
        ),
      );

      expect(find.textContaining("Recovery isn't linear"), findsOneWidget);
      expect(
        find.text("Here's your adjusted plan, built just for you."),
        findsOneWidget,
      );
      expect(find.text('Your Restart Plan'), findsOneWidget);
      for (final step in plan.steps) {
        expect(find.text(step), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_circle), findsNWidgets(plan.steps.length));
    },
  );

  testWidgets('the Back to Dashboard button calls onBackToDashboard', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RestartPlanScreen(
          plan: plan,
          onBackToDashboard: () => tapped = true,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('restart_plan_back_to_dashboard_button')),
    );
    await tester.pump();

    expect(tapped, isTrue);
  });
}

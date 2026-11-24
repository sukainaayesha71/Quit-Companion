import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/presentation/screens/alternative_activity_history_screen.dart';
import 'package:quit_companion/features/journal/models/mood.dart';

void main() {
  testWidgets(
    'shows activity timestamps and stored outcomes, including unrecorded outcomes',
    (tester) async {
      final repository = FakeHabitAlternativeAttemptRepository();
      await repository.logAttempt(
        HabitAlternativeAttempt(
          attemptId: 'unanswered',
          userId: 'u1',
          alternativeId: 'breathing',
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          attemptedAt: DateTime(2026, 8, 19, 9, 5),
        ),
      );
      await repository.logAttempt(
        HabitAlternativeAttempt(
          attemptId: 'helped',
          userId: 'u1',
          alternativeId: 'cold_water',
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          attemptedAt: DateTime(2026, 8, 18, 8, 30),
          outcomeHelped: true,
        ),
      );
      final controller = AlternativesController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeActivityHistoryScreen(
            userId: 'u1',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4-7-8 Breathing'), findsOneWidget);
      expect(find.text('Drink Cold Water'), findsOneWidget);
      expect(find.text('2026-08-19 at 09:05'), findsOneWidget);
      expect(find.text('2026-08-18 at 08:30'), findsOneWidget);
      expect(find.text('Outcome: No outcome recorded'), findsOneWidget);
      expect(find.text('Outcome: Helped'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    },
  );
}

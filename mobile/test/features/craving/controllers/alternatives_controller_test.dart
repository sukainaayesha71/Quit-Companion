import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/habit_alternative.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  group('AlternativesController', () {
    test(
      'loadRecommendations ranks the fixed library by trigger/mood and user history',
      () async {
        final controller = AlternativesController(
          FakeHabitAlternativeAttemptRepository(),
        );

        await controller.loadRecommendations(
          userId: 'u1',
          triggerCategory: TriggerCategory.boredom,
          mood: Mood.bored,
        );

        expect(controller.recommendations, hasLength(8));
        expect(
          controller.recommendations.first.category,
          AlternativeCategory.game,
        );
      },
    );

    test(
      'setFilter(null) shows everything; a category filters the list',
      () async {
        final controller = AlternativesController(
          FakeHabitAlternativeAttemptRepository(),
        );
        await controller.loadRecommendations(
          userId: 'u1',
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );

        expect(controller.filteredRecommendations, hasLength(8));

        controller.setFilter(AlternativeCategory.game);
        expect(controller.filteredRecommendations, hasLength(4));
        expect(
          controller.filteredRecommendations.every(
            (a) => a.category == AlternativeCategory.game,
          ),
          isTrue,
        );

        controller.setFilter(null);
        expect(controller.filteredRecommendations, hasLength(8));
      },
    );

    test(
      'selectAlternative logs an attempt for the chosen alternative',
      () async {
        final repository = FakeHabitAlternativeAttemptRepository();
        final controller = AlternativesController(
          repository,
          now: () => DateTime(2026, 8, 19),
        );
        const alternative = HabitAlternative(
          alternativeId: 'breathing',
          title: '4-7-8 Breathing',
          description: 'x',
          category: AlternativeCategory.exercise,
          instructions: 'x',
        );

        await controller.selectAlternative(
          userId: 'u1',
          alternative: alternative,
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );

        expect(repository.attempts, hasLength(1));
        expect(repository.attempts.first.alternativeId, 'breathing');
        expect(repository.attempts.first.userId, 'u1');
      },
    );

    test(
      'recordOutcome records feedback against the most recently selected attempt',
      () async {
        final repository = FakeHabitAlternativeAttemptRepository();
        final controller = AlternativesController(
          repository,
          now: () => DateTime(2026, 8, 19),
        );
        const alternative = HabitAlternative(
          alternativeId: 'breathing',
          title: '4-7-8 Breathing',
          description: 'x',
          category: AlternativeCategory.exercise,
          instructions: 'x',
        );
        await controller.selectAlternative(
          userId: 'u1',
          alternative: alternative,
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );

        await controller.recordOutcome(userId: 'u1', helped: true);

        expect(repository.attempts.single.outcomeHelped, isTrue);
        expect(controller.feedbackMessage, isNotNull);
      },
    );

    test(
      'recorded outcomes immediately update recommendations for the active context',
      () async {
        final controller = AlternativesController(
          FakeHabitAlternativeAttemptRepository(),
          now: () => DateTime(2026, 8, 19),
        );
        await controller.loadRecommendations(
          userId: 'u1',
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );
        const alternative = HabitAlternative(
          alternativeId: 'short_walk',
          title: 'Take a Short Walk',
          description: 'x',
          category: AlternativeCategory.exercise,
          instructions: 'x',
        );
        await controller.selectAlternative(
          userId: 'u1',
          alternative: alternative,
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );
        await controller.recordOutcome(userId: 'u1', helped: true);

        expect(controller.recommendations.first.alternativeId, 'short_walk');
      },
    );

    test(
      'loadAttemptHistory returns the user records newest first without assigning missing outcomes',
      () async {
        final repository = FakeHabitAlternativeAttemptRepository();
        for (final date in [DateTime(2026, 8, 18), DateTime(2026, 8, 19)]) {
          await repository.logAttempt(
            HabitAlternativeAttempt(
              attemptId: date.day.toString(),
              userId: 'u1',
              alternativeId: 'breathing',
              triggerCategory: TriggerCategory.stress,
              mood: Mood.stressed,
              attemptedAt: date,
            ),
          );
        }
        final controller = AlternativesController(repository);

        await controller.loadAttemptHistory('u1');

        expect(controller.attemptHistory.map((attempt) => attempt.attemptId), [
          '19',
          '18',
        ]);
        expect(
          controller.attemptHistory.every(
            (attempt) => attempt.outcomeHelped == null,
          ),
          isTrue,
        );
        expect(controller.isHistoryLoading, isFalse);
      },
    );

    test(
      'a repository failure while logging the attempt is non-fatal',
      () async {
        final repository = FakeHabitAlternativeAttemptRepository()
          ..failWith = Exception('down');
        final controller = AlternativesController(repository);
        const alternative = HabitAlternative(
          alternativeId: 'breathing',
          title: '4-7-8 Breathing',
          description: 'x',
          category: AlternativeCategory.exercise,
          instructions: 'x',
        );

        await controller.selectAlternative(
          userId: 'u1',
          alternative: alternative,
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );
        // No exception thrown — the await above completing is the assertion.
      },
    );
  });
}

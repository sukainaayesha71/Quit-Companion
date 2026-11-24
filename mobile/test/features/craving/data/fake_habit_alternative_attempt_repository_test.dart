import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  test('logAttempt records the attempt with a null outcome', () async {
    final repo = FakeHabitAlternativeAttemptRepository();
    await repo.logAttempt(
      HabitAlternativeAttempt(
        attemptId: 'a1',
        userId: 'u1',
        alternativeId: 'breathing',
        triggerCategory: TriggerCategory.stress,
        mood: Mood.stressed,
        attemptedAt: DateTime(2026, 8, 19),
      ),
    );

    expect(repo.attempts, hasLength(1));
    expect(repo.attempts.first.outcomeHelped, isNull);
  });

  test('recordOutcome updates the matching attempt in place', () async {
    final repo = FakeHabitAlternativeAttemptRepository();
    await repo.logAttempt(
      HabitAlternativeAttempt(
        attemptId: 'a1',
        userId: 'u1',
        alternativeId: 'breathing',
        triggerCategory: TriggerCategory.stress,
        mood: Mood.stressed,
        attemptedAt: DateTime(2026, 8, 19),
      ),
    );

    await repo.recordOutcome(userId: 'u1', attemptId: 'a1', helped: true);

    expect(repo.attempts.single.outcomeHelped, isTrue);
  });

  test(
    'getAttempts returns only the selected user records and preserves unanswered outcomes',
    () async {
      final repo = FakeHabitAlternativeAttemptRepository();
      for (final userId in ['u1', 'u2']) {
        await repo.logAttempt(
          HabitAlternativeAttempt(
            attemptId: userId,
            userId: userId,
            alternativeId: 'breathing',
            triggerCategory: TriggerCategory.stress,
            mood: Mood.stressed,
            attemptedAt: DateTime(2026, 8, 19),
          ),
        );
      }

      final history = await repo.getAttempts('u1');

      expect(history, hasLength(1));
      expect(history.single.userId, 'u1');
      expect(history.single.outcomeHelped, isNull);
    },
  );

  test(
    'logAttempt throws when failWith is set, simulating a Firestore failure',
    () async {
      final repo = FakeHabitAlternativeAttemptRepository()
        ..failWith = Exception('firestore down');

      expect(
        () => repo.logAttempt(
          HabitAlternativeAttempt(
            attemptId: 'a1',
            userId: 'u1',
            alternativeId: 'breathing',
            triggerCategory: TriggerCategory.stress,
            mood: Mood.stressed,
            attemptedAt: DateTime(2026, 8, 19),
          ),
        ),
        throwsException,
      );
    },
  );
}

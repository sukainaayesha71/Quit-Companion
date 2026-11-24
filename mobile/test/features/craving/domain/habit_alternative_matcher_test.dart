import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/domain/habit_alternative_matcher.dart';
import 'package:quit_companion/features/craving/models/habit_alternative.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  group('rankAlternatives', () {
    test(
      'returns every item in the library, never invents or drops content',
      () {
        final ranked = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );

        expect(ranked.map((a) => a.alternativeId).toSet(), {
          'breathing',
          'cold_water',
          'short_walk',
          'bubble_pop',
          'word_puzzle',
          'tap_pop',
          'memory_match',
          'craving_countdown',
        });
      },
    );

    test(
      'stress trigger + stressed mood ranks the calming exercises first',
      () {
        final ranked = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );

        expect(ranked.first.category, AlternativeCategory.exercise);
      },
    );

    test('boredom trigger + bored mood ranks a game first', () {
      final ranked = rankAlternatives(
        triggerCategory: TriggerCategory.boredom,
        mood: Mood.bored,
      );

      expect(ranked.first.category, AlternativeCategory.game);
    });

    test('afterMeal trigger ranks the quick-fix item first', () {
      final ranked = rankAlternatives(
        triggerCategory: TriggerCategory.afterMeal,
        mood: Mood.happy,
      );

      expect(ranked.first.alternativeId, 'cold_water');
    });

    test(
      'ranking is a fixed deterministic function — identical inputs always produce identical order',
      () {
        final first = rankAlternatives(
          triggerCategory: TriggerCategory.socialPressure,
          mood: Mood.social,
        );
        final second = rankAlternatives(
          triggerCategory: TriggerCategory.socialPressure,
          mood: Mood.social,
        );

        expect(
          first.map((a) => a.alternativeId),
          second.map((a) => a.alternativeId),
        );
      },
    );

    test(
      'helpful outcomes in a matching context improve an alternative rank',
      () {
        final history = List.generate(
          6,
          (index) =>
              _attempt(index: index, alternativeId: 'short_walk', helped: true),
        );

        final baseline = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );
        final personalized = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          attemptHistory: history,
        );

        expect(
          baseline.indexWhere((item) => item.alternativeId == 'short_walk'),
          greaterThan(
            baseline.indexWhere((item) => item.alternativeId == 'breathing'),
          ),
        );
        expect(personalized.first.alternativeId, 'short_walk');
      },
    );

    test(
      'unhelpful outcomes in a matching context lower an alternative rank',
      () {
        final history = List.generate(
          6,
          (index) =>
              _attempt(index: index, alternativeId: 'breathing', helped: false),
        );

        final baseline = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );
        final personalized = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          attemptHistory: history,
        );

        expect(baseline.first.alternativeId, 'breathing');
        expect(personalized.first.alternativeId, isNot('breathing'));
      },
    );

    test(
      'attempts without outcome feedback do not change contextual ranking',
      () {
        final baseline = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
        );
        final withoutFeedback = rankAlternatives(
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          attemptHistory: [_attempt(index: 1, alternativeId: 'short_walk')],
        );

        expect(
          withoutFeedback.map((item) => item.alternativeId),
          baseline.map((item) => item.alternativeId),
        );
      },
    );
  });
}

HabitAlternativeAttempt _attempt({
  required int index,
  required String alternativeId,
  bool? helped,
}) {
  return HabitAlternativeAttempt(
    attemptId: '$index',
    userId: 'u1',
    alternativeId: alternativeId,
    triggerCategory: TriggerCategory.stress,
    mood: Mood.stressed,
    attemptedAt: DateTime(2026, 8, index + 1),
    outcomeHelped: helped,
  );
}

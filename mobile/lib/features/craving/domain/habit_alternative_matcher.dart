import 'package:quit_companion/features/craving/data/habit_alternative_library.dart';
import 'package:quit_companion/features/craving/models/habit_alternative.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

/// Ranks only the fixed, pre-vetted content library. Current trigger/mood
/// relevance is combined locally with stored outcome feedback; no external
/// AI service is called and no advice text is generated.
List<HabitAlternative> rankAlternatives({
  required TriggerCategory triggerCategory,
  required Mood mood,
  List<HabitAlternativeAttempt> attemptHistory = const [],
  List<HabitAlternative> library = habitAlternativeLibrary,
}) {
  double score(HabitAlternative alternative) {
    var value = 0;
    switch (triggerCategory) {
      case TriggerCategory.stress:
      case TriggerCategory.socialPressure:
        if (alternative.category == AlternativeCategory.exercise) value += 2;
        break;
      case TriggerCategory.boredom:
        if (alternative.category == AlternativeCategory.game) value += 2;
        break;
      case TriggerCategory.afterMeal:
        if (alternative.category == AlternativeCategory.quickFix) value += 2;
        break;
      case TriggerCategory.other:
        break;
    }

    switch (mood) {
      case Mood.stressed:
      case Mood.sad:
        if (alternative.category == AlternativeCategory.exercise) value += 1;
        break;
      case Mood.bored:
        if (alternative.category == AlternativeCategory.game) value += 1;
        break;
      case Mood.happy:
      case Mood.social:
        break;
    }

    return value +
        _personalAdjustment(
          alternative: alternative,
          triggerCategory: triggerCategory,
          mood: mood,
          attemptHistory: attemptHistory,
        );
  }

  // Keep the authored order for ties so ranking remains deterministic.
  final indexed = library.asMap().entries.toList()
    ..sort((a, b) {
      final scoreComparison = score(b.value).compareTo(score(a.value));
      if (scoreComparison != 0) return scoreComparison;
      return a.key - b.key;
    });
  return indexed.map((entry) => entry.value).toList();
}

double _personalAdjustment({
  required HabitAlternative alternative,
  required TriggerCategory triggerCategory,
  required Mood mood,
  required List<HabitAlternativeAttempt> attemptHistory,
}) {
  var evidenceWeight = 0.0;
  var helpedWeight = 0.0;

  for (final attempt in attemptHistory) {
    if (attempt.alternativeId != alternative.alternativeId ||
        attempt.outcomeHelped == null) {
      continue;
    }

    final contextWeight = _contextWeight(
      attempt: attempt,
      triggerCategory: triggerCategory,
      mood: mood,
    );
    evidenceWeight += contextWeight;
    if (attempt.outcomeHelped!) helpedWeight += contextWeight;
  }

  if (evidenceWeight == 0) return 0;

  // A neutral prior prevents one outcome from dominating the ranking.
  final successRate = (helpedWeight + 1) / (evidenceWeight + 2);
  final confidence = evidenceWeight / (evidenceWeight + 2);
  return (successRate - 0.5) * 6 * confidence;
}

double _contextWeight({
  required HabitAlternativeAttempt attempt,
  required TriggerCategory triggerCategory,
  required Mood mood,
}) {
  final triggerMatches = attempt.triggerCategory == triggerCategory;
  final moodMatches = attempt.mood == mood;
  if (triggerMatches && moodMatches) return 1;
  if (triggerMatches || moodMatches) return 0.5;
  return 0.2;
}

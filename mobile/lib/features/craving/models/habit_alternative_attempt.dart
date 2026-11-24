import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

/// Not an SDD-named entity itself — the SDD's HabitAlternative entity only
/// carries a `successRate` field with no defined source for it. SRDS UC4
/// steps 8-10 require logging the user's selection and Yes/No outcome
/// feedback. The local recommender uses completed outcomes to adjust ranking;
/// attempts without feedback do not affect recommendations.
class HabitAlternativeAttempt {
  final String attemptId;
  final String userId;
  final String alternativeId;
  final TriggerCategory triggerCategory;
  final Mood mood;
  final DateTime attemptedAt;
  final bool? outcomeHelped;

  const HabitAlternativeAttempt({
    required this.attemptId,
    required this.userId,
    required this.alternativeId,
    required this.triggerCategory,
    required this.mood,
    required this.attemptedAt,
    this.outcomeHelped,
  });

  HabitAlternativeAttempt copyWith({bool? outcomeHelped}) {
    return HabitAlternativeAttempt(
      attemptId: attemptId,
      userId: userId,
      alternativeId: alternativeId,
      triggerCategory: triggerCategory,
      mood: mood,
      attemptedAt: attemptedAt,
      outcomeHelped: outcomeHelped ?? this.outcomeHelped,
    );
  }
}

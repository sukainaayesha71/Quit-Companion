import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';

/// HabitAlternativeAttempt persistence (Module 7 — Alternatives & Habit
/// Replacement, FR7). SRDS UC4 steps 8-10: log the selection, then update
/// it with a Yes/No outcome once feedback is given.
abstract class HabitAlternativeAttemptRepository {
  Future<void> logAttempt(HabitAlternativeAttempt attempt);

  Future<void> recordOutcome({
    required String userId,
    required String attemptId,
    required bool helped,
  });

  Future<List<HabitAlternativeAttempt>> getAttempts(String userId);
}

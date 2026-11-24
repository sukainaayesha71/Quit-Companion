import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/craving/data/habit_alternative_attempt_repository.dart';

class FakeHabitAlternativeAttemptRepository
    implements HabitAlternativeAttemptRepository {
  final List<HabitAlternativeAttempt> attempts = [];
  Object? failWith;

  @override
  Future<void> logAttempt(HabitAlternativeAttempt attempt) async {
    if (failWith != null) throw failWith!;
    attempts.add(attempt);
  }

  @override
  Future<void> recordOutcome({
    required String userId,
    required String attemptId,
    required bool helped,
  }) async {
    if (failWith != null) throw failWith!;
    final index = attempts.indexWhere(
      (a) => a.userId == userId && a.attemptId == attemptId,
    );
    if (index == -1) return;
    attempts[index] = attempts[index].copyWith(outcomeHelped: helped);
  }

  @override
  Future<List<HabitAlternativeAttempt>> getAttempts(String userId) async {
    if (failWith != null) throw failWith!;
    return attempts.where((attempt) => attempt.userId == userId).toList();
  }
}

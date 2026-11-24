import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/craving/data/habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/models/mood.dart';

/// Real Firestore implementation (Module 7), mirrors
/// FirestoreHealthBotRepository's per-user-subcollection pattern:
/// nicotineUsers/{userId}/habitAlternativeAttempts/{attemptId}. Requires
/// the matching Firestore rules subcollection block.
class FirestoreHabitAlternativeAttemptRepository
    implements HabitAlternativeAttemptRepository {
  final FirebaseFirestore _firestore;

  FirestoreHabitAlternativeAttemptRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _attemptsFor(String userId) =>
      _firestore
          .collection('nicotineUsers')
          .doc(userId)
          .collection('habitAlternativeAttempts');

  @override
  Future<void> logAttempt(HabitAlternativeAttempt attempt) async {
    await _attemptsFor(attempt.userId).doc(attempt.attemptId).set({
      'alternativeId': attempt.alternativeId,
      'triggerCategory': attempt.triggerCategory.name,
      'mood': attempt.mood.name,
      'attemptedAt': attempt.attemptedAt.toUtc().toIso8601String(),
      'outcomeHelped': attempt.outcomeHelped,
    });
  }

  @override
  Future<void> recordOutcome({
    required String userId,
    required String attemptId,
    required bool helped,
  }) async {
    await _attemptsFor(userId).doc(attemptId).update({'outcomeHelped': helped});
  }

  @override
  Future<List<HabitAlternativeAttempt>> getAttempts(String userId) async {
    final snapshot = await _attemptsFor(userId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final attemptedAt = data['attemptedAt'];
      return HabitAlternativeAttempt(
        attemptId: doc.id,
        userId: userId,
        alternativeId: data['alternativeId'] as String,
        triggerCategory: TriggerCategory.values.firstWhere(
          (value) => value.name == data['triggerCategory'],
        ),
        mood: Mood.values.firstWhere((value) => value.name == data['mood']),
        attemptedAt: attemptedAt is Timestamp
            ? attemptedAt.toDate()
            : DateTime.parse(attemptedAt as String),
        outcomeHelped: data['outcomeHelped'] as bool?,
      );
    }).toList();
  }
}

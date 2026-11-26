import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';

/// Real Firestore implementation (SDD §6, Module 3), mirrors
/// FirestoreUsageLogRepository's per-user-subcollection pattern:
/// nicotineUsers/{userId}/cravingLogs/{logId}. Requires the matching
/// Firestore rules subcollection block (see Module 3 plan Task 8) — a
/// missing rule here fails the exact same way it did for usageLogs
/// (PERMISSION_DENIED), which is why that task exists explicitly.
class FirestoreCravingLogRepository
    implements CravingLogRepository, LiveCravingLogRepository {
  final FirebaseFirestore _firestore;

  FirestoreCravingLogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsFor(String userId) =>
      _firestore
          .collection('nicotineUsers')
          .doc(userId)
          .collection('cravingLogs');

  @override
  Future<void> deleteLog({required String userId, required String logId}) =>
      _logsFor(userId).doc(logId).delete();

  @override
  Future<void> logCraving(CravingLog log) async {
    await _logsFor(log.userId).doc(log.logId).set({
      'cravingIntensity': log.cravingIntensity,
      'mood': log.mood.name,
      'triggerCategory': log.triggerCategory.name,
      'locationContext': log.locationContext,
      'activity': log.activity,
      'notes': log.notes,
      'timestamp': log.timestamp.toIso8601String(),
      'relapseRiskScore': log.relapseRiskScore.name,
      'riskAssessmentPending': log.riskAssessmentPending,
      // Same field the backend worker writes after re-scoring; omitted when
      // unknown so a re-sent entry can't erase the worker's value.
      if (log.assessmentSource != null)
        'assessmentSource': log.assessmentSource,
      'recoveryContext': log.recoveryContext,
      'nicotineUsedSinceLastCheckin': log.nicotineUsedSinceLastCheckin,
      // Mood-slider ratings (Open Decision 6) — null-safe: older readers
      // (nothing in this codebase yet, but any external tooling) simply
      // see these keys as absent/null, same as any other optional field.
      'moodHappy': log.moodHappy,
      'moodExcited': log.moodExcited,
      'moodEnthusiastic': log.moodEnthusiastic,
      'moodContented': log.moodContented,
      'moodCalm': log.moodCalm,
      'moodIrritable': log.moodIrritable,
      'moodAnxious': log.moodAnxious,
      'moodStressed': log.moodStressed,
      'moodSad': log.moodSad,
      'moodBored': log.moodBored,
    });
  }

  @override
  Future<int> countCravingsResistedSince(String userId, DateTime since) =>
      _countSince(userId, since);

  @override
  Future<int> countLoggedSince(String userId, DateTime since) =>
      _countSince(userId, since);

  @override
  Future<List<CravingLog>> getRecentLogs(String userId, DateTime since) async {
    final snapshot = await _logsFor(userId)
        .where('timestamp', isGreaterThanOrEqualTo: since.toIso8601String())
        .orderBy('timestamp')
        .get();
    return snapshot.docs
        .map((doc) => _fromDoc(userId, doc.id, doc.data()))
        .toList();
  }

  CravingLog _fromDoc(String userId, String logId, Map<String, dynamic> data) {
    return CravingLog(
      logId: logId,
      userId: userId,
      cravingIntensity: (data['cravingIntensity'] as num).toInt(),
      mood: Mood.values.firstWhere((m) => m.name == data['mood']),
      triggerCategory: TriggerCategory.values.firstWhere(
        (t) => t.name == data['triggerCategory'],
      ),
      locationContext: data['locationContext'] as String,
      activity: data['activity'] as String,
      notes: data['notes'] as String?,
      timestamp: DateTime.parse(data['timestamp'] as String),
      relapseRiskScore: RelapseRiskLevel.values.firstWhere(
        (r) => r.name == data['relapseRiskScore'],
      ),
      riskAssessmentPending: data['riskAssessmentPending'] as bool? ?? false,
      assessmentSource: data['assessmentSource'] as String?,
      recoveryContext:
          (data['recoveryContext'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ) ??
          {},
      nicotineUsedSinceLastCheckin:
          data['nicotineUsedSinceLastCheckin'] as bool?,
      // Absent on every record logged before Open Decision 6 — (data['x']
      // as num?) is null for a missing key, never throws, so old records
      // load exactly as before with these fields simply null.
      moodHappy: (data['moodHappy'] as num?)?.toDouble(),
      moodExcited: (data['moodExcited'] as num?)?.toDouble(),
      moodEnthusiastic: (data['moodEnthusiastic'] as num?)?.toDouble(),
      moodContented: (data['moodContented'] as num?)?.toDouble(),
      moodCalm: (data['moodCalm'] as num?)?.toDouble(),
      moodIrritable: (data['moodIrritable'] as num?)?.toDouble(),
      moodAnxious: (data['moodAnxious'] as num?)?.toDouble(),
      moodStressed: (data['moodStressed'] as num?)?.toDouble(),
      moodSad: (data['moodSad'] as num?)?.toDouble(),
      moodBored: (data['moodBored'] as num?)?.toDouble(),
    );
  }

  Future<int> _countSince(String userId, DateTime since) async {
    final snapshot = await _logsFor(
      userId,
    ).where('timestamp', isGreaterThanOrEqualTo: since.toIso8601String()).get();
    return snapshot.docs.length;
  }

  @override
  Stream<void> watchChanges(String userId) =>
      _logsFor(userId).snapshots().map((_) {});
}

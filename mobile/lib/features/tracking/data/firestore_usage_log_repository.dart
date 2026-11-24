import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';
import 'package:quit_companion/features/tracking/data/usage_log_repository.dart';

/// Real Firestore implementation of UsageLogRepository (SDD §6/§7.5).
/// Stored per-user so a single log/day upsert (same logId = same date)
/// never needs a composite index — not wired into main.dart until a
/// configured Firebase project exists, mirroring FirestoreUserRepository.
class FirestoreUsageLogRepository implements UsageLogRepository {
  final FirebaseFirestore _firestore;

  FirestoreUsageLogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsFor(String userId) =>
      _firestore
          .collection('nicotineUsers')
          .doc(userId)
          .collection('usageLogs');

  @override
  Future<void> logUsage(UsageLog log) async {
    await _logsFor(log.userId).doc(log.logId).set({
      'date': log.date.toIso8601String(),
      'actualUsage': log.actualUsage,
      'targetUsage': log.targetUsage,
    });
  }

  @override
  Future<List<UsageLog>> getUsageLogs(String userId) async {
    final snapshot = await _logsFor(userId).get();
    final logs = snapshot.docs.map((doc) {
      final data = doc.data();
      return UsageLog(
        logId: doc.id,
        userId: userId,
        date: DateTime.parse(data['date'] as String),
        actualUsage: (data['actualUsage'] as num).toDouble(),
        targetUsage: (data['targetUsage'] as num).toDouble(),
      );
    }).toList();
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }
}

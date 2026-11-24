import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';

/// In-memory test double. `countCravingsResistedSince` and
/// `countLoggedSince` share one counting rule (logs for [userId] at/after
/// [since]) — "resisted" and "logged" are currently the same set, since
/// every logged craving counts as resisted (see CravingLogRepository doc).
class FakeCravingLogRepository implements CravingLogRepository {
  final List<CravingLog> _logs = [];

  @override
  Future<void> deleteLog({
    required String userId,
    required String logId,
  }) async {
    _logs.removeWhere((log) => log.userId == userId && log.logId == logId);
  }

  @override
  Future<void> logCraving(CravingLog log) async {
    _logs.removeWhere(
      (item) => item.userId == log.userId && item.logId == log.logId,
    );
    _logs.add(log);
  }

  @override
  Future<int> countCravingsResistedSince(String userId, DateTime since) =>
      _countSince(userId, since);

  @override
  Future<int> countLoggedSince(String userId, DateTime since) =>
      _countSince(userId, since);

  @override
  Future<List<CravingLog>> getRecentLogs(String userId, DateTime since) async {
    final logs = _logs
        .where((log) => log.userId == userId && !log.timestamp.isBefore(since))
        .toList();
    logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return logs;
  }

  Future<int> _countSince(String userId, DateTime since) async {
    return _logs
        .where((log) => log.userId == userId && !log.timestamp.isBefore(since))
        .length;
  }
}

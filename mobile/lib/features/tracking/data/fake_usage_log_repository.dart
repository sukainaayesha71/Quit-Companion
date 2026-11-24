import 'package:quit_companion/features/tracking/models/usage_log.dart';
import 'package:quit_companion/features/tracking/data/usage_log_repository.dart';

class FakeUsageLogRepository implements UsageLogRepository {
  final List<UsageLog> _logs = [];

  @override
  Future<void> logUsage(UsageLog log) async {
    _logs.add(log);
  }

  @override
  Future<List<UsageLog>> getUsageLogs(String userId) async {
    final logs = _logs.where((l) => l.userId == userId).toList();
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }
}

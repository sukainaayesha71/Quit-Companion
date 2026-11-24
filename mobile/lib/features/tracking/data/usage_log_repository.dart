import 'package:quit_companion/features/tracking/models/usage_log.dart';

/// SDD §7.5 Log_Usage: Countdown-phase actual-usage logging that feeds
/// FR10's Reduction Streak and FR16's Gradual-phase Money Saved.
abstract class UsageLogRepository {
  Future<void> logUsage(UsageLog log);
  Future<List<UsageLog>> getUsageLogs(String userId);
}

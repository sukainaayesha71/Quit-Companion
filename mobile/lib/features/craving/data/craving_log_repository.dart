import 'package:quit_companion/features/craving/models/craving_log.dart';

/// CravingLog persistence (SDD §6/§7.2, Module 3 — Habit & Trigger
/// Tracking, FR5/FR6). `countCravingsResistedSince` was originally added
/// as a deliberately narrow interface for Module 2's Dashboard (see
/// FakeCravingLogRepository's original doc comment); Module 3 extends it
/// additively — that method's signature/behavior is unchanged, so
/// DashboardController does not need to change.
abstract class CravingLogRepository {
  /// Count of cravings logged (and resisted, i.e. no relapse followed) for
  /// [userId] on or after [since] — typically the Nicotine-Free phase's
  /// EffectiveStart (SDD §7.2). Every logged craving counts: relapse
  /// logging is a separate, explicit act (FR12, Module 5, not built yet).
  Future<int> countCravingsResistedSince(String userId, DateTime since);

  /// Persists a newly-scored craving log (FR6).
  Future<void> logCraving(CravingLog log);

  Future<void> deleteLog({required String userId, required String logId});

  /// Count of craving logs for [userId] at or after [since] — used to feed
  /// the relapse-risk rule's "3+ logs in the last 24h" condition (FR5,
  /// SRDS §5.5.2). Call with `since = now.subtract(Duration(hours: 24))`.
  Future<int> countLoggedSince(String userId, DateTime since);

  /// Full craving-log records for [userId] at or after [since], oldest
  /// first — feeds FR17's `Progress = COLLECT(...)` (Module 4, SDD §7.7),
  /// which needs real trigger/mood history, not just counts.
  Future<List<CravingLog>> getRecentLogs(String userId, DateTime since);
}

abstract interface class LiveCravingLogRepository {
  Stream<void> watchChanges(String userId);
}

/// UC3 offline capture: repositories that queue writes locally can report
/// which craving logs are saved on the device but not yet confirmed by
/// Firestore, so the UI can mark them "waiting to sync".
abstract interface class SyncStatusCravingLogRepository {
  Future<Set<String>> pendingSyncLogIds(String userId);
}

/// SDD §6: supports FR10's Reduction Streak and FR16's Gradual-phase Money
/// Saved. Distinct from CravingLog (craving *events*, Module 3) and from a
/// relapse JournalEntry/RelapseEvent (Nicotine-Free phase only, Module 5).
class UsageLog {
  final String logId;
  final String userId;
  final DateTime date;
  final double actualUsage;
  final double targetUsage;

  const UsageLog({
    required this.logId,
    required this.userId,
    required this.date,
    required this.actualUsage,
    required this.targetUsage,
  });
}

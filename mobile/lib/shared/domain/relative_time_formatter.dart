const _monthAbbrev = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// docs/UI_Design/community 10.png shows relative timestamps ("2h ago").
/// Pure, testable formatter — no other screen in this codebase needed
/// relative time before (every prior module shows an absolute date).
String formatRelativeTime(DateTime timestamp, {required DateTime now}) {
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${_monthAbbrev[timestamp.month - 1]} ${timestamp.day}';
}

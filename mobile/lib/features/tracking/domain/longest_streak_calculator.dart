/// Longest smoke-free gap across the user's whole history: the largest
/// difference in days between consecutive points in
/// [quitDate, ...sorted relapseDates, today]. Relapses are the only
/// negative signal the app persists (JournalEntry.relapseFlag,
/// RelapseController) — this deliberately does not treat a merely-logged
/// craving as breaking a streak, since logging a craving is itself the
/// coping action, not evidence of relapse.
int computeLongestStreakDays({
  required DateTime quitDate,
  required List<DateTime> relapseDates,
  required DateTime today,
}) {
  DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  final points = [
    dateOnly(quitDate),
    ...relapseDates.map(dateOnly),
    dateOnly(today),
  ]..sort();

  var longest = 0;
  for (var i = 1; i < points.length; i++) {
    final gap = points[i].difference(points[i - 1]).inDays;
    if (gap > longest) longest = gap;
  }
  return longest;
}

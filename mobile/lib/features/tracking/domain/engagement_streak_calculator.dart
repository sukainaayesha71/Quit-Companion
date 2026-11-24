/// SDD §7.6: "The daily check-in engagement streak (increments on any app
/// open or craving log) runs identically through both phases and is not
/// the same counter as NicotineFreeDays or the Reduction Streak." No FR
/// number or owning module is assigned to it anywhere in the SDD, and no
/// "app open" event is logged anywhere in this codebase (there is no
/// telemetry/analytics infrastructure at all) — building that from
/// scratch is out of scope here. This calculator instead derives
/// engagement honestly from data the app *already* persists: the caller
/// passes the union of CravingLog and UsageLog dates (both are real,
/// already-logged user activity) as [activityDates] — a documented,
/// narrower proxy for "any app open," not a fabricated metric.
///
/// [today] has no activity yet is given a one-day grace period (the
/// streak still reads as continuing from yesterday) rather than dropping
/// to 0 the instant midnight passes before the user has done anything —
/// a deliberate UX choice, not a literal reading of the pseudocode (which
/// doesn't specify this edge case at all).
int computeEngagementStreak({
  required List<DateTime> activityDates,
  required DateTime today,
}) {
  DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  final days = activityDates.map(dateOnly).toSet();
  if (days.isEmpty) return 0;

  var cursor = dateOnly(today);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

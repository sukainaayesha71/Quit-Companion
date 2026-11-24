import 'package:quit_companion/features/rewards/models/badge.dart';

/// SDD §7.3 Check_Milestones, FR9. The literal pseudocode checks an exact
/// `NicotineFreeDays == threshold` match, which would silently skip a
/// badge if the user doesn't open the app on the exact day a threshold is
/// crossed (e.g. away for a week, comes back on day 10 — day 7's '1 Week
/// Warrior' would never fire under a strict `==` check). This
/// implementation instead does a documented catch-up: every threshold at
/// or below the current [nicotineFreeDays] that isn't already in
/// [alreadyEarned] is awarded, in ascending tier order. Never awarded at
/// all before quitDate is reached — enforced by the caller passing a
/// NicotineFreeState.nicotineFreeDays value, which by construction only
/// exists in the Nicotine-Free phase (see DashboardStateCalculator).
List<BadgeType> checkNewlyEarnedBadges({
  required int nicotineFreeDays,
  required Set<BadgeType> alreadyEarned,
}) {
  return [
    for (final type in BadgeType.values)
      if (nicotineFreeDays >= type.thresholdDays &&
          !alreadyEarned.contains(type))
        type,
  ];
}

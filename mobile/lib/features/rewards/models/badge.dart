/// SDD §6 / SRDS class diagram: Badge(badgeId, userId, badgeType,
/// dateEarned). §7.3's reconciled 6-tier list (FR9), gated on
/// `MAX(quitDate, lastRelapseDate)` — never awarded before quitDate is
/// reached, for any strategy.
enum BadgeType {
  firstDayHero,
  oneWeekWarrior,
  thirtyDayChampion,
  ninetyDayLegend,
  sixMonthHero,
  oneYearChampion,
}

extension BadgeTypeInfo on BadgeType {
  /// Cumulative milestone points are derived from unique earned badges,
  /// so opening the screen again cannot award the same points twice.
  int get points => switch (this) {
    BadgeType.firstDayHero => 10,
    BadgeType.oneWeekWarrior => 50,
    BadgeType.thirtyDayChampion => 150,
    BadgeType.ninetyDayLegend => 300,
    BadgeType.sixMonthHero => 600,
    BadgeType.oneYearChampion => 1200,
  };

  /// SDD §7.3's exact award threshold, in NicotineFreeDays.
  int get thresholdDays => switch (this) {
    BadgeType.firstDayHero => 1,
    BadgeType.oneWeekWarrior => 7,
    BadgeType.thirtyDayChampion => 30,
    BadgeType.ninetyDayLegend => 90,
    BadgeType.sixMonthHero => 180,
    BadgeType.oneYearChampion => 365,
  };

  /// SDD §7.3's exact badge name, verbatim.
  String get label => switch (this) {
    BadgeType.firstDayHero => 'First Day Hero',
    BadgeType.oneWeekWarrior => '1 Week Warrior',
    BadgeType.thirtyDayChampion => '30 Day Champion',
    BadgeType.ninetyDayLegend => '90 Day Legend',
    BadgeType.sixMonthHero => '6 Month Hero',
    BadgeType.oneYearChampion => '1 Year Champion',
  };
}

class Badge {
  final String badgeId;
  final String userId;
  final BadgeType badgeType;
  final DateTime dateEarned;

  const Badge({
    required this.badgeId,
    required this.userId,
    required this.badgeType,
    required this.dateEarned,
  });
}

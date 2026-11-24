/// Recovery-journey milestones shown on the Nicotine-Free hero card and the
/// milestone/reward card (docs/UI_Design/dashboard 5.png). Purely a
/// presentation-layer breakdown of NicotineFreeState.nicotineFreeDays — adds
/// no new domain concept and requires no DashboardStateCalculator change.
class DashboardMilestone {
  final String shortLabel;
  final String rewardLabel;
  final int thresholdDays;

  const DashboardMilestone({
    required this.shortLabel,
    required this.rewardLabel,
    required this.thresholdDays,
  });
}

const List<DashboardMilestone> kDashboardMilestones = [
  DashboardMilestone(
    shortLabel: '24h',
    rewardLabel: '24-Hour Milestone',
    thresholdDays: 1,
  ),
  DashboardMilestone(
    shortLabel: '3 days',
    rewardLabel: '3-Day Milestone',
    thresholdDays: 3,
  ),
  DashboardMilestone(
    shortLabel: '1 week',
    rewardLabel: '1-Week Warrior',
    thresholdDays: 7,
  ),
  DashboardMilestone(
    shortLabel: '1 month',
    rewardLabel: '1-Month Milestone',
    thresholdDays: 30,
  ),
];

/// The first not-yet-reached milestone, or null once every milestone in
/// [kDashboardMilestones] has been reached.
DashboardMilestone? nextDashboardMilestone(int nicotineFreeDays) {
  for (final milestone in kDashboardMilestones) {
    if (nicotineFreeDays < milestone.thresholdDays) return milestone;
  }
  return null;
}

/// Progress (0.0-1.0) from the previous milestone threshold toward [milestone].
double dashboardMilestoneProgress(
  int nicotineFreeDays,
  DashboardMilestone milestone,
) {
  final index = kDashboardMilestones.indexOf(milestone);
  final previousThreshold = index <= 0
      ? 0
      : kDashboardMilestones[index - 1].thresholdDays;
  final span = milestone.thresholdDays - previousThreshold;
  if (span <= 0) return 1.0;
  return ((nicotineFreeDays - previousThreshold) / span).clamp(0.0, 1.0);
}

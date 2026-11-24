import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_milestones.dart';

/// The 24h -> 3 days -> 1 week -> 1 month strip inside the hero card
/// (docs/UI_Design/dashboard 5.png). Purely derived from nicotineFreeDays.
class MilestoneTimeline extends StatelessWidget {
  final int nicotineFreeDays;

  const MilestoneTimeline({super.key, required this.nicotineFreeDays});

  @override
  Widget build(BuildContext context) {
    final next = nextDashboardMilestone(nicotineFreeDays);
    return Row(
      children: [
        for (var i = 0; i < kDashboardMilestones.length; i++) ...[
          if (i != 0)
            Expanded(
              child: Container(
                height: 2,
                color: nicotineFreeDays >= kDashboardMilestones[i].thresholdDays
                    ? AppColors.sage
                    : AppColors.border,
              ),
            ),
          _MilestoneNode(
            milestone: kDashboardMilestones[i],
            reached: nicotineFreeDays >= kDashboardMilestones[i].thresholdDays,
            isNext: identical(kDashboardMilestones[i], next),
          ),
        ],
      ],
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  final DashboardMilestone milestone;
  final bool reached;
  final bool isNext;

  const _MilestoneNode({
    required this.milestone,
    required this.reached,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached ? AppColors.sage : Colors.transparent,
              border: Border.all(
                color: reached
                    ? AppColors.sage
                    : (isNext ? AppColors.terracotta : AppColors.border),
                width: isNext && !reached ? 2 : 1.5,
              ),
            ),
            child: reached
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            milestone.shortLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: reached || isNext ? FontWeight.w600 : FontWeight.w400,
              color: reached ? AppColors.sageDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

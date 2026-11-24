import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_milestones.dart';

/// "N more days to [milestone]" card (docs/UI_Design/dashboard 5.png).
/// Entirely derived from nicotineFreeDays — no invented percentages.
class MilestoneProgressCard extends StatelessWidget {
  final int nicotineFreeDays;

  const MilestoneProgressCard({super.key, required this.nicotineFreeDays});

  @override
  Widget build(BuildContext context) {
    final next = nextDashboardMilestone(nicotineFreeDays);
    final progress = next == null
        ? 1.0
        : dashboardMilestoneProgress(nicotineFreeDays, next);
    final title = next == null
        ? "You've reached every milestone! 🎉"
        : '${next.thresholdDays - nicotineFreeDays} more day${next.thresholdDays - nicotineFreeDays == 1 ? '' : 's'} to ${next.rewardLabel} 🏆';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.terracottaLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.terracottaDark,
                  size: 22,
                ),
              ),
              const Positioned(
                top: -4,
                right: -4,
                child: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AppColors.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.terracotta,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

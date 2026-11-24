import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/milestone_timeline.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

/// Hero card for NicotineFreeState (docs/UI_Design/dashboard 5.png): big
/// day count, "Since [date]" caption, and the milestone timeline strip.
///
/// [sinceDate] is derived by the caller as `today - nicotineFreeDays`
/// (DashboardController doesn't expose the user's actual quitDate/
/// lastRelapseDate to the UI, and this screen must not be changed to add
/// that — see conversation decision on keeping DashboardController
/// unchanged). The derived date is accurate to the day for a dashboard
/// viewed same-day.
class NicotineFreeHeroCard extends StatelessWidget {
  final int nicotineFreeDays;
  final DateTime sinceDate;

  const NicotineFreeHeroCard({
    super.key,
    required this.nicotineFreeDays,
    required this.sinceDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard_nicotine_free_days'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.terracotta, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(
                  Icons.wb_sunny_rounded,
                  color: AppColors.terracotta.withValues(alpha: 0.55),
                  size: 28,
                ),
              ),
              Text(
                '$nicotineFreeDays',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: AppColors.terracotta,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Nicotine-Free Day${nicotineFreeDays == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Since ${_formatDate(sinceDate)}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          MilestoneTimeline(nicotineFreeDays: nicotineFreeDays),
        ],
      ),
    );
  }
}

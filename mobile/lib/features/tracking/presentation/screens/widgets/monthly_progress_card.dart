import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';

class MonthlyProgressCard extends StatelessWidget {
  final List<TrackMonthlySummary> summaries;

  const MonthlyProgressCard({super.key, required this.summaries});

  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('track_monthly_summaries'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (summaries.isEmpty)
            const Text(
              'Monthly summaries will appear after you log cravings or journal a relapse.',
              key: Key('track_monthly_summary_empty'),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            for (final (index, summary) in summaries.indexed) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      '${_months[summary.month.month - 1]} ${summary.month.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${summary.cravingCount} craving${summary.cravingCount == 1 ? '' : 's'}'
                      ' · ${summary.relapseCount} relapse${summary.relapseCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (index != summaries.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
            ],
        ],
      ),
    );
  }
}

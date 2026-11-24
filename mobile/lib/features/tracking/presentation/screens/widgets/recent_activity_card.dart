import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

class RecentActivityCard extends StatelessWidget {
  final List<TrackActivityItem> items;
  const RecentActivityCard({super.key, required this.items});

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Row(
              key: const Key('track_recent_activity_empty'),
              children: const [
                Icon(Icons.history, color: AppColors.textSecondary, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Log a craving to start building your activity history.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            )
          else
            for (final item in items) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: item.isRelapse
                          ? AppColors.terracottaLight
                          : AppColors.sageLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isRelapse
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: item.isRelapse
                          ? AppColors.terracottaDark
                          : AppColors.sageDark,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _formatDate(item.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (item != items.last)
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

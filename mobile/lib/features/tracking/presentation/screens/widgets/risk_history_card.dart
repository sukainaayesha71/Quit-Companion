import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';

class RiskHistoryCard extends StatelessWidget {
  final List<TrackRiskHistoryItem> items;

  const RiskHistoryCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('track_risk_history'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Relapse-risk History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              'Saved risk levels will appear here when you log a craving.',
              key: Key('track_risk_history_empty'),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            for (final (index, item) in items.indexed) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.triggerCategory.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${item.date.month}/${item.date.day}/${item.date.year}',
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
                      item.pending
                          ? 'Assessment pending'
                          : '${_label(item.riskLevel)} Risk',
                      style: TextStyle(
                        color: _color(item.riskLevel),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (index != items.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
            ],
        ],
      ),
    );
  }

  String _label(RelapseRiskLevel level) => switch (level) {
    RelapseRiskLevel.low => 'Low',
    RelapseRiskLevel.medium => 'Medium',
    RelapseRiskLevel.high => 'High',
  };

  Color _color(RelapseRiskLevel level) => switch (level) {
    RelapseRiskLevel.low => AppColors.sageDark,
    RelapseRiskLevel.medium => AppColors.terracotta,
    RelapseRiskLevel.high => AppColors.error,
  };
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// FR4 / UC6: shown at the top of the Dashboard when the user's most recent
/// craving (within the last 24 hours) was scored high risk — see
/// DashboardController.recentHighRiskLog. Leads straight to Habit
/// Alternatives (Module 7's HighRiskScreen), the same place a high-risk
/// craving log routes to, so a user who skipped it then can come back.
class HighRiskBanner extends StatelessWidget {
  final VoidCallback onTryAlternative;

  const HighRiskBanner({super.key, required this.onTryAlternative});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'High craving risk',
      child: Container(
        key: const Key('dashboard_high_risk_banner'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.terracottaLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.terracotta.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.terracottaDark,
                  size: 26,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'High craving risk right now',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.terracottaDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your latest craving was rated high risk. A quick '
                        'healthy activity can help it pass.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('dashboard_high_risk_banner_action'),
                onPressed: onTryAlternative,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.terracottaDark,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.self_improvement_rounded, size: 20),
                label: const Text('Try an alternative'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

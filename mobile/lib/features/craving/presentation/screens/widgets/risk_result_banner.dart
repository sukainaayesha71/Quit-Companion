import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/craving/presentation/screens/widgets/prediction_source_label.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

/// Post-submission result (FR5). Per the approved Module 3 plan's Open
/// Decision 3: shows only the risk level and a generic, non-clinical,
/// non-fabricated message — the SRDS decision table's High-Risk actions
/// (suggest alternative activity, push notification, community support)
/// all point at features that don't exist yet (Alternatives, Notification,
/// Community modules) and are intentionally not referenced here.
class RiskResultBanner extends StatelessWidget {
  final RelapseRiskLevel riskLevel;
  final VoidCallback onDone;
  final bool assessmentPending;

  /// Which method produced [riskLevel] (backend-reported). Hidden while the
  /// assessment is pending or when unknown.
  final PredictionSource? predictionSource;

  const RiskResultBanner({
    super.key,
    required this.riskLevel,
    required this.onDone,
    this.assessmentPending = false,
    this.predictionSource,
  });

  @override
  Widget build(BuildContext context) {
    final (label, message, color, icon) = switch (riskLevel) {
      RelapseRiskLevel.low => (
        'Low Risk',
        'Log saved. Keep going!', // SRDS §5.5.2 pseudocode, verbatim
        AppColors.sage,
        Icons.check_circle_outline,
      ),
      RelapseRiskLevel.medium => (
        'Medium Risk',
        'Craving logged. Consider taking a short break.',
        AppColors.terracotta,
        Icons.info_outline,
      ),
      RelapseRiskLevel.high => (
        'High Risk',
        "This one felt intense. You've made it through cravings before — this will pass too.",
        AppColors.error,
        Icons.warning_amber_rounded,
      ),
    };

    return Column(
      key: const Key('craving_risk_result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                assessmentPending ? 'Craving Saved' : label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                assessmentPending
                    ? 'Your entry is saved. The risk assessment will update when the service is reachable.'
                    : message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (!assessmentPending) ...[
                const SizedBox(height: 12),
                PredictionSourceLabel(source: predictionSource),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('craving_result_done_button'),
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

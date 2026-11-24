import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

/// ML integration fix (2026-11-23): shows which method actually produced a
/// craving's risk level, as reported by the backend — "ML (Experimental)",
/// "Rule-based", or "Rule-based (ML unavailable)" for a fallback. Renders
/// nothing when the source wasn't reported (older backend) or unknown.
class PredictionSourceLabel extends StatelessWidget {
  final PredictionSource? source;

  const PredictionSourceLabel({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final label = source?.label;
    if (label == null) return const SizedBox.shrink();
    final isMl = source == PredictionSource.machineLearning;
    return Semantics(
      label: 'Scored by $label',
      excludeSemantics: true,
      child: Container(
        key: const Key('craving_prediction_source'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isMl ? AppColors.terracottaLight : AppColors.sageLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMl ? Icons.science_outlined : Icons.rule_rounded,
              size: 15,
              color: isMl ? AppColors.terracottaDark : AppColors.sageDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Scored by: $label',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMl ? AppColors.terracottaDark : AppColors.sageDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/dashboard/domain/health_recovery_milestones.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';

/// Sourced recovery milestones shown during both the countdown and
/// nicotine-free phases.
///
class HealthRecoveryCard extends StatelessWidget {
  final List<HealthRecoveryMilestone> timeline;
  final ProductType? productType;
  final DateTime quitDate;
  final int? daysUntilQuit;
  final int? nicotineFreeDays;

  const HealthRecoveryCard({
    super.key,
    required this.timeline,
    required this.productType,
    required this.quitDate,
    this.daysUntilQuit,
    this.nicotineFreeDays,
  }) : assert((daysUntilQuit == null) != (nicotineFreeDays == null));

  @override
  Widget build(BuildContext context) {
    final title = switch (productType) {
      ProductType.cigarettes => 'Cigarette Recovery Timeline',
      ProductType.vape => 'Vaping Recovery Timeline',
      ProductType.pouches => 'Nicotine Pouch Recovery Timeline',
      ProductType.hookah => 'Hookah Recovery Timeline',
      null => 'Nicotine Recovery Timeline',
    };
    final dateText = MaterialLocalizations.of(
      context,
    ).formatMediumDate(quitDate);
    final phaseText = daysUntilQuit != null
        ? daysUntilQuit! == 0
              ? 'Your Quit Day is today. The timeline below is general guidance.'
              : 'Your planned Quit Day is $dateText. These general milestones start after that date.'
        : nicotineFreeDays == 0
        ? 'Your current quit attempt starts today. The milestones below are general guidance.'
        : 'You are $nicotineFreeDays days into your current quit attempt, which started $dateText.';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            phaseText,
            key: const Key('health_recovery_phase_context'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.sageDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'General information, not a prediction of your personal recovery. Recovery varies from person to person.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < timeline.length; index++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.sage,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index < timeline.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              color: AppColors.sageLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeline[index].timeframe,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            timeline[index].description,
                            key: Key(
                              'health_recovery_${timeline[index].sourceTitle}_${timeline[index].timeframe}',
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Source: ${timeline[index].sourceTitle}. ${timeline[index].sourceNote}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            timeline[index].sourceUrl,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.sageDark,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
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

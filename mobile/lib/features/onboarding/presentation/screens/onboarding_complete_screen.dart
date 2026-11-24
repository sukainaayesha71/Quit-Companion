import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_quantity_config.dart';

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
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

String _capitalize(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

/// Step 4 (final) of onboarding: docs/UI_Design's "Tell us about your
/// habit" recap, shown after Goal Selection's "Generate My Plan". Repurposed
/// from the original quit-date-only "You're All Set!" screen to also recap
/// product type and daily usage.
class OnboardingCompleteScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final String? unitLabelOverride;

  const OnboardingCompleteScreen({
    super.key,
    required this.onContinue,
    this.unitLabelOverride,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<OnboardingController>().workingUser;
    final textTheme = Theme.of(context).textTheme;
    final quitDate = user?.quitDate;
    final reductionDays = user?.reductionSchedule?.length;
    final productType = user?.productType;
    final usage = user?.baselineDailyUsage;
    final unitLabel =
        unitLabelOverride ??
        (productType == null
            ? null
            : productQuantityConfigs[productType]?.unitLabel);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.sageLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.sageDark,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tell us about your habit',
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your personalized plan is ready. Every step from here brings '
                'you closer to a nicotine-free life.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (productType != null &&
                        usage != null &&
                        unitLabel != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.sageDark,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Your Habit',
                              style: textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_capitalize(productType.name)} — ${usage.round()} $unitLabel',
                        key: const Key('onboarding_complete_habit_summary'),
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.flag_outlined,
                          color: AppColors.terracotta,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Your Quit Day',
                            style: textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your Quit Day is ${quitDate != null ? _formatDate(quitDate) : quitDate}.'
                      '${reductionDays != null ? ' Reduction plan: $reductionDays days.' : ''}',
                      key: const Key('onboarding_complete_summary'),
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                key: const Key('onboarding_complete_continue_button'),
                onPressed: onContinue,
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

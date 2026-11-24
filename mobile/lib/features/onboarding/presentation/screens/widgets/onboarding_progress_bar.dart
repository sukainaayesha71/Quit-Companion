import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Segmented step indicator shared by every screen in the Product Selection
/// -> Quantity -> Goal -> Habit Summary sequence (docs/UI_Design 4/4a-4d).
class OnboardingProgressBar extends StatelessWidget {
  final int currentStep; // 1-based
  final int totalSteps;

  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final filled = i < currentStep;
        return Expanded(
          child: Container(
            key: Key('onboarding_progress_segment_$i'),
            height: 6,
            margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: filled ? AppColors.sage : AppColors.sageLight,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_back_link.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_header_illustration.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_progress_bar.dart';

/// Shared chrome for every screen in the Product Selection -> Quantity ->
/// Goal Selection sequence: header illustration, white rounded-top card
/// containing the back link, progress bar, heading, screen-specific content,
/// and a full-width bottom button. Matches docs/UI_Design 4/4a-4d's shared
/// structural template.
class OnboardingScaffold extends StatelessWidget {
  final String headerAsset;
  final double headerAspectRatio;
  final int step;
  final int totalSteps;
  final VoidCallback onBack;
  final String heading;
  final Widget content;
  final String buttonLabel;
  final Key buttonKey;
  final VoidCallback? onButtonPressed;

  const OnboardingScaffold({
    super.key,
    required this.headerAsset,
    required this.headerAspectRatio,
    required this.step,
    required this.totalSteps,
    required this.onBack,
    required this.heading,
    required this.content,
    required this.buttonLabel,
    required this.buttonKey,
    required this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          OnboardingHeaderIllustration(
            asset: headerAsset,
            aspectRatio: headerAspectRatio,
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Column(
                          children: [
                            OnboardingBackLink(onTap: onBack),
                            const SizedBox(height: 18),
                            OnboardingProgressBar(
                              currentStep: step,
                              totalSteps: totalSteps,
                            ),
                            const SizedBox(height: 20),
                            Text(heading, style: textTheme.headlineMedium),
                            const SizedBox(height: 24),
                            content,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: ElevatedButton(
                        key: buttonKey,
                        onPressed: onButtonPressed,
                        child: Text(buttonLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

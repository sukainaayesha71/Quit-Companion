import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_back_link.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_progress_bar.dart';

class _GenderOption {
  final Gender gender;
  final String label;
  final IconData icon;
  const _GenderOption(this.gender, this.label, this.icon);
}

const _options = [
  _GenderOption(Gender.female, 'Female', Icons.face_3_outlined),
  _GenderOption(Gender.male, 'Male', Icons.face_6_outlined),
];

/// New first onboarding step (before Product Selection): lets Profile's
/// avatar reflect the user later. Deliberately does NOT reuse
/// OnboardingScaffold/OnboardingHeaderIllustration (both frozen, already
/// device-verified for the 3 screens after this one) — this screen builds
/// its own header illustration instead, so nothing about those shared
/// widgets changes for this feature.
class GenderSelectionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(Gender) onContinue;
  final Gender? initialSelection;

  const GenderSelectionScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    this.initialSelection,
  });

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  Gender? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _GenderHeaderIllustration(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnboardingBackLink(onTap: widget.onBack),
                    const SizedBox(height: 18),
                    const OnboardingProgressBar(currentStep: 1, totalSteps: 5),
                    const SizedBox(height: 20),
                    Text(
                      'Tell us about yourself',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "This helps us personalize your avatar. You can change it later in your profile.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    for (final option in _options) ...[
                      _GenderOptionRow(
                        option: option,
                        selected: _selected == option.gender,
                        onTap: () => setState(() => _selected = option.gender),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      key: const Key('gender_continue_button'),
                      onPressed: _selected == null
                          ? null
                          : () => widget.onContinue(_selected!),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderOptionRow extends StatelessWidget {
  final _GenderOption option;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('gender_option_${option.gender.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.terracotta : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              color: selected ? AppColors.terracotta : AppColors.sageDark,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat, hand-painted "welcome" header — two abstract person silhouettes
/// on a sage banner, echoing the avatar shapes Profile uses later. No new
/// image asset (same reasoning as DashboardBackground/RewardsScreen).
class _GenderHeaderIllustration extends StatelessWidget {
  const _GenderHeaderIllustration();

  Widget _silhouette(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Container(
          width: 52,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('gender_header_illustration'),
      width: double.infinity,
      height: 160,
      color: AppColors.sage,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _silhouette(AppColors.terracottaLight),
          const SizedBox(width: 16),
          _silhouette(Colors.white),
        ],
      ),
    );
  }
}

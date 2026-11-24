import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

class OnboardingBackLink extends StatelessWidget {
  final VoidCallback onTap;
  const OnboardingBackLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('onboarding_back_link'),
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sageDark,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.chevron_left, size: 20),
        label: const Text('Back'),
      ),
    );
  }
}

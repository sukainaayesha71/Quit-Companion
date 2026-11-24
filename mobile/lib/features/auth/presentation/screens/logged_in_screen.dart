import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Temporary post-login placeholder. Module 2 (Dashboard) is out of scope
/// for Module 1 — this screen intentionally shows no dashboard/app data,
/// only confirmation that authentication succeeded.
class LoggedInScreen extends StatelessWidget {
  final String email;
  const LoggedInScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                    Icons.eco_outlined,
                    color: AppColors.sageDark,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Back!',
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "You're logged in as $email.",
                key: const Key('logged_in_summary'),
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your dashboard is on its way — check back soon.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/relapse/models/restart_plan.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// FR17 (Module 4): matches the approved reference,
/// docs/UI_Design/restart plan result screen 12.png — growth illustration,
/// "Recovery isn't linear. Let's try again." headline, "Your Restart Plan"
/// checklist card, "Back to Dashboard" button.
///
/// Displayed after a relapse is saved, replacing the relapse form.
class RestartPlanScreen extends StatelessWidget {
  final RestartPlan plan;
  final VoidCallback onBackToDashboard;

  const RestartPlanScreen({
    super.key,
    required this.plan,
    required this.onBackToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GrowthIllustration(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Recovery isn't linear.\nLet's try again.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Here's your adjusted plan, built just for you.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Restart Plan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final step in plan.steps) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: AppColors.sageDark,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (step != plan.steps.last)
                              const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      key: const Key('restart_plan_back_to_dashboard_button'),
                      onPressed: onBackToDashboard,
                      child: const Text('Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrowthIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.terracottaLight, AppColors.sageLight],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      child: const Center(
        child: Icon(Icons.eco_rounded, color: AppColors.sageDark, size: 56),
      ),
    );
  }
}

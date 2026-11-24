import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// FR15: explicit consent before any FR2 profile data is collected.
class ConsentScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const ConsentScreen({super.key, required this.onContinue});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;
  bool _researchAgreed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.sageLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.privacy_tip_outlined,
                        color: AppColors.sageDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Consent & Privacy',
                        style: textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Before we collect any information about your nicotine use, we need '
                  'your explicit consent. Your data will be anonymized and handled in '
                  'line with our privacy policy.',
                  key: const Key('consent_text'),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: CheckboxListTile(
                    key: const Key('consent_checkbox'),
                    value: _agreed,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      'I have read and agree to the data collection terms.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _agreed = value ?? false),
                  ),
                ),
                CheckboxListTile(
                  key: const Key('research_consent_checkbox'),
                  value: _researchAgreed,
                  title: const Text(
                    'Optional: contribute check-in data to model research',
                  ),
                  subtitle: const Text(
                    'Only coded ratings and nicotine-use outcomes are used. Names, email, chat and notes are excluded. This is not required to use the app.',
                  ),
                  onChanged: (value) =>
                      setState(() => _researchAgreed = value ?? false),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('consent_continue_button'),
                  onPressed: _agreed
                      ? () {
                          context.read<OnboardingController>().recordConsent(
                            true,
                          );
                          context
                              .read<OnboardingController>()
                              .recordResearchConsent(_researchAgreed);
                          widget.onContinue();
                        }
                      : null,
                  child: const Text('Agree & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

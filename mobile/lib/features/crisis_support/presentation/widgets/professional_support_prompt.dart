import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';

/// SRDS 4.2: the gentle prompt shown after repeated high anxiety/sadness
/// ratings. Wording rules: supportive and non-judgmental, describes only
/// what the user themselves reported, never names a condition or implies a
/// diagnosis, and leaves the choice entirely to the user.
class ProfessionalSupportPrompt extends StatelessWidget {
  const ProfessionalSupportPrompt({super.key});

  /// Shows the prompt. Returns true if the user chose to see support
  /// options (the Crisis Support screen has then already been opened and
  /// closed again).
  static Future<bool> show(BuildContext context) async {
    final wantsSupport = await showDialog<bool>(
      context: context,
      builder: (_) => const ProfessionalSupportPrompt(),
    );
    if (wantsSupport == true && context.mounted) {
      await Navigator.of(context).push(CrisisSupportScreen.route());
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('professional_support_prompt'),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(Icons.spa_rounded, color: AppColors.sageDark, size: 32),
      title: const Text(
        'Checking in with you',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
      content: const SingleChildScrollView(
        child: Text(
          "You've rated yourself as feeling very anxious or sad a few times "
          'recently. Feelings like these are common while quitting, and '
          'they matter.\n\n'
          'Talking to a counsellor, doctor or someone you trust can make '
          "things feel lighter. If you'd like, we can show you free, "
          'confidential support lines.',
          key: Key('professional_support_prompt_body'),
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(
          key: const Key('professional_support_prompt_dismiss'),
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const Key('professional_support_prompt_view'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sage,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          child: const Text('See support options'),
        ),
      ],
    );
  }
}

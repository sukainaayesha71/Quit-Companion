import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Register screen's "Continue with Google" button, using the real
/// Google "G" logo mark cropped from docs/UI_Design "register screen 3"
/// (`assets/images/google_g_logo.png`) instead of an approximated
/// colored-letters wordmark. Kept separate from the shared
/// `GoogleSignInButton` (used by Login) so this redesign doesn't touch
/// the Login screen.
class RegisterGoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const RegisterGoogleButton({super.key, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(double.infinity, 56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.sageDark,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/google_g_logo.png',
                  height: 22,
                  width: 22,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Continue with Google',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

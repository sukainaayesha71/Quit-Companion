import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// "── or ──" divider shown above the Google button on Login/Register.
class SocialSignInDivider extends StatelessWidget {
  const SocialSignInDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

/// "Continue with Google" button styled with the official Google mark.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleSignInButton({super.key, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : (onPressed ?? () {}),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.sage),
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

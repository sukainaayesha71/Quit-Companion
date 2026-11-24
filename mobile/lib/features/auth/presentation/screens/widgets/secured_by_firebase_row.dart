import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// "Secured by Firebase Authentication" trust row shown on Login/Register.
class SecuredByFirebaseRow extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const SecuredByFirebaseRow({
    super.key,
    this.label = 'Secured by Firebase Authentication',
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.sageLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.gpp_good,
            color: AppColors.sageDark,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

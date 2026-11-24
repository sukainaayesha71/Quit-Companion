import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Flat sage banner with a couple of leaf accents, echoing the mockup's
/// hand-painted greenery — same hand-painted-not-cropped approach as
/// DashboardBackground/RewardsScreen's illustrations.
class ProfileHeaderBackground extends StatelessWidget {
  const ProfileHeaderBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profile_header_background'),
      color: AppColors.sage,
      child: Stack(
        children: [
          Positioned(
            top: -10,
            left: -10,
            child: Icon(
              Icons.eco,
              size: 64,
              color: AppColors.sageDark.withValues(alpha: 0.4),
            ),
          ),
          Positioned(
            top: 10,
            right: -14,
            child: Icon(
              Icons.eco,
              size: 80,
              color: AppColors.sageDark.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

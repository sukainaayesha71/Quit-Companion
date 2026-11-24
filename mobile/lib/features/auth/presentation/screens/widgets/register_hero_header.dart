import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Register screen's hero header, matching docs/UI_Design "register
/// screen 3" pixel-for-pixel: `assets/images/register_hero.png` is that
/// exact reference art (sunset gradient, birds, walking-couple
/// silhouette, footprints, hill) with only the baked-in title/subtitle
/// text erased, so real Text widgets can sit on top at the same
/// measured position. Kept separate from the shared `AuthHeroHeader`
/// (used by Login) so this redesign doesn't touch the Login screen.
class RegisterHeroHeader extends StatelessWidget {
  const RegisterHeroHeader({super.key});

  // Fractions measured directly off the reference's screen content
  // (534x470 crop): pixel row/column ÷ crop width/height.
  static const double _titleTop = 180 / 470;
  static const double _subtitleTop = 318 / 470;
  static const double _leftInset = 39 / 534;
  static const double _aspectRatio = 534 / 470;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // A fixed SizedBox (width from MediaQuery, height derived from the
    // reference's aspect ratio) instead of AspectRatio+LayoutBuilder:
    // that two-pass sizing combo left a stale ghost frame of this header
    // baked in above the live content on some devices (Impeller/OpenGLES).
    // AuthHeroHeader (Login) uses the same fixed-SizedBox shape and never
    // exhibited the artifact.
    final width = MediaQuery.sizeOf(context).width;
    final height = width / _aspectRatio;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/register_hero.png', fit: BoxFit.cover),
          Positioned(
            top: height * _titleTop,
            left: width * _leftInset,
            right: 16,
            child: Text(
              'Create Your\nAccount',
              style: textTheme.headlineLarge?.copyWith(height: 1.05),
            ),
          ),
          Positioned(
            top: height * _subtitleTop,
            left: width * _leftInset,
            right: 16,
            child: Text(
              "Let's start your recovery journey.",
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

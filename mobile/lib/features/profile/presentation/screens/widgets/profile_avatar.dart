import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Hand-painted circular avatar (no image asset) — a simple flat
/// head+shoulders silhouette, hair shape distinguishing the two variants.
/// Defaults to female when [gender] is null (matches the mockup's only
/// existing illustration, and the app's only pre-gender-field users).
class ProfileAvatar extends StatelessWidget {
  final Gender? gender;
  final double size;

  const ProfileAvatar({super.key, required this.gender, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final isMale = gender == Gender.male;
    return Container(
      key: Key(isMale ? 'profile_avatar_male' : 'profile_avatar_female'),
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size(size, size),
        painter: _AvatarPainter(isMale: isMale),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final bool isMale;
  _AvatarPainter({required this.isMale});

  @override
  void paint(Canvas canvas, Size size) {
    final skinPaint = Paint()..color = AppColors.terracottaLight;
    final hairPaint = Paint()
      ..color = isMale
          ? AppColors.textPrimary.withValues(alpha: 0.75)
          : AppColors.sageDark;
    final shirtPaint = Paint()..color = isMale ? AppColors.sage : Colors.white;

    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()..color = AppColors.sageLight,
    );

    // Shoulders/shirt.
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.62,
        size.width * 0.8,
        size.height * 0.6,
      ),
      3.14159,
      3.14159,
      true,
      shirtPaint,
    );

    // Face.
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.42),
      size.width * 0.22,
      skinPaint,
    );

    // Hair — a fuller arc for the female variant (longer hair), a short cap for male.
    final hairHeight = isMale ? size.height * 0.16 : size.height * 0.34;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.14,
        size.width * 0.52,
        hairHeight * 1.6,
      ),
      3.14159,
      3.14159,
      true,
      hairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.isMale != isMale;
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Sunset-over-hills header shared by Login and Register, styled after
/// docs/UI_Design "login screen 2" / "register screen 3": a warm gradient
/// sky with a walking-figure silhouette, dipping into a sage green hill
/// that the rest of the screen's content sits on.
class AuthHeroHeader extends StatelessWidget {
  final String heading;
  final String subheading;
  final int figureCount;

  const AuthHeroHeader({
    super.key,
    required this.heading,
    required this.subheading,
    this.figureCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: _HillClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomRight,
                  colors: [AppColors.heroSkyTop, AppColors.heroGlow],
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 10,
            child: _WalkingFigures(count: figureCount),
          ),
          const Positioned(top: 18, left: 24, child: _Dots()),
          Positioned(
            left: 24,
            right: 24,
            top: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(subheading, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkingFigures extends StatelessWidget {
  final int count;
  const _WalkingFigures({required this.count});

  @override
  Widget build(BuildContext context) {
    final figure = Icon(
      Icons.directions_walk_rounded,
      size: 96,
      color: AppColors.sageDark.withValues(alpha: 0.55),
    );
    return SizedBox(
      height: 150,
      width: count > 1 ? 120 : 80,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: count > 1
            ? [
                Positioned(left: 0, bottom: 0, child: figure),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Transform.flip(flipX: true, child: figure),
                ),
              ]
            : [figure],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 40,
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: List.generate(5, (i) {
          return Container(
            width: i.isEven ? 4 : 6,
            height: i.isEven ? 4 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (i.isOdd ? AppColors.terracotta : AppColors.sageDark)
                  .withValues(alpha: 0.35),
            ),
          );
        }),
      ),
    );
  }
}

/// Diagonal hill line separating the sunset sky from the sage green base
/// that the rest of the screen sits on.
class _HillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.78,
        size.width,
        size.height * 0.52,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

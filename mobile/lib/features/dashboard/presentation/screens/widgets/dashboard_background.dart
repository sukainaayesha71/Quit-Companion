import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Hand-painted sunrise/countryside scene behind the Dashboard's content
/// card (docs/UI_Design/dashboard 5.png). Built from Flutter primitives
/// rather than cropped from the reference mockup — the reference bakes its
/// own card/nav UI into every region below a thin top sky sliver (see the
/// now-removed mobile/tool/extract_dashboard_background.py), so a
/// screenshot-style crop isn't safe to ship for less-than-full-card states
/// (loading, error, the Countdown/reduction phase). Static and
/// non-interactive; callers should wrap this in IgnorePointer.
class DashboardBackground extends StatelessWidget {
  const DashboardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            const _SkyGradient(),
            Positioned(
              top: h * 0.05,
              right: w * 0.06,
              child: const _Sun(size: 72),
            ),
            Positioned(
              top: h * 0.07,
              left: w * 0.08,
              child: const _Cloud(width: 54, height: 20),
            ),
            Positioned(
              top: h * 0.15,
              right: w * 0.28,
              child: const _Cloud(width: 40, height: 15),
            ),
            Positioned(top: h * 0.10, left: w * 0.04, child: const _Birds()),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: h * 0.44,
              child: const _Hills(),
            ),
          ],
        );
      },
    );
  }
}

class _SkyGradient extends StatelessWidget {
  const _SkyGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.heroSkyTop, AppColors.heroGlow],
        ),
      ),
    );
  }
}

class _Sun extends StatelessWidget {
  final double size;
  const _Sun({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.4,
      height: size * 2.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 8; i++)
            Transform.rotate(
              angle: i * (3.14159265 / 4),
              child: Container(
                width: 3,
                height: size * 1.1,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFDE7C8), AppColors.terracotta],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  final double width;
  final double height;
  const _Cloud({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

class _Birds extends StatelessWidget {
  const _Birds();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 60,
      height: 20,
      child: CustomPaint(painter: _BirdsPainter()),
    );
  }
}

class _BirdsPainter extends CustomPainter {
  const _BirdsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.sageDark.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    void bird(Offset center, double scale) {
      final path = Path()
        ..moveTo(center.dx - 6 * scale, center.dy)
        ..quadraticBezierTo(
          center.dx - 3 * scale,
          center.dy - 4 * scale,
          center.dx,
          center.dy,
        )
        ..quadraticBezierTo(
          center.dx + 3 * scale,
          center.dy - 4 * scale,
          center.dx + 6 * scale,
          center.dy,
        );
      canvas.drawPath(path, paint);
    }

    bird(const Offset(10, 10), 1.0);
    bird(const Offset(30, 4), 0.8);
    bird(const Offset(46, 14), 0.7);
  }

  @override
  bool shouldRepaint(covariant _BirdsPainter oldDelegate) => false;
}

class _Hills extends StatelessWidget {
  const _Hills();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipPath(
          clipper: const _HillClipper(baseFraction: 0.30, waveDepth: 0.05),
          child: Container(color: AppColors.sageLight),
        ),
        ClipPath(
          clipper: const _HillClipper(baseFraction: 0.16, waveDepth: 0.04),
          child: Container(color: AppColors.heroHill),
        ),
        ClipPath(
          clipper: const _HillClipper(baseFraction: 0.02, waveDepth: 0.03),
          child: Container(color: AppColors.sage),
        ),
        const Positioned(left: 8, bottom: 10, child: _Tree(height: 46)),
        const Positioned(left: 34, bottom: 4, child: _Tree(height: 34)),
        const Positioned(right: 14, bottom: 8, child: _Tree(height: 40)),
        Positioned.fill(child: CustomPaint(painter: _PathAndFlowersPainter())),
      ],
    );
  }
}

class _HillClipper extends CustomClipper<Path> {
  final double baseFraction;
  final double waveDepth;
  const _HillClipper({required this.baseFraction, required this.waveDepth});

  @override
  Path getClip(Size size) {
    final base = size.height * baseFraction;
    final amp = size.height * waveDepth;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, base)
      ..quadraticBezierTo(
        size.width * 0.28,
        base - amp,
        size.width * 0.55,
        base + amp * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        base + amp * 1.2,
        size.width,
        base - amp * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _HillClipper oldClipper) =>
      oldClipper.baseFraction != baseFraction ||
      oldClipper.waveDepth != waveDepth;
}

class _Tree extends StatelessWidget {
  final double height;
  const _Tree({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 0.6,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.sageDark.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: height * 0.12,
            height: height * 0.18,
            color: AppColors.sageDark.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

class _PathAndFlowersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..color = AppColors.background.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;

    final trail = Path()
      ..moveTo(size.width * 0.78, size.height)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.7,
        size.width * 0.82,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.3,
        size.width * 0.88,
        size.height * 0.05,
      );
    canvas.drawPath(trail, pathPaint);

    final flowerPaint = Paint()
      ..color = AppColors.terracotta.withValues(alpha: 0.7);
    final flowerCenters = [
      Offset(size.width * 0.94, size.height * 0.18),
      Offset(size.width * 0.7, size.height * 0.55),
      Offset(size.width * 0.9, size.height * 0.4),
    ];
    for (final c in flowerCenters) {
      canvas.drawCircle(c, size.width * 0.012, flowerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathAndFlowersPainter oldDelegate) => false;
}

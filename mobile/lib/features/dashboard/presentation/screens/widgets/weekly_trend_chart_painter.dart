import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Smooth area/line chart for the Dashboard progress card (docs/UI_Design/
/// dashboard 5.png) — daily values, oldest first: 7 for "This Week", 30 for
/// the FR4/UC6 "Last 30 Days" view. Pure presentation: takes whatever
/// counts the caller passes, invents nothing.
class WeeklyTrendChartPainter extends CustomPainter {
  final List<int> values;

  WeeklyTrendChartPainter(this.values) : assert(values.length >= 2);

  /// Above this many points, per-day dots would crowd into a solid band,
  /// so only today's (last) point gets a dot.
  static const _maxDottedPoints = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final stepX = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * stepX,
          size.height - (values[i] / maxValue) * size.height * 0.85,
        ),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      linePath.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    linePath.lineTo(points.last.dx, points.last.dy);

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.sage.withValues(alpha: 0.35),
          AppColors.sage.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.terracotta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = AppColors.terracotta;
    final dotHaloPaint = Paint()..color = AppColors.surface;
    final dotted = points.length <= _maxDottedPoints ? points : [points.last];
    for (final point in dotted) {
      canvas.drawCircle(point, 5, dotHaloPaint);
      canvas.drawCircle(point, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyTrendChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

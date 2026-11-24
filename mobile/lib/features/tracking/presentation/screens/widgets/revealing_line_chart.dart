import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/weekly_trend_chart_painter.dart';

/// Wraps the existing (unmodified) WeeklyTrendChartPainter with a
/// left-to-right reveal animation on first build — the chart itself is
/// reused as-is, only how much of it is clipped-visible animates.
class RevealingLineChart extends StatefulWidget {
  final List<int> values;
  const RevealingLineChart({super.key, required this.values});

  @override
  State<RevealingLineChart> createState() => _RevealingLineChartState();
}

class _RevealingLineChartState extends State<RevealingLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          ClipRect(clipper: _RevealClipper(_controller.value), child: child),
      child: CustomPaint(
        painter: WeeklyTrendChartPainter(widget.values),
        size: Size.infinite,
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double fraction;
  _RevealClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

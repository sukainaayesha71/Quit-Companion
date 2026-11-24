import 'dart:async';
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

enum _BreathPhase { inhale, hold, exhale }

/// A guided 4-7-8 breathing exercise: an expanding/contracting bubble with
/// a friendly face, a live phase label, and a cycle counter. Runs for a
/// fixed 6 cycles (~2 minutes) then celebrates — but the close button
/// works at any point, and leaving early is never treated as a failure
/// (per the approved design, docs/superpowers/specs/2026-08-30-breathing-bubble-game-design.md).
class BreathingBubbleGameScreen extends StatefulWidget {
  const BreathingBubbleGameScreen({super.key});

  @override
  State<BreathingBubbleGameScreen> createState() =>
      _BreathingBubbleGameScreenState();
}

class _BreathingBubbleGameScreenState extends State<BreathingBubbleGameScreen>
    with SingleTickerProviderStateMixin {
  static const _totalCycles = 6;
  static const _inhaleMs = 4000;
  static const _holdMs = 7000;
  static const _exhaleMs = 8000;
  static const _cycleDuration = Duration(
    milliseconds: _inhaleMs + _holdMs + _exhaleMs,
  );

  late final AnimationController _controller;
  int _currentCycle = 1;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleDuration)
      ..addStatusListener(_onStatusChanged)
      ..forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_currentCycle >= _totalCycles) {
      setState(() => _completed = true);
    } else {
      setState(() => _currentCycle++);
      _controller
        ..reset()
        ..forward();
    }
  }

  _BreathPhase _phaseAt(double t) {
    final elapsedMs = t * _cycleDuration.inMilliseconds;
    if (elapsedMs < _inhaleMs) return _BreathPhase.inhale;
    if (elapsedMs < _inhaleMs + _holdMs) return _BreathPhase.hold;
    return _BreathPhase.exhale;
  }

  /// 0.0 (smallest) to 1.0 (largest), eased in/out for the inhale/exhale
  /// segments so the motion feels organic rather than mechanical; held
  /// flat at 1.0 throughout the hold segment.
  double _scaleAt(double t) {
    final elapsedMs = t * _cycleDuration.inMilliseconds;
    if (elapsedMs < _inhaleMs) {
      return Curves.easeInOut.transform(elapsedMs / _inhaleMs);
    }
    if (elapsedMs < _inhaleMs + _holdMs) {
      return 1.0;
    }
    final exhaleElapsed = elapsedMs - _inhaleMs - _holdMs;
    return 1.0 - Curves.easeInOut.transform(exhaleElapsed / _exhaleMs);
  }

  String _labelFor(_BreathPhase phase) => switch (phase) {
    _BreathPhase.inhale => 'Breathe In',
    _BreathPhase.hold => 'Hold',
    _BreathPhase.exhale => 'Breathe Out',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                key: const Key('breathing_bubble_close_button'),
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.sageLight,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
            ),
            Center(
              child: _completed
                  ? _CompletionView(
                      onDone: () => Navigator.of(context).maybePop(),
                    )
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final scale = _scaleAt(_controller.value);
                        final phase = _phaseAt(_controller.value);
                        final size = 140 + scale * 100;
                        final color = Color.lerp(
                          AppColors.sageLight,
                          AppColors.sage,
                          scale,
                        )!;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cycle $_currentCycle of $_totalCycles',
                              key: const Key('breathing_bubble_cycle_counter'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _BreathingBubble(size: size, color: color),
                            const SizedBox(height: 32),
                            Text(
                              _labelFor(phase),
                              key: const Key('breathing_bubble_phase_label'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  final VoidCallback onDone;

  const _CompletionView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('\u{1F33F}', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text(
          'Nice work — 6 calming breaths',
          key: Key('breathing_bubble_completion_message'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('breathing_bubble_done_button'),
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _BreathingBubble extends StatelessWidget {
  final double size;
  final Color color;

  const _BreathingBubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const _BubbleFace(),
    );
  }
}

/// A simple, original, geometric face — two dot eyes and a curved smile,
/// not an image asset and not referencing any existing character. Blinks
/// slowly and randomly purely for warmth; deliberately does not track the
/// breathing phase, so it never competes with the phase label.
class _BubbleFace extends StatefulWidget {
  const _BubbleFace();

  @override
  State<_BubbleFace> createState() => _BubbleFaceState();
}

class _BubbleFaceState extends State<_BubbleFace> {
  bool _blinking = false;
  Timer? _blinkTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    final delay = Duration(seconds: 6 + _random.nextInt(5));
    _blinkTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _blinking = true);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleNextBlink();
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Eye(blinking: _blinking),
            const SizedBox(width: 14),
            _Eye(blinking: _blinking),
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 24,
          height: 12,
          child: CustomPaint(painter: _SmilePainter()),
        ),
      ],
    );
  }
}

class _Eye extends StatelessWidget {
  final bool blinking;

  const _Eye({required this.blinking});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 8,
      height: blinking ? 1 : 8,
      decoration: const BoxDecoration(
        color: AppColors.textPrimary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SmilePainter extends CustomPainter {
  const _SmilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width / 2, size.height, size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SmilePainter oldDelegate) => false;
}

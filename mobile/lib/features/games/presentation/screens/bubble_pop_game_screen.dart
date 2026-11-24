import 'dart:async';
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// A calm, self-paced distraction — bubbles drift slowly upward and pop
/// on tap. Deliberately no timer, no score, no end state (per the
/// approved design, docs/superpowers/specs/2026-08-29-alternatives-mini-games-design.md):
/// the point is to ride out a craving, not add stimulation.
class BubblePopGameScreen extends StatefulWidget {
  const BubblePopGameScreen({super.key});

  @override
  State<BubblePopGameScreen> createState() => _BubblePopGameScreenState();
}

class _FloatingBubbleData {
  final String id;
  final double leftFraction;
  final Duration duration;
  final Color color;
  final double size;

  const _FloatingBubbleData({
    required this.id,
    required this.leftFraction,
    required this.duration,
    required this.color,
    required this.size,
  });
}

class _BubblePopGameScreenState extends State<BubblePopGameScreen> {
  static const _maxConcurrentBubbles = 8;
  static const _colors = [AppColors.sageLight, AppColors.terracottaLight];

  final List<_FloatingBubbleData> _bubbles = [];
  final Random _random = Random();
  Timer? _spawnTimer;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    // First bubble appears immediately so the screen never opens empty;
    // later ones spawn on a slow, randomized interval.
    _bubbles.add(_makeBubble());
    _scheduleNextSpawn();
  }

  _FloatingBubbleData _makeBubble() {
    return _FloatingBubbleData(
      id: 'bubble${_nextId++}',
      leftFraction: _random.nextDouble(),
      duration: Duration(seconds: 8 + _random.nextInt(6)),
      color: _colors[_random.nextInt(_colors.length)],
      size: 48 + _random.nextDouble() * 24,
    );
  }

  void _scheduleNextSpawn() {
    final delay = Duration(milliseconds: 1500 + _random.nextInt(2000));
    _spawnTimer = Timer(delay, () {
      if (!mounted) return;
      if (_bubbles.length < _maxConcurrentBubbles) {
        setState(() => _bubbles.add(_makeBubble()));
      }
      _scheduleNextSpawn();
    });
  }

  void _removeBubble(String id) {
    if (!mounted) return;
    setState(() => _bubbles.removeWhere((b) => b.id == id));
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            for (final bubble in _bubbles)
              _FloatingBubble(
                key: ValueKey(bubble.id),
                data: bubble,
                screenSize: screenSize,
                onFinished: () => _removeBubble(bubble.id),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                key: const Key('bubble_pop_done_button'),
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.sageLight,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animates one bubble floating from just below the bottom of the screen
/// to just above the top over [_FloatingBubbleData.duration], calling
/// [onFinished] either when it reaches the top unpopped or immediately
/// after its tap-triggered pop animation completes.
class _FloatingBubble extends StatelessWidget {
  final _FloatingBubbleData data;
  final Size screenSize;
  final VoidCallback onFinished;

  const _FloatingBubble({
    super.key,
    required this.data,
    required this.screenSize,
    required this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.1, end: -0.2),
      duration: data.duration,
      curve: Curves.linear,
      onEnd: onFinished,
      builder: (context, verticalFraction, child) {
        return Positioned(
          left: data.leftFraction * (screenSize.width - data.size),
          top: verticalFraction * screenSize.height,
          child: child!,
        );
      },
      child: BubblePopBubbleTile(
        color: data.color,
        size: data.size,
        onPopped: onFinished,
      ),
    );
  }
}

/// The tappable bubble itself. Public (not underscore-prefixed) so tests
/// can find any bubble via `find.byType(BubblePopBubbleTile)` without
/// needing to know its randomly-generated id.
class BubblePopBubbleTile extends StatefulWidget {
  final Color color;
  final double size;
  final VoidCallback onPopped;

  const BubblePopBubbleTile({
    super.key,
    required this.color,
    required this.size,
    required this.onPopped,
  });

  @override
  State<BubblePopBubbleTile> createState() => _BubblePopBubbleTileState();
}

class _BubblePopBubbleTileState extends State<BubblePopBubbleTile> {
  bool _popped = false;

  void _handleTap() {
    if (_popped) return;
    HapticFeedback.lightImpact();
    setState(() => _popped = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) widget.onPopped();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _popped ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: _popped ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

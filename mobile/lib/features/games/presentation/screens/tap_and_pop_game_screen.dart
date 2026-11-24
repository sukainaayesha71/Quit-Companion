import 'dart:async';
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

class _Dot {
  final String id;
  final double leftFraction;
  final double topFraction;
  final Color color;

  const _Dot({
    required this.id,
    required this.leftFraction,
    required this.topFraction,
    required this.color,
  });
}

/// A snappy 30-second reflex round: one dot at a time appears at a random
/// position; tap it before it fades to score a point. No penalty for a
/// miss. Ends with a score summary offering Play Again or Done. Distinct
/// from the calm, untimed Bubble Pop game — this one is deliberately
/// timed and scored, per the user's explicit brief for this game.
class TapAndPopGameScreen extends StatefulWidget {
  const TapAndPopGameScreen({super.key});

  @override
  State<TapAndPopGameScreen> createState() => _TapAndPopGameScreenState();
}

class _TapAndPopGameScreenState extends State<TapAndPopGameScreen> {
  static const _roundSeconds = 30;
  static const _dotLifetime = Duration(milliseconds: 1200);

  final Random _random = Random();
  int _score = 0;
  int _secondsRemaining = _roundSeconds;
  bool _roundOver = false;
  _Dot? _currentDot;
  int _nextDotId = 0;

  Timer? _countdownTimer;
  Timer? _dotLifetimeTimer;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    _countdownTimer?.cancel();
    _dotLifetimeTimer?.cancel();
    setState(() {
      _score = 0;
      _secondsRemaining = _roundSeconds;
      _roundOver = false;
    });
    _spawnDot();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _dotLifetimeTimer?.cancel();
        setState(() {
          _roundOver = true;
          _currentDot = null;
        });
      }
    });
  }

  void _spawnDot() {
    _dotLifetimeTimer?.cancel();
    final dot = _Dot(
      id: 'dot${_nextDotId++}',
      leftFraction: 0.1 + _random.nextDouble() * 0.7,
      topFraction: 0.15 + _random.nextDouble() * 0.55,
      color: _random.nextBool() ? AppColors.sage : AppColors.terracotta,
    );
    setState(() => _currentDot = dot);
    _dotLifetimeTimer = Timer(_dotLifetime, () {
      if (!mounted || _roundOver) return;
      _spawnDot(); // missed — no penalty, just move on
    });
  }

  void _popDot(String dotId) {
    if (_currentDot?.id != dotId || _roundOver) return;
    _dotLifetimeTimer?.cancel();
    setState(() => _score++);
    _spawnDot();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _dotLifetimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dot = _currentDot;
            return Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    key: const Key('tap_and_pop_close_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.sageLight,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_secondsRemaining s',
                        key: const Key('tap_and_pop_timer'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Score: $_score',
                        key: const Key('tap_and_pop_score'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_roundOver)
                  Positioned.fill(
                    child: Center(
                      child: _SummaryView(
                        score: _score,
                        onPlayAgain: _startRound,
                        onDone: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  )
                else if (dot != null)
                  Positioned(
                    left: dot.leftFraction * constraints.maxWidth,
                    top: dot.topFraction * constraints.maxHeight,
                    child: TapAndPopDotTile(
                      key: ValueKey(dot.id),
                      color: dot.color,
                      onTap: () => _popDot(dot.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final int score;
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;

  const _SummaryView({
    required this.score,
    required this.onPlayAgain,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('\u{1F389}', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(
          'You popped $score bubbles!',
          key: const Key('tap_and_pop_summary_message'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('tap_and_pop_play_again_button'),
          onPressed: onPlayAgain,
          child: const Text('Play Again'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('tap_and_pop_done_button'),
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Public (not underscore-prefixed) so tests can find the current dot via
/// `find.byType(TapAndPopDotTile)` without knowing its generated id.
class TapAndPopDotTile extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const TapAndPopDotTile({super.key, required this.color, required this.onTap});

  @override
  State<TapAndPopDotTile> createState() => _TapAndPopDotTileState();
}

class _TapAndPopDotTileState extends State<TapAndPopDotTile> {
  bool _popped = false;

  void _handleTap() {
    if (_popped) return;
    setState(() => _popped = true);
    // Let the pop animation actually play before telling the parent to
    // replace this dot — otherwise the parent's setState (which swaps in
    // a brand new dot with a different key) would unmount this widget
    // the same frame the tap happened, and the animation would never be
    // seen. Same reasoning as BubblePopBubbleTile's identical delay.
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _popped ? 1.3 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: _popped ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 64,
            height: 64,
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

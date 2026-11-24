import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

const _messages = [
  "You're doing great — just stay with this feeling.",
  "The urge is already starting to fade.",
  "Every second here makes the next craving easier to beat.",
  "You're stronger than this moment.",
  "Almost there — keep going.",
  "You're about to prove to yourself you can do this.",
];

/// An ambient, passive 3-minute "stay with the craving" challenge — no
/// tapping, no matching, just a filling progress ring and rotating
/// encouraging messages. Reaching the end is success; there is no losing
/// state, and leaving early via the close button is never a failure (per
/// the approved design, docs/superpowers/specs/2026-08-30-craving-countdown-game-design.md).
class CravingCountdownGameScreen extends StatefulWidget {
  const CravingCountdownGameScreen({super.key});

  @override
  State<CravingCountdownGameScreen> createState() =>
      _CravingCountdownGameScreenState();
}

class _CravingCountdownGameScreenState extends State<CravingCountdownGameScreen>
    with SingleTickerProviderStateMixin {
  static const _totalDuration = Duration(seconds: 180);
  static const _segmentSeconds = 30;

  late final AnimationController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addStatusListener(_onStatusChanged)
      ..forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _completed = true);
    }
  }

  void _startChallenge() {
    setState(() => _completed = false);
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _timeRemainingLabel(double t) {
    final remainingSeconds = (_totalDuration.inSeconds * (1 - t)).ceil().clamp(
      0,
      _totalDuration.inSeconds,
    );
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _messageAt(double t) {
    final elapsedSeconds = (_totalDuration.inSeconds * t).floor();
    final index = (elapsedSeconds ~/ _segmentSeconds).clamp(
      0,
      _messages.length - 1,
    );
    return _messages[index];
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
                key: const Key('craving_countdown_close_button'),
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
                      onPlayAgain: _startChallenge,
                      onDone: () => Navigator.of(context).maybePop(),
                    )
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final t = _controller.value;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: CircularProgressIndicator(
                                      value: t,
                                      strokeWidth: 10,
                                      backgroundColor: AppColors.border,
                                      valueColor: const AlwaysStoppedAnimation(
                                        AppColors.sage,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _timeRemainingLabel(t),
                                    key: const Key(
                                      'craving_countdown_time_remaining',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                _messageAt(t),
                                key: const Key('craving_countdown_message'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
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
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;

  const _CompletionView({required this.onPlayAgain, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('\u{1F4AA}', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        const Text(
          'You beat the craving!',
          key: Key('craving_countdown_completion_message'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('craving_countdown_play_again_button'),
          onPressed: onPlayAgain,
          child: const Text('Play Again'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('craving_countdown_done_button'),
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

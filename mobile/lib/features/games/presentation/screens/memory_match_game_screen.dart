import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

const _icons = [
  Icons.air_rounded,
  Icons.favorite_rounded,
  Icons.savings_rounded,
  Icons.eco_rounded,
  Icons.psychology_rounded,
  Icons.calendar_today_rounded,
  Icons.emoji_events_rounded,
  Icons.water_drop_rounded,
];

/// A 4x4 icon memory-matching game themed around quitting/health concepts
/// (lungs, heart, money saved, fresh air, and more). Move counter, no
/// timer (per the approved design,
/// docs/superpowers/specs/2026-08-30-memory-match-game-design.md). [board]
/// is injectable so tests get a fixed, non-shuffled layout; production
/// always omits it and gets a freshly shuffled one each game.
class MemoryMatchGameScreen extends StatefulWidget {
  final List<IconData>? board;

  const MemoryMatchGameScreen({super.key, this.board});

  @override
  State<MemoryMatchGameScreen> createState() => _MemoryMatchGameScreenState();
}

class _MemoryMatchGameScreenState extends State<MemoryMatchGameScreen> {
  late List<IconData> _board;
  final Set<int> _faceUp = {};
  final Set<int> _matched = {};
  int _moves = 0;
  bool _resolving = false;

  bool get _completed => _matched.length == _board.length;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    final board = widget.board ?? ([..._icons, ..._icons]..shuffle(Random()));
    setState(() {
      _board = board;
      _faceUp.clear();
      _matched.clear();
      _moves = 0;
      _resolving = false;
    });
  }

  void _onCardTap(int index) {
    if (_resolving ||
        _faceUp.contains(index) ||
        _matched.contains(index) ||
        _faceUp.length >= 2) {
      return;
    }
    setState(() => _faceUp.add(index));
    if (_faceUp.length < 2) return;

    final indices = _faceUp.toList();
    final isMatch = _board[indices[0]] == _board[indices[1]];
    if (isMatch) {
      setState(() {
        _moves++;
        _matched.addAll(indices);
        _faceUp.clear();
      });
    } else {
      setState(() {
        _moves++;
        _resolving = true;
      });
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _faceUp.clear();
          _resolving = false;
        });
      });
    }
  }

  Widget _buildCard(int index) {
    final isFaceUp = _faceUp.contains(index) || _matched.contains(index);
    final isMatched = _matched.contains(index);
    final color = isMatched
        ? AppColors.sageLight
        : (isFaceUp ? AppColors.surface : AppColors.sage);
    return GestureDetector(
      key: Key('memory_card_$index'),
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(
          isFaceUp ? _board[index] : Icons.help_outline_rounded,
          color: isFaceUp ? AppColors.textPrimary : Colors.white,
          size: isFaceUp ? 28 : 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('memory_match_close_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.sageLight,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                  Flexible(
                    child: Text(
                      'Moves: $_moves',
                      key: const Key('memory_match_move_counter'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_completed)
                Expanded(
                  child: Center(
                    child: _CompletionView(
                      moves: _moves,
                      onPlayAgain: _startGame,
                      onDone: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    itemCount: _board.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemBuilder: (context, index) => _buildCard(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  final int moves;
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;

  const _CompletionView({
    required this.moves,
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
          'You did it in $moves moves!',
          key: const Key('memory_match_completion_message'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('memory_match_play_again_button'),
          onPressed: onPlayAgain,
          child: const Text('Play Again'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('memory_match_done_button'),
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

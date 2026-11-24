import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/games/domain/word_search_generator.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

const _wordBank = [
  'CALM',
  'HOPE',
  'FOCUS',
  'PEACE',
  'STRONG',
  'HEALING',
  'BREATHE',
  'PROGRESS',
];

/// A calm word-search puzzle — find every word in the bank by dragging
/// across it in the grid, at your own pace, no timer. [puzzle] is
/// injectable so tests get a fixed, deterministic layout instead of a
/// freshly randomized one; production always omits it.
class WordSearchGameScreen extends StatefulWidget {
  final WordSearchPuzzle? puzzle;

  const WordSearchGameScreen({super.key, this.puzzle});

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen> {
  late final WordSearchPuzzle _puzzle;
  final Set<String> _foundWords = {};
  final Set<Point<int>> _foundCells = {};
  Point<int>? _startCell;
  List<Point<int>>? _currentSelection;

  @override
  void initState() {
    super.initState();
    _puzzle =
        widget.puzzle ??
        const WordSearchGenerator(
          size: 10,
        ).generate(_wordBank, random: Random());
  }

  Point<int> _cellAt(Offset local, double cellSize) {
    final size = _puzzle.grid.length;
    final col = (local.dx / cellSize).floor().clamp(0, size - 1);
    final row = (local.dy / cellSize).floor().clamp(0, size - 1);
    return Point(row, col);
  }

  List<Point<int>>? _straightLineBetween(Point<int> start, Point<int> end) {
    final dRow = end.x - start.x;
    final dCol = end.y - start.y;
    if (dRow == 0 && dCol == 0) return [start];
    if (dRow != 0 && dCol != 0 && dRow.abs() != dCol.abs()) return null;
    final steps = max(dRow.abs(), dCol.abs());
    final stepRow = dRow == 0 ? 0 : (dRow > 0 ? 1 : -1);
    final stepCol = dCol == 0 ? 0 : (dCol > 0 ? 1 : -1);
    return List.generate(
      steps + 1,
      (i) => Point(start.x + stepRow * i, start.y + stepCol * i),
    );
  }

  bool _pointListEquals(List<Point<int>> a, List<Point<int>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onPanStart(DragStartDetails details, double cellSize) {
    final cell = _cellAt(details.localPosition, cellSize);
    setState(() {
      _startCell = cell;
      _currentSelection = [cell];
    });
  }

  void _onPanUpdate(DragUpdateDetails details, double cellSize) {
    final startCell = _startCell;
    if (startCell == null) return;
    final current = _cellAt(details.localPosition, cellSize);
    final line = _straightLineBetween(startCell, current);
    if (line != null) {
      setState(() => _currentSelection = line);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final selection = _currentSelection;
    if (selection != null) {
      for (final placement in _puzzle.placements) {
        if (_foundWords.contains(placement.word)) continue;
        final matchesForward = _pointListEquals(selection, placement.cells);
        final matchesBackward = _pointListEquals(
          selection,
          placement.cells.reversed.toList(),
        );
        if (matchesForward || matchesBackward) {
          setState(() {
            _foundWords.add(placement.word);
            _foundCells.addAll(placement.cells);
          });
          break;
        }
      }
    }
    setState(() {
      _startCell = null;
      _currentSelection = null;
    });
  }

  Widget _buildCell(int row, int col) {
    final point = Point(row, col);
    final isFound = _foundCells.contains(point);
    final isSelected = _currentSelection?.contains(point) ?? false;
    Color color = AppColors.surface;
    if (isFound) {
      color = AppColors.sageLight;
    } else if (isSelected) {
      color = AppColors.terracottaLight;
    }
    return Container(
      key: Key('word_search_cell_${row}_$col'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        _puzzle.grid[row][col],
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _puzzle.grid.length;
    final allFound = _foundWords.length == _puzzle.placements.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gridDimension = min(constraints.maxWidth - 40, 360.0);
            final cellSize = gridDimension / size;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    key: const Key('word_search_done_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.sageLight,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Find the words',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _wordBank.map((word) {
                      final found = _foundWords.contains(word);
                      return Text(
                        word,
                        key: Key('word_search_word_$word'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: found
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration: found
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onPanStart: (details) => _onPanStart(details, cellSize),
                      onPanUpdate: (details) => _onPanUpdate(details, cellSize),
                      onPanEnd: _onPanEnd,
                      child: SizedBox(
                        width: gridDimension,
                        height: gridDimension,
                        child: Column(
                          children: List.generate(
                            size,
                            (row) => Expanded(
                              child: Row(
                                children: List.generate(
                                  size,
                                  (col) =>
                                      Expanded(child: _buildCell(row, col)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (allFound) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'All done \u{1F389}',
                      key: Key('word_search_all_done_message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sageDark,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

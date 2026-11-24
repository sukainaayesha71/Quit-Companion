import 'dart:math';

/// One word's placement in a WordSearchPuzzle's grid — the ordered list of
/// cells it occupies, start to end, in whichever forward direction it was
/// placed.
class WordPlacement {
  final String word;
  final List<Point<int>> cells;

  const WordPlacement({required this.word, required this.cells});
}

/// A generated, fully-filled word-search grid plus where each requested
/// word ended up. [grid] is row-major (`grid[row][col]`), one uppercase
/// letter per cell — every cell has a letter, whether or not it's part of
/// a placed word.
class WordSearchPuzzle {
  final List<List<String>> grid;
  final List<WordPlacement> placements;

  const WordSearchPuzzle({required this.grid, required this.placements});
}

class WordSearchGenerationException implements Exception {
  final String message;
  WordSearchGenerationException(this.message);

  @override
  String toString() => message;
}

/// Pure, testable word-search grid generator — no I/O, no Flutter
/// dependency (mirrors the WeeklyPlanCalculator/RestartPlanCalculator
/// pattern already used elsewhere in this codebase for pure domain logic).
///
/// Places each word along one of three forward-only directions
/// (horizontal left-to-right, vertical top-to-bottom, diagonal
/// top-left-to-bottom-right) — deliberately no reversed words, to keep
/// this a gentle puzzle rather than a tricky one.
class WordSearchGenerator {
  final int size;

  const WordSearchGenerator({this.size = 10});

  static const _directions = [
    Point(0, 1), // horizontal
    Point(1, 0), // vertical
    Point(1, 1), // diagonal down-right
  ];

  static const _maxAttemptsPerWord = 200;
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static const _maxGridAttempts = 50;

  WordSearchPuzzle generate(List<String> words, {Random? random}) {
    final rng = random ?? Random();

    // A single word occasionally fails to find a spot within
    // _maxAttemptsPerWord tries once earlier words have already claimed
    // some intersecting cells — that's bad luck in this particular
    // layout, not a fundamentally impossible one, so start the whole grid
    // over with fresh random placements rather than giving up on the
    // first word-level failure. Confirmed necessary empirically: a fixed
    // 8-word bank in a 10x10 grid failed to place its longest word about
    // 1 in every ~15 single-grid-attempt runs during testing.
    for (var gridAttempt = 0; gridAttempt < _maxGridAttempts; gridAttempt++) {
      final grid = List.generate(size, (_) => List<String?>.filled(size, null));
      final placements = <WordPlacement>[];
      var succeeded = true;

      for (final rawWord in words) {
        final word = rawWord.toUpperCase();
        final placement = _placeWord(word, grid, rng);
        if (placement == null) {
          succeeded = false;
          break;
        }
        placements.add(placement);
      }

      if (!succeeded) continue;

      final filledGrid = grid
          .map(
            (row) => row
                .map((cell) => cell ?? _alphabet[rng.nextInt(_alphabet.length)])
                .toList(),
          )
          .toList();

      return WordSearchPuzzle(grid: filledGrid, placements: placements);
    }

    throw WordSearchGenerationException(
      'Could not place all ${words.length} words in a $size x $size grid after $_maxGridAttempts full-grid attempts.',
    );
  }

  WordPlacement? _placeWord(String word, List<List<String?>> grid, Random rng) {
    for (var attempt = 0; attempt < _maxAttemptsPerWord; attempt++) {
      final delta = _directions[rng.nextInt(_directions.length)];
      final maxRowStart = size - 1 - delta.x * (word.length - 1);
      final maxColStart = size - 1 - delta.y * (word.length - 1);
      if (maxRowStart < 0 || maxColStart < 0) continue;

      final startRow = rng.nextInt(maxRowStart + 1);
      final startCol = rng.nextInt(maxColStart + 1);

      final cells = List.generate(
        word.length,
        (i) => Point(startRow + delta.x * i, startCol + delta.y * i),
      );

      var fits = true;
      for (var i = 0; i < cells.length; i++) {
        final existing = grid[cells[i].x][cells[i].y];
        if (existing != null && existing != word[i]) {
          fits = false;
          break;
        }
      }
      if (!fits) continue;

      for (var i = 0; i < cells.length; i++) {
        grid[cells[i].x][cells[i].y] = word[i];
      }
      return WordPlacement(word: word, cells: cells);
    }
    return null;
  }
}

# Alternatives Mini-Games Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the two placeholder "game" alternatives (Bubble Pop, Word Puzzle) into real, playable, calm mini-games reached via a new "Play" button on the existing Alternative detail screen.

**Architecture:** Two new, self-contained, stateless-from-the-outside game screens in a new `mobile/lib/screens/games/` folder, plus one new pure/testable domain file for word-search grid generation. No new controller, repository, or Firestore writes — these are ephemeral, session-only distractions with no persisted state of their own.

**Tech Stack:** Flutter/Dart only — `dart:math` (`Point`, `Random`), `dart:async` (`Timer`), core Flutter widgets/gestures/haptics. No new pubspec dependency.

## Global Constraints

- No timer, score, difficulty level, or win/lose state in either game — both are self-paced, leave-whenever-you-want distractions (per the approved design spec, `docs/superpowers/specs/2026-08-29-alternatives-mini-games-design.md`).
- No Firestore writes, no new controller/repository — the existing `AlternativesController.recordOutcome` "Did this help?" logging on `AlternativeDetailScreen` is the only persistence in this flow and is untouched.
- Word Search word bank is exactly: `CALM`, `HOPE`, `FOCUS`, `PEACE`, `STRONG`, `HEALING`, `BREATHE`, `PROGRESS` — forward directions only (horizontal left-to-right, vertical top-to-bottom, diagonal top-left-to-bottom-right); no reversed words.
- Do not delete or weaken any existing test. All new coverage is additive.
- Run `flutter analyze` and the affected test file(s) after every task; run the full `flutter test` suite before the final commit.

---

## Task 1: Word Search grid generator (pure domain logic)

**Files:**
- Create: `mobile/lib/domain/word_search_generator.dart`
- Test: `mobile/test/domain/word_search_generator_test.dart`

**Interfaces:**
- Produces: `WordSearchGenerator` (const constructor `WordSearchGenerator({int size = 10})`, method `WordSearchPuzzle generate(List<String> words, {Random? random})`), `WordPlacement` (`{String word, List<Point<int>> cells}`), `WordSearchPuzzle` (`{List<List<String>> grid, List<WordPlacement> placements}`), `WordSearchGenerationException`. Task 3 (Word Search screen) consumes all four of these by name exactly as given here.

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/domain/word_search_generator_test.dart`:

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/domain/word_search_generator.dart';

void main() {
  const words = ['CALM', 'HOPE', 'FOCUS', 'PEACE', 'STRONG', 'HEALING', 'BREATHE', 'PROGRESS'];

  test('generate places every word somewhere in the grid, in-bounds', () {
    final puzzle = const WordSearchGenerator(size: 10).generate(words, random: Random(1));

    expect(puzzle.placements.map((p) => p.word).toSet(), words.toSet());
    for (final placement in puzzle.placements) {
      expect(placement.cells.length, placement.word.length);
      for (final cell in placement.cells) {
        expect(cell.x, inInclusiveRange(0, 9));
        expect(cell.y, inInclusiveRange(0, 9));
      }
    }
  });

  test('every placed word forms a straight line in an allowed forward direction', () {
    final puzzle = const WordSearchGenerator(size: 10).generate(words, random: Random(2));

    for (final placement in puzzle.placements) {
      final cells = placement.cells;
      if (cells.length < 2) continue;
      final dRow = cells[1].x - cells[0].x;
      final dCol = cells[1].y - cells[0].y;
      // Forward-only: horizontal (0,1), vertical (1,0), or diagonal-down (1,1).
      expect(
        (dRow == 0 && dCol == 1) || (dRow == 1 && dCol == 0) || (dRow == 1 && dCol == 1),
        isTrue,
        reason: 'unexpected direction ($dRow, $dCol) for ${placement.word}',
      );
      for (var i = 1; i < cells.length; i++) {
        expect(cells[i].x - cells[i - 1].x, dRow);
        expect(cells[i].y - cells[i - 1].y, dCol);
      }
    }
  });

  test('the grid letters match each placement\'s word at every one of its cells', () {
    final puzzle = const WordSearchGenerator(size: 10).generate(words, random: Random(3));

    for (final placement in puzzle.placements) {
      for (var i = 0; i < placement.cells.length; i++) {
        final cell = placement.cells[i];
        expect(puzzle.grid[cell.x][cell.y], placement.word[i]);
      }
    }
  });

  test('every non-word cell is filled with a single uppercase letter, never empty', () {
    final puzzle = const WordSearchGenerator(size: 10).generate(words, random: Random(4));

    for (final row in puzzle.grid) {
      for (final cell in row) {
        expect(cell.length, 1);
        expect(cell, cell.toUpperCase());
      }
    }
  });

  test('generation is deterministic for a given seed', () {
    final puzzleA = const WordSearchGenerator(size: 10).generate(words, random: Random(42));
    final puzzleB = const WordSearchGenerator(size: 10).generate(words, random: Random(42));

    expect(puzzleA.grid, puzzleB.grid);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/domain/word_search_generator_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'quit_companion/domain/word_search_generator.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `mobile/lib/domain/word_search_generator.dart`:

```dart
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

  WordSearchPuzzle generate(List<String> words, {Random? random}) {
    final rng = random ?? Random();
    final grid = List.generate(size, (_) => List<String?>.filled(size, null));
    final placements = <WordPlacement>[];

    for (final rawWord in words) {
      final word = rawWord.toUpperCase();
      final placement = _placeWord(word, grid, rng);
      if (placement == null) {
        throw WordSearchGenerationException(
          'Could not place word "$word" in a $size x $size grid after $_maxAttemptsPerWord attempts.',
        );
      }
      placements.add(placement);
    }

    final filledGrid = grid
        .map((row) => row.map((cell) => cell ?? _alphabet[rng.nextInt(_alphabet.length)]).toList())
        .toList();

    return WordSearchPuzzle(grid: filledGrid, placements: placements);
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/domain/word_search_generator_test.dart`
Expected: PASS (5/5).

- [ ] **Step 5: Analyze and commit**

Run: `cd mobile && flutter analyze lib/domain/word_search_generator.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/domain/word_search_generator.dart mobile/test/domain/word_search_generator_test.dart
git commit -m "feat(games): add pure word-search grid generator"
```

---

## Task 2: Bubble Pop game screen

**Files:**
- Create: `mobile/lib/screens/games/bubble_pop_game_screen.dart`
- Test: `mobile/test/screens/bubble_pop_game_screen_test.dart`

**Interfaces:**
- Consumes: `AppColors` from `mobile/lib/theme/app_theme.dart` (fields used: `background`, `sageLight`, `terracottaLight`, `textPrimary`).
- Produces: `BubblePopGameScreen` (public widget, no constructor params beyond `key`), `BubblePopBubbleTile` (public widget — deliberately public, not underscore-prefixed, so tests can find bubbles via `find.byType(BubblePopBubbleTile)`).

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/screens/bubble_pop_game_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/games/bubble_pop_game_screen.dart';

void main() {
  testWidgets('a bubble is present immediately on open', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BubblePopGameScreen()));
    await tester.pump();

    expect(find.byType(BubblePopBubbleTile), findsWidgets);
  });

  testWidgets('tapping a bubble removes it after its pop animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BubblePopGameScreen()));
    await tester.pump();
    final before = find.byType(BubblePopBubbleTile).evaluate().length;
    expect(before, greaterThan(0));

    await tester.tap(find.byType(BubblePopBubbleTile).first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byType(BubblePopBubbleTile).evaluate().length, before - 1);
  });

  testWidgets('the Done button pops the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BubblePopGameScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bubble_pop_done_button')));
    await tester.pumpAndSettle();

    expect(find.byType(BubblePopGameScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/bubble_pop_game_screen_test.dart`
Expected: FAIL — file `lib/screens/games/bubble_pop_game_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `mobile/lib/screens/games/bubble_pop_game_screen.dart`:

```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

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
  static const _colors = [
    AppColors.sageLight,
    AppColors.terracottaLight,
  ];

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
                style: IconButton.styleFrom(backgroundColor: AppColors.sageLight, shape: const CircleBorder()),
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

  const _FloatingBubble({super.key, required this.data, required this.screenSize, required this.onFinished});

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
      child: BubblePopBubbleTile(color: data.color, size: data.size, onPopped: onFinished),
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

  const BubblePopBubbleTile({super.key, required this.color, required this.size, required this.onPopped});

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
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/bubble_pop_game_screen_test.dart`
Expected: PASS (3/3).

- [ ] **Step 5: Analyze and commit**

Run: `cd mobile && flutter analyze lib/screens/games/bubble_pop_game_screen.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/games/bubble_pop_game_screen.dart mobile/test/screens/bubble_pop_game_screen_test.dart
git commit -m "feat(games): add playable Bubble Pop mini-game screen"
```

---

## Task 3: Word Search game screen

**Files:**
- Create: `mobile/lib/screens/games/word_search_game_screen.dart`
- Test: `mobile/test/screens/word_search_game_screen_test.dart`

**Interfaces:**
- Consumes: `WordSearchGenerator`, `WordSearchPuzzle`, `WordPlacement` from Task 1's `mobile/lib/domain/word_search_generator.dart`; `AppColors` from `mobile/lib/theme/app_theme.dart`.
- Produces: `WordSearchGameScreen` (public widget, constructor `WordSearchGameScreen({Key? key, WordSearchPuzzle? puzzle})` — `puzzle` is injectable so tests get a deterministic layout instead of relying on real randomness).

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/screens/word_search_game_screen_test.dart`:

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/domain/word_search_generator.dart';
import 'package:quit_companion/screens/games/word_search_game_screen.dart';

/// A fixed, hand-built puzzle for deterministic tests: CALM placed
/// horizontally on row 0 starting at column 0 (cells (0,0)-(0,3)); every
/// other cell filled with 'X' so no other word can accidentally match.
WordSearchPuzzle _fixedPuzzle() {
  final grid = List.generate(10, (_) => List.filled(10, 'X'));
  const word = 'CALM';
  for (var i = 0; i < word.length; i++) {
    grid[0][i] = word[i];
  }
  return WordSearchPuzzle(
    grid: grid,
    placements: const [
      WordPlacement(word: 'CALM', cells: [Point(0, 0), Point(0, 1), Point(0, 2), Point(0, 3)]),
    ],
  );
}

void main() {
  testWidgets('renders the word bank and the letter grid', (tester) async {
    await tester.pumpWidget(MaterialApp(home: WordSearchGameScreen(puzzle: _fixedPuzzle())));
    await tester.pump();

    expect(find.byKey(const Key('word_search_word_CALM')), findsOneWidget);
    expect(find.byKey(const Key('word_search_cell_0_0')), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('dragging across a placed word\'s cells marks it found', (tester) async {
    await tester.pumpWidget(MaterialApp(home: WordSearchGameScreen(puzzle: _fixedPuzzle())));
    await tester.pump();

    final start = tester.getCenter(find.byKey(const Key('word_search_cell_0_0')));
    final end = tester.getCenter(find.byKey(const Key('word_search_cell_0_3')));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    final wordText = tester.widget<Text>(find.byKey(const Key('word_search_word_CALM')));
    expect(wordText.style?.decoration, TextDecoration.lineThrough);
    expect(find.byKey(const Key('word_search_all_done_message')), findsOneWidget);
  });

  testWidgets('dragging a non-matching line does not mark anything found', (tester) async {
    await tester.pumpWidget(MaterialApp(home: WordSearchGameScreen(puzzle: _fixedPuzzle())));
    await tester.pump();

    final start = tester.getCenter(find.byKey(const Key('word_search_cell_5_5')));
    final end = tester.getCenter(find.byKey(const Key('word_search_cell_5_7')));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    final wordText = tester.widget<Text>(find.byKey(const Key('word_search_word_CALM')));
    expect(wordText.style?.decoration, isNot(TextDecoration.lineThrough));
    expect(find.byKey(const Key('word_search_all_done_message')), findsNothing);
  });

  testWidgets('the Done button pops the screen at any progress state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WordSearchGameScreen(puzzle: _fixedPuzzle())),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('word_search_done_button')));
    await tester.pumpAndSettle();

    expect(find.byType(WordSearchGameScreen), findsNothing);
  });

  testWidgets('with no puzzle injected, generates one from the real word bank', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WordSearchGameScreen()));
    await tester.pump();

    expect(find.byKey(const Key('word_search_word_CALM')), findsOneWidget);
    expect(find.byKey(const Key('word_search_word_PROGRESS')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/word_search_game_screen_test.dart`
Expected: FAIL — file `lib/screens/games/word_search_game_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `mobile/lib/screens/games/word_search_game_screen.dart`:

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/word_search_generator.dart';
import '../../theme/app_theme.dart';

const _wordBank = ['CALM', 'HOPE', 'FOCUS', 'PEACE', 'STRONG', 'HEALING', 'BREATHE', 'PROGRESS'];

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
    _puzzle = widget.puzzle ?? const WordSearchGenerator(size: 10).generate(_wordBank, random: Random());
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
    return List.generate(steps + 1, (i) => Point(start.x + stepRow * i, start.y + stepCol * i));
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
        final matchesBackward = _pointListEquals(selection, placement.cells.reversed.toList());
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
      decoration: BoxDecoration(color: color, border: Border.all(color: AppColors.border, width: 0.5)),
      child: Text(_puzzle.grid[row][col], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    key: const Key('word_search_done_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(backgroundColor: AppColors.sageLight, shape: const CircleBorder()),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text('Find the words', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                          color: found ? AppColors.textSecondary : AppColors.textPrimary,
                          decoration: found ? TextDecoration.lineThrough : TextDecoration.none,
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
                                children: List.generate(size, (col) => Expanded(child: _buildCell(row, col))),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.sageDark),
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/word_search_game_screen_test.dart`
Expected: PASS (5/5).

- [ ] **Step 5: Analyze and commit**

Run: `cd mobile && flutter analyze lib/screens/games/word_search_game_screen.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/games/word_search_game_screen.dart mobile/test/screens/word_search_game_screen_test.dart
git commit -m "feat(games): add playable Word Search mini-game screen"
```

---

## Task 4: Wire "Play" into AlternativeDetailScreen, and reword the game copy

**Files:**
- Modify: `mobile/lib/screens/craving/alternative_detail_screen.dart`
- Modify: `mobile/lib/data/habit_alternative_library.dart:38-52`
- Modify: `mobile/test/screens/alternative_detail_screen_test.dart`

**Interfaces:**
- Consumes: `BubblePopGameScreen` (Task 2), `WordSearchGameScreen` (Task 3), `AlternativeCategory` from `mobile/lib/models/habit_alternative.dart` (already exists).

- [ ] **Step 1: Write the failing tests**

In `mobile/test/screens/alternative_detail_screen_test.dart`, add two new `HabitAlternative` fixtures near the top (after the existing `_alternative` constant) and two new tests at the end of `main()`, right before the final closing `}`:

```dart
const _bubblePopAlternative = HabitAlternative(
  alternativeId: 'bubble_pop',
  title: 'Bubble Pop Mini-Game',
  description: 'A calm, self-paced distraction',
  category: AlternativeCategory.game,
  instructions: 'Open the Bubble Pop mini-game and pop bubbles at your own pace.',
);

const _wordPuzzleAlternative = HabitAlternative(
  alternativeId: 'word_puzzle',
  title: 'Quick Word Puzzle',
  description: 'Keep your hands and mind busy',
  category: AlternativeCategory.game,
  instructions: 'Open the Word Puzzle mini-game and find the hidden calming words.',
);
```

And these two tests inside `main()`, after the existing `'the back button returns to the previous screen'` test:

```dart
  testWidgets('shows a Play button for game-category alternatives, not for others', (tester) async {
    final controller = AlternativesController(FakeHabitAlternativeAttemptRepository());

    await tester.pumpWidget(MaterialApp(
      home: AlternativeDetailScreen(
        userId: 'u1',
        alternative: _alternative, // exercise category
        triggerCategory: TriggerCategory.stress,
        mood: Mood.stressed,
        controller: controller,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alternative_detail_play_button')), findsNothing);
  });

  testWidgets('tapping Play on Bubble Pop opens BubblePopGameScreen', (tester) async {
    final controller = AlternativesController(FakeHabitAlternativeAttemptRepository());

    await tester.pumpWidget(MaterialApp(
      home: AlternativeDetailScreen(
        userId: 'u1',
        alternative: _bubblePopAlternative,
        triggerCategory: TriggerCategory.boredom,
        mood: Mood.bored,
        controller: controller,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alternative_detail_play_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pumpAndSettle();

    expect(find.byType(BubblePopGameScreen), findsOneWidget);
  });

  testWidgets('tapping Play on Quick Word Puzzle opens WordSearchGameScreen', (tester) async {
    final controller = AlternativesController(FakeHabitAlternativeAttemptRepository());

    await tester.pumpWidget(MaterialApp(
      home: AlternativeDetailScreen(
        userId: 'u1',
        alternative: _wordPuzzleAlternative,
        triggerCategory: TriggerCategory.boredom,
        mood: Mood.bored,
        controller: controller,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pumpAndSettle();

    expect(find.byType(WordSearchGameScreen), findsOneWidget);
  });
```

Add these two imports to the top of the test file, alongside the existing imports:

```dart
import 'package:quit_companion/screens/games/bubble_pop_game_screen.dart';
import 'package:quit_companion/screens/games/word_search_game_screen.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart`
Expected: FAIL — `alternative_detail_play_button` key not found (button doesn't exist yet).

- [ ] **Step 3: Write the implementation**

In `mobile/lib/screens/craving/alternative_detail_screen.dart`, add two imports at the top:

```dart
import '../games/bubble_pop_game_screen.dart';
import '../games/word_search_game_screen.dart';
```

Add this private method inside `_AlternativeDetailScreenState`, right after the `_onControllerChanged` method:

```dart
  void _openGame(BuildContext context, String alternativeId) {
    final Widget gameScreen = switch (alternativeId) {
      'bubble_pop' => const BubblePopGameScreen(),
      'word_puzzle' => const WordSearchGameScreen(),
      _ => throw StateError('No game screen wired up for alternativeId "$alternativeId".'),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => gameScreen));
  }
```

Then, in the `build` method, insert a new block right after the `Container` that shows `alternative.instructions` (i.e. right after its closing `),` and before the `const SizedBox(height: 28),` that precedes "Did this help?"):

```dart
              if (alternative.category == AlternativeCategory.game) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('alternative_detail_play_button'),
                  onPressed: () => _openGame(context, alternative.alternativeId),
                  child: const Text('Play'),
                ),
              ],
```

`AlternativeCategory` is already imported in this file via `'../../models/habit_alternative.dart'`, so no new import is needed for it.

Now reword the two game entries' copy in `mobile/lib/data/habit_alternative_library.dart` (lines 38-52 as of this plan — confirm exact lines with `grep -n "bubble_pop\|word_puzzle" mobile/lib/data/habit_alternative_library.dart` first, since line numbers may have shifted):

Replace:
```dart
    alternativeId: 'bubble_pop',
    title: 'Bubble Pop Mini-Game',
    description: 'A 2-minute distraction that actually works',
    category: AlternativeCategory.game,
    instructions: 'Open the Bubble Pop mini-game and play for 2 minutes. A short, absorbing '
        'distraction is often enough to let a craving pass.',
  ),
  HabitAlternative(
    alternativeId: 'word_puzzle',
    title: 'Quick Word Puzzle',
    description: 'Keep your hands and mind busy',
    category: AlternativeCategory.game,
    instructions: 'Open the Word Puzzle mini-game and try one round. Keeping your hands and '
        'mind occupied is a proven craving-management technique.',
  ),
```

With:
```dart
    alternativeId: 'bubble_pop',
    title: 'Bubble Pop Mini-Game',
    description: 'A calm, self-paced distraction',
    category: AlternativeCategory.game,
    instructions: 'Open the Bubble Pop mini-game and pop bubbles at your own pace, for as '
        'long as you like. A short, absorbing distraction is often enough to let a craving pass.',
  ),
  HabitAlternative(
    alternativeId: 'word_puzzle',
    title: 'Quick Word Puzzle',
    description: 'Keep your hands and mind busy',
    category: AlternativeCategory.game,
    instructions: 'Open the Word Puzzle mini-game and find the hidden calming words at your '
        'own pace. Keeping your hands and mind occupied is a proven craving-management technique.',
  ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart`
Expected: PASS (6/6 — the original 4 plus the 2 new ones).

Then run the full existing Alternatives test surface to confirm the copy reword didn't break anything that (per Task 4's own investigation) doesn't actually assert the old copy text:

Run: `cd mobile && flutter test test/screens/high_risk_screen_test.dart test/controllers/alternatives_controller_test.dart`
Expected: PASS, no changes needed (neither file asserts the exact description/instructions strings — confirmed by `grep -rn "2-minute distraction\|play for 2 minutes\|try one round" test/` returning no matches before this task started).

- [ ] **Step 5: Analyze, run the full suite, and commit**

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`

Run: `cd mobile && flutter test`
Expected: all tests pass (no regressions anywhere else).

```bash
git add mobile/lib/screens/craving/alternative_detail_screen.dart mobile/lib/data/habit_alternative_library.dart mobile/test/screens/alternative_detail_screen_test.dart
git commit -m "feat(games): wire Play button into Alternative detail screen"
```

---

## Post-plan verification

- [ ] Run `cd mobile && flutter analyze` — expect `No issues found!`
- [ ] Run `cd mobile && flutter test` — expect all tests passing, count higher than the pre-plan baseline (368) by at least 13 (5 generator + 3 bubble pop + 5 word search + 2 detail-screen new tests, roughly — exact count depends on final assertions written).
- [ ] Manually confirm (via `git log --oneline -4`) that all 4 tasks landed as 4 separate commits, nothing squashed or skipped.

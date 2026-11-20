# Memory Match Mini-Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4x4 icon memory-matching mini-game to the Alternatives library, themed around quitting/health concepts.

**Architecture:** One new self-contained game screen (`mobile/lib/screens/games/memory_match_game_screen.dart`), plain widget state (`Set<int>` for face-up/matched indices) — no animation controller, no timer needed for this game.

**Tech Stack:** Flutter/Dart only — `dart:math` (`Random`, for shuffling). No new pubspec dependency.

## Global Constraints

- 4x4 grid, 8 pairs, plain Material icons only (no image assets).
- Move counter increments once per pair-attempt (both matches and mismatches count).
- No timer for this game.
- This is a new additive library entry (`alternativeId: 'memory_match'`), not a replacement.
- Adding it to `habit_alternative_library.dart` requires a matching entry in `high_risk_screen.dart`'s `_uiMeta` map too — Tap & Pop's addition proved this map has no default case and null-asserts, so a missing entry crashes every render of that screen. Also requires updating the hardcoded library-size counts already bumped once (5→6) in `alternatives_controller_test.dart` and `habit_alternative_matcher_test.dart` — this task bumps them again (6→7).
- Do not delete or weaken any existing test.
- Run `flutter analyze` and the affected test file(s) after every task; run the full `flutter test` suite before the final commit.

---

## Task 1: Memory Match game screen

**Files:**
- Create: `mobile/lib/screens/games/memory_match_game_screen.dart`
- Test: `mobile/test/screens/memory_match_game_screen_test.dart`

**Interfaces:**
- Consumes: `AppColors` (`background`, `sage`, `sageLight`, `surface`, `textPrimary`); `pumpUntil` from `mobile/test/support/pump_until.dart` (already exists).
- Produces: `MemoryMatchGameScreen` (public widget, constructor `MemoryMatchGameScreen({Key? key, List<IconData>? board})` — `board` is injectable so tests get a fixed, non-shuffled 16-card layout instead of real randomness, same pattern as `WordSearchGameScreen(puzzle: ...)`).

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/screens/memory_match_game_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/games/memory_match_game_screen.dart';
import '../support/pump_until.dart';

// Fixed, non-shuffled board for deterministic tests: pairs sit at
// consecutive indices (0,1), (2,3), (4,5)...
const _fixedBoard = [
  Icons.air_rounded, Icons.air_rounded,
  Icons.favorite_rounded, Icons.favorite_rounded,
  Icons.savings_rounded, Icons.savings_rounded,
  Icons.eco_rounded, Icons.eco_rounded,
  Icons.psychology_rounded, Icons.psychology_rounded,
  Icons.calendar_today_rounded, Icons.calendar_today_rounded,
  Icons.emoji_events_rounded, Icons.emoji_events_rounded,
  Icons.water_drop_rounded, Icons.water_drop_rounded,
];

void main() {
  testWidgets('all 16 cards start face-down', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryMatchGameScreen(board: _fixedBoard)));
    await tester.pump();

    expect(find.byIcon(Icons.help_outline_rounded), findsNWidgets(16));
    expect(find.text('Moves: 0'), findsOneWidget);
  });

  testWidgets('tapping a card reveals its icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryMatchGameScreen(board: _fixedBoard)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('memory_card_0')));
    await tester.pump();

    expect(find.byIcon(Icons.air_rounded), findsOneWidget);
  });

  testWidgets('tapping a matching pair keeps both revealed and increments moves', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryMatchGameScreen(board: _fixedBoard)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('memory_card_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('memory_card_1')));
    await tester.pump();

    expect(find.text('Moves: 1'), findsOneWidget);
    expect(find.byIcon(Icons.air_rounded), findsNWidgets(2));
  });

  testWidgets('tapping a mismatching pair shows both then flips back', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryMatchGameScreen(board: _fixedBoard)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('memory_card_0'))); // air
    await tester.pump();
    await tester.tap(find.byKey(const Key('memory_card_2'))); // favorite
    await tester.pump();

    expect(find.byIcon(Icons.air_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('Moves: 1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byIcon(Icons.air_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.help_outline_rounded), findsNWidgets(16));
  });

  testWidgets('a third tap is ignored while two mismatched cards are still resolving', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryMatchGameScreen(board: _fixedBoard)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('memory_card_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('memory_card_2')));
    await tester.pump();

    // Still resolving (800ms hasn't elapsed) — this tap must be a no-op.
    await tester.tap(find.byKey(const Key('memory_card_4')));
    await tester.pump();

    expect(find.byIcon(Icons.savings_rounded), findsNothing);
    expect(find.text('Moves: 1'), findsOneWidget);
  });

  testWidgets('completing all pairs shows the completion message with the move count', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryMatchGameScreen(board: _fixedBoard)));
    await tester.pump();

    for (var i = 0; i < 16; i += 2) {
      await tester.tap(find.byKey(Key('memory_card_$i')));
      await tester.pump();
      await tester.tap(find.byKey(Key('memory_card_${i + 1}')));
      await tester.pump();
    }

    expect(find.byKey(const Key('memory_match_completion_message')), findsOneWidget);
    expect(find.text('You did it in 8 moves!'), findsOneWidget);
  });

  testWidgets('Play Again resets the board and move counter', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoryMatchGameScreen(board: _fixedBoard)));
    await tester.pump();

    for (var i = 0; i < 16; i += 2) {
      await tester.tap(find.byKey(Key('memory_card_$i')));
      await tester.pump();
      await tester.tap(find.byKey(Key('memory_card_${i + 1}')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('memory_match_play_again_button')));
    await tester.pump();

    expect(find.text('Moves: 0'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsNWidgets(16));
  });

  testWidgets('the close button pops the screen at any point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemoryMatchGameScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpUntil(tester, () => find.byKey(const Key('memory_match_close_button')).evaluate().isNotEmpty);

    await tester.tap(find.byKey(const Key('memory_match_close_button')));
    await pumpUntil(tester, () => find.byType(MemoryMatchGameScreen).evaluate().isEmpty);

    expect(find.byType(MemoryMatchGameScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/memory_match_game_screen_test.dart`
Expected: FAIL — `lib/screens/games/memory_match_game_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `mobile/lib/screens/games/memory_match_game_screen.dart`:

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
    if (_resolving || _faceUp.contains(index) || _matched.contains(index) || _faceUp.length >= 2) {
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
    final color = isMatched ? AppColors.sageLight : (isFaceUp ? AppColors.surface : AppColors.sage);
    return GestureDetector(
      key: Key('memory_card_$index'),
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('memory_match_close_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(backgroundColor: AppColors.sageLight, shape: const CircleBorder()),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Moves: $_moves',
                    key: const Key('memory_match_move_counter'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_completed)
                Expanded(
                  child: Center(
                    child: _CompletionView(moves: _moves, onPlayAgain: _startGame, onDone: () => Navigator.of(context).maybePop()),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    itemCount: _board.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

  const _CompletionView({required this.moves, required this.onPlayAgain, required this.onDone});

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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/memory_match_game_screen_test.dart`
Expected: PASS (8/8).

- [ ] **Step 5: Run it 10 times to check for flakiness**

Run: `cd mobile && for i in 1 2 3 4 5 6 7 8 9 10; do flutter test test/screens/memory_match_game_screen_test.dart 2>&1 | tail -3; done`
Expected: 8/8 passing on all 10 runs.

- [ ] **Step 6: Analyze and commit**

Run: `cd mobile && flutter analyze lib/screens/games/memory_match_game_screen.dart test/screens/memory_match_game_screen_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/games/memory_match_game_screen.dart mobile/test/screens/memory_match_game_screen_test.dart
git commit -m "feat(games): add playable Memory Match mini-game screen"
```

---

## Task 2: Add Memory Match to the Alternatives library and wire it up

**Files:**
- Modify: `mobile/lib/data/habit_alternative_library.dart`
- Modify: `mobile/lib/screens/craving/alternative_detail_screen.dart`
- Modify: `mobile/lib/screens/craving/high_risk_screen.dart`
- Modify: `mobile/test/screens/alternative_detail_screen_test.dart`
- Modify: `mobile/test/screens/high_risk_screen_test.dart`
- Modify: `mobile/test/controllers/alternatives_controller_test.dart`
- Modify: `mobile/test/domain/habit_alternative_matcher_test.dart`

**Interfaces:**
- Consumes: `MemoryMatchGameScreen` (Task 1).

- [ ] **Step 1: Write the failing tests**

In `mobile/test/screens/alternative_detail_screen_test.dart`, add the import alongside the other four game-screen imports:

```dart
import 'package:quit_companion/screens/games/memory_match_game_screen.dart';
```

Add a fixture and test, following the exact pattern of the Tap & Pop addition:

```dart
const _memoryMatchAlternative = HabitAlternative(
  alternativeId: 'memory_match',
  title: 'Memory Match',
  description: 'A quick icon-matching game',
  category: AlternativeCategory.game,
  instructions: 'Flip two cards at a time and find every matching pair.',
);
```

```dart
  testWidgets('tapping Play on Memory Match opens MemoryMatchGameScreen', (tester) async {
    final controller = AlternativesController(FakeHabitAlternativeAttemptRepository());

    await tester.pumpWidget(MaterialApp(
      home: AlternativeDetailScreen(
        userId: 'u1',
        alternative: _memoryMatchAlternative,
        triggerCategory: TriggerCategory.boredom,
        mood: Mood.bored,
        controller: controller,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alternative_detail_play_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MemoryMatchGameScreen), findsOneWidget);
  });
```

In `mobile/test/screens/high_risk_screen_test.dart`, update the render test's title/count and add the new card's assertions (mirroring exactly how the Tap & Pop addition updated this same test from "five" to "six"):

```dart
  testWidgets('renders the approved 6a layout: header, filters, and all seven alternative cards', (tester) async {
```

(rename from "all six" to "all seven"), and add after the existing `tap_pop` assertions:

```dart
    expect(find.byKey(const Key('high_risk_card_memory_match')), findsOneWidget);
    expect(find.text('Memory Match'), findsOneWidget);
```

And bump the Try This button count:

```dart
    expect(tryThisButtons, findsNWidgets(7));
```

In `mobile/test/controllers/alternatives_controller_test.dart`, bump the three hardcoded counts from the Tap & Pop task (6→7 for totals, 3→4 for the game-category filter count):

```dart
      expect(controller.recommendations, hasLength(7));
```

```dart
      expect(controller.filteredRecommendations, hasLength(7));

      controller.setFilter(AlternativeCategory.game);
      expect(controller.filteredRecommendations, hasLength(4));
      expect(controller.filteredRecommendations.every((a) => a.category == AlternativeCategory.game), isTrue);

      controller.setFilter(null);
      expect(controller.filteredRecommendations, hasLength(7));
```

In `mobile/test/domain/habit_alternative_matcher_test.dart`, add `'memory_match'` to the expected id set:

```dart
      expect(ranked.map((a) => a.alternativeId).toSet(), {
        'breathing',
        'cold_water',
        'short_walk',
        'bubble_pop',
        'word_puzzle',
        'tap_pop',
        'memory_match',
      });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart test/screens/high_risk_screen_test.dart test/controllers/alternatives_controller_test.dart test/domain/habit_alternative_matcher_test.dart`
Expected: FAIL — `'memory_match'` isn't in the library or `_gameScreenIds`/`_uiMeta` yet, and the count bumps don't match current (pre-Task-2) reality.

- [ ] **Step 3: Write the implementation**

In `mobile/lib/data/habit_alternative_library.dart`, add a new entry after the `tap_pop` entry:

```dart
  HabitAlternative(
    alternativeId: 'memory_match',
    title: 'Memory Match',
    description: 'A quick icon-matching game',
    category: AlternativeCategory.game,
    instructions: 'Flip two cards at a time and find every matching pair.',
  ),
```

In `mobile/lib/screens/craving/alternative_detail_screen.dart`, add the import:

```dart
import '../games/memory_match_game_screen.dart';
```

Add `'memory_match'` to `_gameScreenIds`:

```dart
const _gameScreenIds = {'bubble_pop', 'word_puzzle', 'breathing', 'tap_pop', 'memory_match'};
```

Add a case to `_openGame`'s switch:

```dart
      'memory_match' => const MemoryMatchGameScreen(),
```

In `mobile/lib/screens/craving/high_risk_screen.dart`, add a `_uiMeta` entry (this is the step that prevents the same crash Tap & Pop's addition caused):

```dart
  'memory_match': _AlternativeUiMeta(
    tag: 'Game', icon: Icons.grid_view_rounded, iconBg: AppColors.terracottaLight, iconColor: AppColors.terracottaDark,
  ),
```

- [ ] **Step 4: Run tests, analyze, run the full suite, and commit**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart test/screens/high_risk_screen_test.dart test/controllers/alternatives_controller_test.dart test/domain/habit_alternative_matcher_test.dart`
Expected: PASS, all green.

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`

Run: `cd mobile && flutter test`
Expected: all tests pass, no regressions.

```bash
git add mobile/lib/data/habit_alternative_library.dart mobile/lib/screens/craving/alternative_detail_screen.dart mobile/lib/screens/craving/high_risk_screen.dart mobile/test/screens/alternative_detail_screen_test.dart mobile/test/screens/high_risk_screen_test.dart mobile/test/controllers/alternatives_controller_test.dart mobile/test/domain/habit_alternative_matcher_test.dart
git commit -m "feat(games): add Memory Match to the Alternatives library"
```

---

## Post-plan verification

- [ ] `flutter analyze` — `No issues found!`
- [ ] `flutter test` — all passing, count higher than the pre-plan baseline (394) by roughly 9 (8 new screen tests + 1 new Play-button test).
- [ ] `git log --oneline -2` confirms 2 separate commits.

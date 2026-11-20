# Tap & Pop Mini-Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new, distinct 30-second timed reflex mini-game (Tap & Pop) to the Alternatives library, alongside the existing calm Bubble Pop.

**Architecture:** One new self-contained game screen (`mobile/lib/screens/games/tap_and_pop_game_screen.dart`), driven by two plain `Timer`s (a 1-second countdown, a per-dot lifetime timer) — same pattern already established by Bubble Pop, not the AnimationController pattern used by Breathing Bubble (this game needs discrete spawn/expire events, not a continuous eased transition).

**Tech Stack:** Flutter/Dart only — `dart:async` (`Timer`), `dart:math` (`Random`). No new pubspec dependency.

## Global Constraints

- One dot on screen at a time, visible 1200ms before fading if unpopped, no penalty for a miss.
- 30-second round; live score counter and countdown visible throughout.
- Round end shows score + Play Again (same screen, fresh round) + Done (pop screen). Close button works at any point, no penalty for leaving early.
- This is a new additive library entry (`alternativeId: 'tap_pop'`), not a replacement of the existing `bubble_pop` entry.
- Do not delete or weaken any existing test.
- Run `flutter analyze` and the affected test file(s) after every task; run the full `flutter test` suite before the final commit.

---

## Task 1: Tap & Pop game screen

**Files:**
- Create: `mobile/lib/screens/games/tap_and_pop_game_screen.dart`
- Test: `mobile/test/screens/tap_and_pop_game_screen_test.dart`

**Interfaces:**
- Consumes: `AppColors` (`background`, `sage`, `terracotta`, `sageLight`, `textPrimary`, `textSecondary`); `pumpUntil` from `mobile/test/support/pump_until.dart` (already exists from the Breathing Bubble task).
- Produces: `TapAndPopGameScreen` (public widget, no constructor params); `TapAndPopDotTile` (public widget — not underscore-prefixed, so tests can find the current dot via `find.byType(TapAndPopDotTile)` without knowing its randomly-generated id, same reasoning as `BubblePopBubbleTile`).

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/screens/tap_and_pop_game_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/games/tap_and_pop_game_screen.dart';
import '../support/pump_until.dart';

void main() {
  testWidgets('a dot is visible shortly after opening', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    expect(find.byType(TapAndPopDotTile), findsOneWidget);
    expect(find.text('Score: 0'), findsOneWidget);
  });

  testWidgets('tapping a dot increments the score and spawns a new dot', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    await tester.tap(find.byType(TapAndPopDotTile));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(find.text('Score: 1'), findsOneWidget);
    expect(find.byType(TapAndPopDotTile), findsOneWidget);
  });

  testWidgets('after 30 seconds, shows the summary with the final score', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    await tester.tap(find.byType(TapAndPopDotTile));
    await tester.pump(const Duration(milliseconds: 150));

    await pumpUntil(
      tester,
      () => find.byKey(const Key('tap_and_pop_summary_message')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
    );

    expect(find.text('You popped 1 bubbles!'), findsOneWidget);
  });

  testWidgets('Play Again resets the score and starts a new round', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    // Score at least 1 before the round ends, so seeing it reset to 0
    // afterward is a meaningful check, not a no-op.
    await tester.tap(find.byType(TapAndPopDotTile));
    await tester.pump(const Duration(milliseconds: 150));

    await pumpUntil(
      tester,
      () => find.byKey(const Key('tap_and_pop_summary_message')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
    );

    await tester.tap(find.byKey(const Key('tap_and_pop_play_again_button')));
    await tester.pump();

    expect(find.text('Score: 0'), findsOneWidget);
    expect(find.byType(TapAndPopDotTile), findsOneWidget);
  });

  testWidgets('the close button pops the screen at any point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TapAndPopGameScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpUntil(tester, () => find.byKey(const Key('tap_and_pop_close_button')).evaluate().isNotEmpty);

    await tester.tap(find.byKey(const Key('tap_and_pop_close_button')));
    await pumpUntil(tester, () => find.byType(TapAndPopGameScreen).evaluate().isEmpty);

    expect(find.byType(TapAndPopGameScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/tap_and_pop_game_screen_test.dart`
Expected: FAIL — `lib/screens/games/tap_and_pop_game_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `mobile/lib/screens/games/tap_and_pop_game_screen.dart`:

```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class _Dot {
  final String id;
  final double leftFraction;
  final double topFraction;
  final Color color;

  const _Dot({required this.id, required this.leftFraction, required this.topFraction, required this.color});
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
                    style: IconButton.styleFrom(backgroundColor: AppColors.sageLight, shape: const CircleBorder()),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Score: $_score',
                        key: const Key('tap_and_pop_score'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                if (_roundOver)
                  Positioned.fill(
                    child: Center(
                      child: _SummaryView(score: _score, onPlayAgain: _startRound, onDone: () => Navigator.of(context).maybePop()),
                    ),
                  )
                else if (dot != null)
                  Positioned(
                    left: dot.leftFraction * constraints.maxWidth,
                    top: dot.topFraction * constraints.maxHeight,
                    child: TapAndPopDotTile(key: ValueKey(dot.id), color: dot.color, onTap: () => _popDot(dot.id)),
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

  const _SummaryView({required this.score, required this.onPlayAgain, required this.onDone});

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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/tap_and_pop_game_screen_test.dart`
Expected: PASS (5/5). If timing-based tests are flaky or fail on exact-duration boundaries, apply the same fix already proven in the Breathing Bubble task: prefer `pumpUntil` (condition-based, small increments) over one large fixed-duration `pump()` call.

- [ ] **Step 5: Run it 10 times to check for flakiness**

Run: `cd mobile && for i in 1 2 3 4 5 6 7 8 9 10; do flutter test test/screens/tap_and_pop_game_screen_test.dart 2>&1 | tail -3; done`
Expected: 5/5 passing on all 10 runs.

- [ ] **Step 6: Analyze and commit**

Run: `cd mobile && flutter analyze lib/screens/games/tap_and_pop_game_screen.dart test/screens/tap_and_pop_game_screen_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/games/tap_and_pop_game_screen.dart mobile/test/screens/tap_and_pop_game_screen_test.dart
git commit -m "feat(games): add playable Tap & Pop mini-game screen"
```

---

## Task 2: Add Tap & Pop to the Alternatives library and wire it up

**Files:**
- Modify: `mobile/lib/data/habit_alternative_library.dart`
- Modify: `mobile/lib/screens/craving/alternative_detail_screen.dart`
- Modify: `mobile/test/screens/alternative_detail_screen_test.dart`

**Interfaces:**
- Consumes: `TapAndPopGameScreen` (Task 1).

- [ ] **Step 1: Write the failing test**

In `mobile/test/screens/alternative_detail_screen_test.dart`, add the import alongside the other three game-screen imports:

```dart
import 'package:quit_companion/screens/games/tap_and_pop_game_screen.dart';
```

Add a new fixture near the other two game fixtures:

```dart
const _tapAndPopAlternative = HabitAlternative(
  alternativeId: 'tap_pop',
  title: 'Tap & Pop',
  description: 'A quick 30-second reflex challenge',
  category: AlternativeCategory.game,
  instructions: 'Tap the dot before it fades — see how many you can pop in 30 seconds.',
);
```

Add a new test after the existing `'tapping Play on 4-7-8 Breathing opens BreathingBubbleGameScreen'` test:

```dart
  testWidgets('tapping Play on Tap & Pop opens TapAndPopGameScreen', (tester) async {
    final controller = AlternativesController(FakeHabitAlternativeAttemptRepository());

    await tester.pumpWidget(MaterialApp(
      home: AlternativeDetailScreen(
        userId: 'u1',
        alternative: _tapAndPopAlternative,
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

    expect(find.byType(TapAndPopGameScreen), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart --plain-name "Tap & Pop"`
Expected: FAIL — `'tap_pop'` isn't in `_gameScreenIds` yet and has no library entry.

- [ ] **Step 3: Write the implementation**

In `mobile/lib/data/habit_alternative_library.dart`, add a new entry to the `habitAlternativeLibrary` list, alongside the existing `bubble_pop`/`word_puzzle` entries (same category, additive — do not remove or reorder the existing two):

```dart
  HabitAlternative(
    alternativeId: 'tap_pop',
    title: 'Tap & Pop',
    description: 'A quick 30-second reflex challenge',
    category: AlternativeCategory.game,
    instructions: 'Tap the dot before it fades — see how many you can pop in 30 seconds.',
  ),
```

In `mobile/lib/screens/craving/alternative_detail_screen.dart`, add the import:

```dart
import '../games/tap_and_pop_game_screen.dart';
```

Add `'tap_pop'` to the `_gameScreenIds` set:

```dart
const _gameScreenIds = {'bubble_pop', 'word_puzzle', 'breathing', 'tap_pop'};
```

Add a case to `_openGame`'s switch:

```dart
      'tap_pop' => const TapAndPopGameScreen(),
```

- [ ] **Step 4: Run tests, analyze, run the full suite, and commit**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart`
Expected: PASS, all green.

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`

Run: `cd mobile && flutter test`
Expected: all tests pass, no regressions.

```bash
git add mobile/lib/data/habit_alternative_library.dart mobile/lib/screens/craving/alternative_detail_screen.dart mobile/test/screens/alternative_detail_screen_test.dart
git commit -m "feat(games): add Tap & Pop to the Alternatives library"
```

---

## Post-plan verification

- [ ] `flutter analyze` — `No issues found!`
- [ ] `flutter test` — all passing, count higher than the pre-plan baseline (388) by roughly 6 (5 new screen tests + 1 new Play-button test).
- [ ] `git log --oneline -2` confirms 2 separate commits.

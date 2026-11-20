# Breathing Bubble Mini-Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static "4-7-8 Breathing" text-instruction alternative with a real, animated, friendly-faced breathing-guide mini-game, reached the same way Bubble Pop and Word Search already are.

**Architecture:** One new self-contained game screen (`mobile/lib/screens/games/breathing_bubble_game_screen.dart`), driven entirely by a single `AnimationController` (no `Timer`-based game loop, no persisted state). The existing Play-button visibility check in `AlternativeDetailScreen` moves from category-based to id-based, since this game replaces an `exercise`-category alternative rather than a `game`-category one.

**Tech Stack:** Flutter/Dart only — `dart:math` (`Random`, for the face's blink timing), `dart:async` (`Timer`, for the same blink), core Flutter animation widgets (`AnimationController`, `AnimatedBuilder`, `CustomPainter`). No new pubspec dependency.

## Global Constraints

- Fixed 4-7-8 timing per cycle (4s inhale, 7s hold, 8s exhale = 19s/cycle), 6 cycles total (~2 minutes) — matches the existing alternative's name and current instructions text, per the approved design (`docs/superpowers/specs/2026-08-30-breathing-bubble-game-design.md`).
- No score, no failure state. Leaving early (via the close button) is never penalized or flagged — only finishing all 6 cycles shows the completion message.
- The bubble's face (two dot eyes + a curved smile) is original, geometric, decorative — drawn with plain shapes/`CustomPainter`, not an image asset, not referencing any existing character.
- Do not delete or weaken any existing test. All new coverage is additive except one deliberate, documented fixture rename (Task 2) needed to resolve a real id collision this change would otherwise introduce.
- Run `flutter analyze` and the affected test file(s) after every task; run the full `flutter test` suite before the final commit.

---

## Task 1: Breathing Bubble game screen

**Files:**
- Create: `mobile/lib/screens/games/breathing_bubble_game_screen.dart`
- Create: `mobile/test/support/pump_until.dart`
- Test: `mobile/test/screens/breathing_bubble_game_screen_test.dart`

**Interfaces:**
- Consumes: `AppColors` from `mobile/lib/theme/app_theme.dart` (fields: `background`, `sageLight`, `sage`, `textPrimary`, `textSecondary`).
- Produces: `BreathingBubbleGameScreen` (public widget, no constructor params beyond `key`); `pumpUntil(WidgetTester, bool Function(), {Duration timeout})` (shared test helper — Task 2 does not need it, but future game tests may reuse it the same way Task 1 does here).

- [ ] **Step 1: Write the shared test helper**

Create `mobile/test/support/pump_until.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

/// Pumps in small increments until [condition] is true or [timeout] is
/// reached. Needed for screens with a continuously-running animation or
/// timer (this game's AnimationController keeps cycling for ~2 minutes;
/// Bubble Pop's bubbles float/respawn forever) — `pumpAndSettle()` either
/// never returns or, worse, silently fast-forwards through the entire
/// remaining animation before your test gets to assert anything.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
```

- [ ] **Step 2: Write the failing tests**

Create `mobile/test/screens/breathing_bubble_game_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/games/breathing_bubble_game_screen.dart';
import '../support/pump_until.dart';

void main() {
  testWidgets('starts on "Breathe In", Cycle 1 of 6', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BreathingBubbleGameScreen()));
    await tester.pump();

    expect(find.text('Breathe In'), findsOneWidget);
    expect(find.text('Cycle 1 of 6'), findsOneWidget);
  });

  testWidgets('advances to Cycle 2 of 6 after one full 19-second cycle', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BreathingBubbleGameScreen()));
    await tester.pump();

    await tester.pump(const Duration(seconds: 19));
    await tester.pump();

    expect(find.text('Cycle 2 of 6'), findsOneWidget);
  });

  testWidgets('the close button pops the screen at any point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BreathingBubbleGameScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpUntil(tester, () => find.byKey(const Key('breathing_bubble_close_button')).evaluate().isNotEmpty);

    await tester.tap(find.byKey(const Key('breathing_bubble_close_button')));
    await pumpUntil(tester, () => find.byType(BreathingBubbleGameScreen).evaluate().isEmpty);

    expect(find.byType(BreathingBubbleGameScreen), findsNothing);
  });

  testWidgets('shows the completion message after all 6 cycles, and Done pops the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BreathingBubbleGameScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpUntil(tester, () => find.byType(BreathingBubbleGameScreen).evaluate().isNotEmpty);

    // 6 cycles * 19s = 114s.
    await tester.pump(const Duration(seconds: 114));
    await tester.pump();

    expect(find.byKey(const Key('breathing_bubble_completion_message')), findsOneWidget);
    expect(find.byKey(const Key('breathing_bubble_done_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('breathing_bubble_done_button')));
    await pumpUntil(tester, () => find.byType(BreathingBubbleGameScreen).evaluate().isEmpty);

    expect(find.byType(BreathingBubbleGameScreen), findsNothing);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/breathing_bubble_game_screen_test.dart`
Expected: FAIL — `lib/screens/games/breathing_bubble_game_screen.dart` doesn't exist yet.

- [ ] **Step 4: Write the implementation**

Create `mobile/lib/screens/games/breathing_bubble_game_screen.dart`:

```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum _BreathPhase { inhale, hold, exhale }

/// A guided 4-7-8 breathing exercise: an expanding/contracting bubble with
/// a friendly face, a live phase label, and a cycle counter. Runs for a
/// fixed 6 cycles (~2 minutes) then celebrates — but the close button
/// works at any point, and leaving early is never treated as a failure
/// (per the approved design, docs/superpowers/specs/2026-08-30-breathing-bubble-game-design.md).
class BreathingBubbleGameScreen extends StatefulWidget {
  const BreathingBubbleGameScreen({super.key});

  @override
  State<BreathingBubbleGameScreen> createState() => _BreathingBubbleGameScreenState();
}

class _BreathingBubbleGameScreenState extends State<BreathingBubbleGameScreen>
    with SingleTickerProviderStateMixin {
  static const _totalCycles = 6;
  static const _inhaleMs = 4000;
  static const _holdMs = 7000;
  static const _exhaleMs = 8000;
  static const _cycleDuration = Duration(milliseconds: _inhaleMs + _holdMs + _exhaleMs);

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
                style: IconButton.styleFrom(backgroundColor: AppColors.sageLight, shape: const CircleBorder()),
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
            ),
            Center(
              child: _completed
                  ? _CompletionView(onDone: () => Navigator.of(context).maybePop())
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final scale = _scaleAt(_controller.value);
                        final phase = _phaseAt(_controller.value);
                        final size = 140 + scale * 100;
                        final color = Color.lerp(AppColors.sageLight, AppColors.sage, scale)!;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cycle $_currentCycle of $_totalCycles',
                              key: const Key('breathing_bubble_cycle_counter'),
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 32),
                            _BreathingBubble(size: size, color: color),
                            const SizedBox(height: 32),
                            Text(
                              _labelFor(phase),
                              key: const Key('breathing_bubble_phase_label'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
        const SizedBox(width: 24, height: 12, child: CustomPaint(painter: _SmilePainter())),
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
      decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
    );
  }
}

class _SmilePainter extends CustomPainter {
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/breathing_bubble_game_screen_test.dart`
Expected: PASS (4/4). If the cycle-advance or completion timing tests fail on the first attempt, re-check the `_phaseAt`/`_scaleAt` millisecond-boundary math above before changing test durations — the 19s/114s figures are exact (4+7+8=19, ×6=114), not approximations.

- [ ] **Step 6: Run it 10 times to check for flakiness**

Run: `cd mobile && for i in 1 2 3 4 5 6 7 8 9 10; do flutter test test/screens/breathing_bubble_game_screen_test.dart 2>&1 | tail -3; done`
Expected: 4/4 passing on all 10 runs. (Bubble Pop's equivalent screen needed two rounds of fixes for exactly this kind of timing flakiness — verify this one doesn't have the same problem before moving on, since unlike Bubble Pop this game has no unseeded `Random` in its core timing logic, only in the decorative blink, so it should be inherently more deterministic — but confirm rather than assume.)

- [ ] **Step 7: Analyze and commit**

Run: `cd mobile && flutter analyze lib/screens/games/breathing_bubble_game_screen.dart test/support/pump_until.dart test/screens/breathing_bubble_game_screen_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/games/breathing_bubble_game_screen.dart mobile/test/support/pump_until.dart mobile/test/screens/breathing_bubble_game_screen_test.dart
git commit -m "feat(games): add playable Breathing Bubble mini-game screen"
```

---

## Task 2: Wire Breathing Bubble into AlternativeDetailScreen, generalize the Play button, reword copy

**Files:**
- Modify: `mobile/lib/screens/craving/alternative_detail_screen.dart`
- Modify: `mobile/lib/data/habit_alternative_library.dart:13-19`
- Modify: `mobile/test/screens/alternative_detail_screen_test.dart`

**Interfaces:**
- Consumes: `BreathingBubbleGameScreen` (Task 1).

- [ ] **Step 1: Fix a real id collision in the existing test fixture, first**

`mobile/test/screens/alternative_detail_screen_test.dart`'s shared `_alternative` fixture (used by four pre-existing, currently-passing tests) happens to reuse `alternativeId: 'breathing'` — a coincidence from when it was first written, not a reference to the real library entry. Once `'breathing'` becomes a real game id in this task, the existing test `'shows a Play button for game-category alternatives, not for others'` (which asserts `_alternative` shows NO Play button) would start failing, since `_alternative`'s id would now match a real game.

Rename the fixture's id so it no longer collides — it was never meant to represent the specific real `'breathing'` library entry, just a generic non-game alternative for exercising generic detail-screen behavior. In `mobile/test/screens/alternative_detail_screen_test.dart`, change:

```dart
const _alternative = HabitAlternative(
  alternativeId: 'breathing',
  title: '4-7-8 Breathing',
  description: 'Calm your nervous system in under a minute',
  category: AlternativeCategory.exercise,
  instructions: 'Breathe in for 4 seconds, hold for 7, exhale for 8.',
);
```

to:

```dart
const _alternative = HabitAlternative(
  alternativeId: 'stretching',
  title: 'Quick Stretch',
  description: 'Release tension in under a minute',
  category: AlternativeCategory.exercise,
  instructions: 'Stand up, reach your arms overhead, and hold for 10 seconds.',
);
```

And update the one test that asserts the id directly — `'renders the title and instructions, and logs an attempt on open'` — change:

```dart
    expect(find.text('4-7-8 Breathing'), findsOneWidget);
    expect(find.text('Breathe in for 4 seconds, hold for 7, exhale for 8.'), findsOneWidget);
    expect(repository.attempts, hasLength(1));
    expect(repository.attempts.first.alternativeId, 'breathing');
```

to:

```dart
    expect(find.text('Quick Stretch'), findsOneWidget);
    expect(find.text('Stand up, reach your arms overhead, and hold for 10 seconds.'), findsOneWidget);
    expect(repository.attempts, hasLength(1));
    expect(repository.attempts.first.alternativeId, 'stretching');
```

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart`
Expected: PASS, all still green (this step is a pure rename, no behavior change yet) — confirms the rename didn't typo anything before moving on to the actual new-feature steps.

- [ ] **Step 2: Write the failing test for the new Play button**

In the same file, add a new test after `'tapping Play on Quick Word Puzzle opens WordSearchGameScreen'`:

```dart
  testWidgets('tapping Play on 4-7-8 Breathing opens BreathingBubbleGameScreen', (tester) async {
    const breathingAlternative = HabitAlternative(
      alternativeId: 'breathing',
      title: '4-7-8 Breathing',
      description: 'Calm your nervous system in under a minute',
      category: AlternativeCategory.exercise,
      instructions: 'Follow the bubble: breathe in as it grows, hold, then breathe out as it shrinks.',
    );
    final controller = AlternativesController(FakeHabitAlternativeAttemptRepository());

    await tester.pumpWidget(MaterialApp(
      home: AlternativeDetailScreen(
        userId: 'u1',
        alternative: breathingAlternative,
        triggerCategory: TriggerCategory.stress,
        mood: Mood.stressed,
        controller: controller,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alternative_detail_play_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BreathingBubbleGameScreen), findsOneWidget);
  });
```

Add the import at the top of the file, alongside the other two game-screen imports:

```dart
import 'package:quit_companion/screens/games/breathing_bubble_game_screen.dart';
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart --plain-name "4-7-8 Breathing"`
Expected: FAIL — `alternative_detail_play_button` not found (the `'breathing'` id isn't in the game-screen set yet, and its category is `exercise`, not `game`).

- [ ] **Step 4: Write the implementation**

In `mobile/lib/screens/craving/alternative_detail_screen.dart`, add the new import alongside the other two:

```dart
import '../games/breathing_bubble_game_screen.dart';
```

Add a top-level constant right after the imports (before the class doc comment):

```dart
/// Every alternativeId with a real playable game screen — deliberately
/// independent of AlternativeCategory, since a game can replace an
/// alternative of any category (Breathing Bubble replaces an `exercise`
/// alternative, not a `game` one).
const _gameScreenIds = {'bubble_pop', 'word_puzzle', 'breathing'};
```

Change the Play-button visibility condition from:

```dart
              if (alternative.category == AlternativeCategory.game) ...[
```

to:

```dart
              if (_gameScreenIds.contains(alternative.alternativeId)) ...[
```

Add a case to `_openGame`'s switch:

```dart
  void _openGame(BuildContext context, String alternativeId) {
    final Widget gameScreen = switch (alternativeId) {
      'bubble_pop' => const BubblePopGameScreen(),
      'word_puzzle' => const WordSearchGameScreen(),
      'breathing' => const BreathingBubbleGameScreen(),
      _ => throw StateError('No game screen wired up for alternativeId "$alternativeId".'),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => gameScreen));
  }
```

Now reword the real library entry. In `mobile/lib/data/habit_alternative_library.dart`, change:

```dart
    alternativeId: 'breathing',
    title: '4-7-8 Breathing',
    description: 'Calm your nervous system in under a minute',
    category: AlternativeCategory.exercise,
    instructions:
        'Breathe in quietly through your nose for 4 seconds. Hold your breath for 7 seconds. '
        'Exhale completely through your mouth for 8 seconds. Repeat this cycle 4 times.',
```

to:

```dart
    alternativeId: 'breathing',
    title: '4-7-8 Breathing',
    description: 'Calm your nervous system in under a minute',
    category: AlternativeCategory.exercise,
    instructions: 'Follow the bubble: breathe in as it grows, hold while it stays full, and '
        'breathe out as it shrinks. Six calming cycles, guided for you.',
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart`
Expected: PASS, all tests green (the renamed fixture from Step 1 plus the new Breathing test from Step 2).

- [ ] **Step 6: Analyze, run the full suite, and commit**

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`

Run: `cd mobile && flutter test`
Expected: all tests pass, no regressions.

```bash
git add mobile/lib/screens/craving/alternative_detail_screen.dart mobile/lib/data/habit_alternative_library.dart mobile/test/screens/alternative_detail_screen_test.dart
git commit -m "feat(games): wire Breathing Bubble into Alternative detail screen"
```

---

## Post-plan verification

- [ ] Run `cd mobile && flutter analyze` — expect `No issues found!`
- [ ] Run `cd mobile && flutter test` — expect all tests passing, count higher than the pre-plan baseline (383) by 4 (4 new Breathing Bubble screen tests) + 1 (the new Play-button test) = 5, i.e. 388 or close to it depending on final assertions written.
- [ ] Confirm via `git log --oneline -2` that both tasks landed as 2 separate commits.

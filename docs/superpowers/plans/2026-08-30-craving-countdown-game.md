# Craving Countdown Challenge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the fourth and last new mini-game — a 3-minute ambient "stay with the craving" countdown with a filling progress ring and rotating encouraging messages.

**Architecture:** One new self-contained game screen (`mobile/lib/screens/games/craving_countdown_game_screen.dart`), driven by a single `AnimationController` over a fixed 180-second duration — same pattern as Breathing Bubble, since this is continuous progress, not discrete spawn/expire events like Tap & Pop.

**Tech Stack:** Flutter/Dart only — no new pubspec dependency (`CircularProgressIndicator` is a core Flutter widget).

## Global Constraints

- Fixed 180-second (3-minute) duration. No adjustable duration, no sound.
- Six original encouraging messages, one per 30-second segment, rotating automatically.
- Reaching 180 seconds is success, not failure — there is no losing state, and leaving early via the close button is never framed as a failure.
- `craving_countdown`'s category is `AlternativeCategory.quickFix`, not `game` — it still gets a Play button via `_gameScreenIds` (id-based, category-independent, per the precedent Breathing Bubble established) but does NOT change the game-category filter count in `alternatives_controller_test.dart` (only the total-library counts change).
- Adding this 8th library entry requires the same `high_risk_screen.dart` `_uiMeta` entry every prior addition has needed (confirmed necessary three times now).
- Do not delete or weaken any existing test.
- Run `flutter analyze` and the affected test file(s) after every task; run the full `flutter test` suite before the final commit.

---

## Task 1: Craving Countdown game screen

**Files:**
- Create: `mobile/lib/screens/games/craving_countdown_game_screen.dart`
- Test: `mobile/test/screens/craving_countdown_game_screen_test.dart`

**Interfaces:**
- Consumes: `AppColors` (`background`, `sage`, `sageLight`, `border`, `textPrimary`, `textSecondary`); `pumpUntil` from `mobile/test/support/pump_until.dart` (already exists).
- Produces: `CravingCountdownGameScreen` (public widget, no constructor params).

- [ ] **Step 1: Write the failing tests**

Create `mobile/test/screens/craving_countdown_game_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/games/craving_countdown_game_screen.dart';
import '../support/pump_until.dart';

void main() {
  testWidgets('starts at 3:00 with an encouraging message shown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CravingCountdownGameScreen()));
    await tester.pump();

    expect(find.text('3:00'), findsOneWidget);
    expect(find.byKey(const Key('craving_countdown_message')), findsOneWidget);
  });

  testWidgets('the message changes after the first 30-second segment', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CravingCountdownGameScreen()));
    await tester.pump();
    final firstMessage = tester.widget<Text>(find.byKey(const Key('craving_countdown_message'))).data;

    await pumpUntil(
      tester,
      () => tester.widget<Text>(find.byKey(const Key('craving_countdown_message'))).data != firstMessage,
      timeout: const Duration(seconds: 15),
    );
  });

  testWidgets('after the full 3 minutes, shows the completion message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CravingCountdownGameScreen()));
    await tester.pump();

    // Cascading AnimationController restarts (this game only has one, on
    // Play Again, not the multi-restart-per-round problem Breathing
    // Bubble had) — small incremental pumps regardless, since a single
    // huge pump() only advances one frame at the new time.
    await pumpUntil(
      tester,
      () => find.byKey(const Key('craving_countdown_completion_message')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    expect(find.text('You beat the craving!'), findsOneWidget);
    expect(find.byKey(const Key('craving_countdown_play_again_button')), findsOneWidget);
  });

  testWidgets('Play Again resets the timer to 3:00', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CravingCountdownGameScreen()));
    await tester.pump();

    await pumpUntil(
      tester,
      () => find.byKey(const Key('craving_countdown_completion_message')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    await tester.tap(find.byKey(const Key('craving_countdown_play_again_button')));
    await tester.pump();

    expect(find.text('3:00'), findsOneWidget);
  });

  testWidgets('the close button pops the screen at any point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CravingCountdownGameScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpUntil(tester, () => find.byKey(const Key('craving_countdown_close_button')).evaluate().isNotEmpty);

    await tester.tap(find.byKey(const Key('craving_countdown_close_button')));
    await pumpUntil(tester, () => find.byType(CravingCountdownGameScreen).evaluate().isEmpty);

    expect(find.byType(CravingCountdownGameScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/screens/craving_countdown_game_screen_test.dart`
Expected: FAIL — `lib/screens/games/craving_countdown_game_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `mobile/lib/screens/games/craving_countdown_game_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
  State<CravingCountdownGameScreen> createState() => _CravingCountdownGameScreenState();
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
    final remainingSeconds = (_totalDuration.inSeconds * (1 - t)).ceil().clamp(0, _totalDuration.inSeconds);
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _messageAt(double t) {
    final elapsedSeconds = (_totalDuration.inSeconds * t).floor();
    final index = (elapsedSeconds ~/ _segmentSeconds).clamp(0, _messages.length - 1);
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
                style: IconButton.styleFrom(backgroundColor: AppColors.sageLight, shape: const CircleBorder()),
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
              ),
            ),
            Center(
              child: _completed
                  ? _CompletionView(onPlayAgain: _startChallenge, onDone: () => Navigator.of(context).maybePop())
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
                                      valueColor: const AlwaysStoppedAnimation(AppColors.sage),
                                    ),
                                  ),
                                  Text(
                                    _timeRemainingLabel(t),
                                    key: const Key('craving_countdown_time_remaining'),
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _messageAt(t),
                                key: const Key('craving_countdown_message'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.4),
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/screens/craving_countdown_game_screen_test.dart`
Expected: PASS (5/5).

- [ ] **Step 5: Run it 10 times to check for flakiness**

Run: `cd mobile && for i in 1 2 3 4 5 6 7 8 9 10; do flutter test test/screens/craving_countdown_game_screen_test.dart 2>&1 | tail -3; done`
Expected: 5/5 passing on all 10 runs.

- [ ] **Step 6: Analyze and commit**

Run: `cd mobile && flutter analyze lib/screens/games/craving_countdown_game_screen.dart test/screens/craving_countdown_game_screen_test.dart`
Expected: `No issues found!`

```bash
git add mobile/lib/screens/games/craving_countdown_game_screen.dart mobile/test/screens/craving_countdown_game_screen_test.dart
git commit -m "feat(games): add playable Craving Countdown Challenge screen"
```

---

## Task 2: Add Craving Countdown Challenge to the Alternatives library and wire it up

**Files:**
- Modify: `mobile/lib/data/habit_alternative_library.dart`
- Modify: `mobile/lib/screens/craving/alternative_detail_screen.dart`
- Modify: `mobile/lib/screens/craving/high_risk_screen.dart`
- Modify: `mobile/test/screens/alternative_detail_screen_test.dart`
- Modify: `mobile/test/screens/high_risk_screen_test.dart`
- Modify: `mobile/test/controllers/alternatives_controller_test.dart`
- Modify: `mobile/test/domain/habit_alternative_matcher_test.dart`

**Interfaces:**
- Consumes: `CravingCountdownGameScreen` (Task 1).

- [ ] **Step 1: Write the failing tests**

In `mobile/test/screens/alternative_detail_screen_test.dart`, add the import:

```dart
import 'package:quit_companion/screens/games/craving_countdown_game_screen.dart';
```

Add a fixture and test:

```dart
const _cravingCountdownAlternative = HabitAlternative(
  alternativeId: 'craving_countdown',
  title: 'Craving Countdown Challenge',
  description: 'Commit to beating this craving for 3 minutes',
  category: AlternativeCategory.quickFix,
  instructions: 'Stay with the feeling until the ring fills — you\'ve got this.',
);
```

```dart
  testWidgets('tapping Play on Craving Countdown Challenge opens CravingCountdownGameScreen', (tester) async {
    final controller = AlternativesController(FakeHabitAlternativeAttemptRepository());

    await tester.pumpWidget(MaterialApp(
      home: AlternativeDetailScreen(
        userId: 'u1',
        alternative: _cravingCountdownAlternative,
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

    expect(find.byType(CravingCountdownGameScreen), findsOneWidget);
  });
```

In `mobile/test/screens/high_risk_screen_test.dart`, rename "all seven" to "all eight" in the render test's title, add after the `memory_match` assertions:

```dart
    expect(find.byKey(const Key('high_risk_card_craving_countdown')), findsOneWidget);
    expect(find.text('Craving Countdown Challenge'), findsOneWidget);
```

and bump the Try This button count:

```dart
    expect(tryThisButtons, findsNWidgets(8));
```

In `mobile/test/controllers/alternatives_controller_test.dart`, bump only the two TOTAL-count assertions (NOT the game-category filter count — `craving_countdown` is `quickFix`, not `game`):

```dart
      expect(controller.recommendations, hasLength(8));
```

```dart
      expect(controller.filteredRecommendations, hasLength(8));

      controller.setFilter(AlternativeCategory.game);
      expect(controller.filteredRecommendations, hasLength(4));
      expect(controller.filteredRecommendations.every((a) => a.category == AlternativeCategory.game), isTrue);

      controller.setFilter(null);
      expect(controller.filteredRecommendations, hasLength(8));
```

In `mobile/test/domain/habit_alternative_matcher_test.dart`, add `'craving_countdown'` to the expected id set:

```dart
      expect(ranked.map((a) => a.alternativeId).toSet(), {
        'breathing',
        'cold_water',
        'short_walk',
        'bubble_pop',
        'word_puzzle',
        'tap_pop',
        'memory_match',
        'craving_countdown',
      });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart test/screens/high_risk_screen_test.dart test/controllers/alternatives_controller_test.dart test/domain/habit_alternative_matcher_test.dart`
Expected: FAIL — `'craving_countdown'` isn't in the library or wired up yet, and the count bumps don't match current (pre-Task-2) reality.

- [ ] **Step 3: Write the implementation**

In `mobile/lib/data/habit_alternative_library.dart`, add a new entry after the `memory_match` entry:

```dart
  HabitAlternative(
    alternativeId: 'craving_countdown',
    title: 'Craving Countdown Challenge',
    description: 'Commit to beating this craving for 3 minutes',
    category: AlternativeCategory.quickFix,
    instructions: 'Stay with the feeling until the ring fills — you\'ve got this.',
  ),
```

In `mobile/lib/screens/craving/alternative_detail_screen.dart`, add the import:

```dart
import '../games/craving_countdown_game_screen.dart';
```

Add `'craving_countdown'` to `_gameScreenIds`:

```dart
const _gameScreenIds = {'bubble_pop', 'word_puzzle', 'breathing', 'tap_pop', 'memory_match', 'craving_countdown'};
```

Add a case to `_openGame`'s switch:

```dart
      'craving_countdown' => const CravingCountdownGameScreen(),
```

In `mobile/lib/screens/craving/high_risk_screen.dart`, add a `_uiMeta` entry:

```dart
  'craving_countdown': _AlternativeUiMeta(
    tag: 'Quick Fix', icon: Icons.timer_outlined, iconBg: AppColors.terracottaLight, iconColor: AppColors.terracottaDark,
  ),
```

- [ ] **Step 4: Run tests, analyze, run the full suite, and commit**

Run: `cd mobile && flutter test test/screens/alternative_detail_screen_test.dart test/screens/high_risk_screen_test.dart test/controllers/alternatives_controller_test.dart test/domain/habit_alternative_matcher_test.dart`
Expected: PASS, all green.

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`

Run: `cd mobile && flutter test`
Expected: all tests pass, no regressions. Run it twice in a row to confirm stability (the Tap & Pop/Memory Match tasks each saw one transient full-suite flake resolved by a clean rerun).

```bash
git add mobile/lib/data/habit_alternative_library.dart mobile/lib/screens/craving/alternative_detail_screen.dart mobile/lib/screens/craving/high_risk_screen.dart mobile/test/screens/alternative_detail_screen_test.dart mobile/test/screens/high_risk_screen_test.dart mobile/test/controllers/alternatives_controller_test.dart mobile/test/domain/habit_alternative_matcher_test.dart
git commit -m "feat(games): add Craving Countdown Challenge to the Alternatives library"
```

---

## Post-plan verification

- [ ] `flutter analyze` — `No issues found!`
- [ ] `flutter test` — all passing, count higher than the pre-plan baseline (403) by roughly 6 (5 new screen tests + 1 new Play-button test).
- [ ] `git log --oneline -2` confirms 2 separate commits.
- [ ] This closes out all 4 requested mini-games (Breathing Bubble, Tap & Pop, Memory Match, Craving Countdown Challenge).

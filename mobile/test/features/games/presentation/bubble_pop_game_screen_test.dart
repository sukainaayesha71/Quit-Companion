import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/games/presentation/screens/bubble_pop_game_screen.dart';

/// Pumps in small increments until [condition] is true or [timeout] is
/// reached. This screen has perpetually-running animations/timers (bubbles
/// float and respawn forever), so `pumpAndSettle()` never returns and a
/// single guessed fixed-duration pump is flaky — this waits for the actual
/// condition instead of a guessed duration.
Future<void> _pumpUntil(
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

void main() {
  testWidgets('a bubble is present immediately on open', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BubblePopGameScreen()));
    await tester.pump();

    expect(find.byType(BubblePopBubbleTile), findsWidgets);
  });

  testWidgets('tapping a bubble removes it after its pop animation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BubblePopGameScreen()));
    await tester.pump();
    // The bubble starts just below the bottom edge of the screen (it
    // floats up from there) — wait until it's actually within the
    // visible/tappable viewport before trying to tap it. A bubble is
    // tappable once flutter_test's hit-testing succeeds on it, which
    // happens once its animated position is back on-screen.
    await _pumpUntil(tester, () {
      final finder = find.byType(BubblePopBubbleTile);
      if (finder.evaluate().isEmpty) return false;
      final center = tester.getCenter(finder.first, warnIfMissed: false);
      return center.dy >= 0 && center.dy <= 600;
    });
    final before = find.byType(BubblePopBubbleTile).evaluate().length;
    expect(before, greaterThan(0));

    await tester.tap(find.byType(BubblePopBubbleTile).first);
    await _pumpUntil(
      tester,
      () => find.byType(BubblePopBubbleTile).evaluate().length < before,
    );

    expect(find.byType(BubblePopBubbleTile).evaluate().length, before - 1);
  });

  testWidgets('the Done button pops the screen', (tester) async {
    // pumpAndSettle can't be used on this screen: bubbles float and
    // respawn perpetually, so animations never "settle" — wait for the
    // actual navigation condition instead of a guessed fixed duration.
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
    await _pumpUntil(
      tester,
      () =>
          find.byKey(const Key('bubble_pop_done_button')).evaluate().isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('bubble_pop_done_button')));
    await _pumpUntil(
      tester,
      () => find.byType(BubblePopGameScreen).evaluate().isEmpty,
    );

    expect(find.byType(BubblePopGameScreen), findsNothing);
  });
}

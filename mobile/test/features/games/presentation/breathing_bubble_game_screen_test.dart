import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/games/presentation/screens/breathing_bubble_game_screen.dart';
import '../../../support/pump_until.dart';

void main() {
  testWidgets('starts on "Breathe In", Cycle 1 of 6', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BreathingBubbleGameScreen()),
    );
    await tester.pump();

    expect(find.text('Breathe In'), findsOneWidget);
    expect(find.text('Cycle 1 of 6'), findsOneWidget);
  });

  testWidgets('advances to Cycle 2 of 6 after one full cycle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BreathingBubbleGameScreen()),
    );
    await tester.pump();

    // Advance in small increments rather than one big jump: a single huge
    // pump() only advances the controller's Ticker by one frame at the
    // new time, so a reset()+forward() triggered mid-jump (inside the
    // AnimationStatus.completed listener) doesn't get to consume any of
    // the *remaining* requested duration within that same pump() call —
    // it needs its own subsequent pump to make further progress. Small
    // repeated pumps (pumpUntil) let each cycle's restart actually tick.
    await pumpUntil(
      tester,
      () => find.text('Cycle 2 of 6').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    );

    expect(find.text('Cycle 2 of 6'), findsOneWidget);
  });

  testWidgets('the close button pops the screen at any point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BreathingBubbleGameScreen(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await pumpUntil(
      tester,
      () => find
          .byKey(const Key('breathing_bubble_close_button'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('breathing_bubble_close_button')));
    await pumpUntil(
      tester,
      () => find.byType(BreathingBubbleGameScreen).evaluate().isEmpty,
    );

    expect(find.byType(BreathingBubbleGameScreen), findsNothing);
  });

  testWidgets(
    'shows the completion message after all 6 cycles, and Done pops the screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BreathingBubbleGameScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await pumpUntil(
        tester,
        () => find.byType(BreathingBubbleGameScreen).evaluate().isNotEmpty,
      );

      // Same reasoning as the "advances to Cycle 2" test: six cascading
      // reset()+forward() restarts can't all be driven by one big pump().
      await pumpUntil(
        tester,
        () => find
            .byKey(const Key('breathing_bubble_completion_message'))
            .evaluate()
            .isNotEmpty,
        timeout: const Duration(seconds: 30),
      );

      expect(
        find.byKey(const Key('breathing_bubble_completion_message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('breathing_bubble_done_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('breathing_bubble_done_button')));
      await pumpUntil(
        tester,
        () => find.byType(BreathingBubbleGameScreen).evaluate().isEmpty,
      );

      expect(find.byType(BreathingBubbleGameScreen), findsNothing);
    },
  );
}

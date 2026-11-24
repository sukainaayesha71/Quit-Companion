import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/games/presentation/screens/tap_and_pop_game_screen.dart';
import '../../../support/pump_until.dart';

void main() {
  testWidgets('a dot is visible shortly after opening', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    expect(find.byType(TapAndPopDotTile), findsOneWidget);
    expect(find.text('Score: 0'), findsOneWidget);
  });

  testWidgets('tapping a dot increments the score and spawns a new dot', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    await tester.tap(find.byType(TapAndPopDotTile));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(find.text('Score: 1'), findsOneWidget);
    expect(find.byType(TapAndPopDotTile), findsOneWidget);
  });

  testWidgets('after 30 seconds, shows the summary with the final score', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    await tester.tap(find.byType(TapAndPopDotTile));
    await tester.pump(const Duration(milliseconds: 150));

    await pumpUntil(
      tester,
      () => find
          .byKey(const Key('tap_and_pop_summary_message'))
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 15),
    );

    expect(find.text('You popped 1 bubbles!'), findsOneWidget);
  });

  testWidgets('Play Again resets the score and starts a new round', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TapAndPopGameScreen()));
    await tester.pump();

    // Score at least 1 before the round ends, so seeing it reset to 0
    // afterward is a meaningful check, not a no-op.
    await tester.tap(find.byType(TapAndPopDotTile));
    await tester.pump(const Duration(milliseconds: 150));

    await pumpUntil(
      tester,
      () => find
          .byKey(const Key('tap_and_pop_summary_message'))
          .evaluate()
          .isNotEmpty,
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
    await pumpUntil(
      tester,
      () => find
          .byKey(const Key('tap_and_pop_close_button'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('tap_and_pop_close_button')));
    await pumpUntil(
      tester,
      () => find.byType(TapAndPopGameScreen).evaluate().isEmpty,
    );

    expect(find.byType(TapAndPopGameScreen), findsNothing);
  });
}

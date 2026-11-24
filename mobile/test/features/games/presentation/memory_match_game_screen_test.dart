import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/games/presentation/screens/memory_match_game_screen.dart';
import '../../../support/pump_until.dart';

// Fixed, non-shuffled board for deterministic tests: pairs sit at
// consecutive indices (0,1), (2,3), (4,5)...
const _fixedBoard = [
  Icons.air_rounded,
  Icons.air_rounded,
  Icons.favorite_rounded,
  Icons.favorite_rounded,
  Icons.savings_rounded,
  Icons.savings_rounded,
  Icons.eco_rounded,
  Icons.eco_rounded,
  Icons.psychology_rounded,
  Icons.psychology_rounded,
  Icons.calendar_today_rounded,
  Icons.calendar_today_rounded,
  Icons.emoji_events_rounded,
  Icons.emoji_events_rounded,
  Icons.water_drop_rounded,
  Icons.water_drop_rounded,
];

void main() {
  // The default 800x600 test surface only fits 3 of the 4x4 grid's rows
  // (12 of 16 cards) — GridView.builder is lazy and won't build the 4th
  // row's items unless the viewport is tall enough to need them. Enlarge
  // it so every card actually exists in the tree for these tests.
  Future<void> pumpScreen(WidgetTester tester, {List<IconData>? board}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: MemoryMatchGameScreen(board: board ?? _fixedBoard)),
    );
    await tester.pump();
  }

  testWidgets('all 16 cards start face-down', (tester) async {
    await pumpScreen(tester);

    expect(find.byIcon(Icons.help_outline_rounded), findsNWidgets(16));
    expect(find.text('Moves: 0'), findsOneWidget);
  });

  testWidgets('tapping a card reveals its icon', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('memory_card_0')));
    await tester.pump();

    expect(find.byIcon(Icons.air_rounded), findsOneWidget);
  });

  testWidgets(
    'tapping a matching pair keeps both revealed and increments moves',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('memory_card_0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('memory_card_1')));
      await tester.pump();

      expect(find.text('Moves: 1'), findsOneWidget);
      expect(find.byIcon(Icons.air_rounded), findsNWidgets(2));
    },
  );

  testWidgets('tapping a mismatching pair shows both then flips back', (
    tester,
  ) async {
    await pumpScreen(tester);

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

  testWidgets(
    'a third tap is ignored while two mismatched cards are still resolving',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('memory_card_0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('memory_card_2')));
      await tester.pump();

      // Still resolving (800ms hasn't elapsed) — this tap must be a no-op.
      await tester.tap(find.byKey(const Key('memory_card_4')));
      await tester.pump();

      expect(find.byIcon(Icons.savings_rounded), findsNothing);
      expect(find.text('Moves: 1'), findsOneWidget);

      // Let the pending mismatch-resolution timer actually fire before the
      // test ends — Flutter's test binding fails a test that leaves a
      // Timer running past completion.
      await tester.pump(const Duration(milliseconds: 900));
    },
  );

  testWidgets(
    'completing all pairs shows the completion message with the move count',
    (tester) async {
      await pumpScreen(tester);

      for (var i = 0; i < 16; i += 2) {
        await tester.tap(find.byKey(Key('memory_card_$i')));
        await tester.pump();
        await tester.tap(find.byKey(Key('memory_card_${i + 1}')));
        await tester.pump();
      }

      expect(
        find.byKey(const Key('memory_match_completion_message')),
        findsOneWidget,
      );
      expect(find.text('You did it in 8 moves!'), findsOneWidget);
    },
  );

  testWidgets('Play Again resets the board and move counter', (tester) async {
    await pumpScreen(tester);

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
    await pumpUntil(
      tester,
      () => find
          .byKey(const Key('memory_match_close_button'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('memory_match_close_button')));
    await pumpUntil(
      tester,
      () => find.byType(MemoryMatchGameScreen).evaluate().isEmpty,
    );

    expect(find.byType(MemoryMatchGameScreen), findsNothing);
  });
}

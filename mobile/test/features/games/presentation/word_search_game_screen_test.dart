import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/games/domain/word_search_generator.dart';
import 'package:quit_companion/features/games/presentation/screens/word_search_game_screen.dart';

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
      WordPlacement(
        word: 'CALM',
        cells: [Point(0, 0), Point(0, 1), Point(0, 2), Point(0, 3)],
      ),
    ],
  );
}

void main() {
  testWidgets('renders the word bank and the letter grid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WordSearchGameScreen(puzzle: _fixedPuzzle())),
    );
    await tester.pump();

    expect(find.byKey(const Key('word_search_word_CALM')), findsOneWidget);
    expect(find.byKey(const Key('word_search_cell_0_0')), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('dragging across a placed word\'s cells marks it found', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WordSearchGameScreen(puzzle: _fixedPuzzle())),
    );
    await tester.pump();

    final start = tester.getCenter(
      find.byKey(const Key('word_search_cell_0_0')),
    );
    final end = tester.getCenter(find.byKey(const Key('word_search_cell_0_3')));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    final wordText = tester.widget<Text>(
      find.byKey(const Key('word_search_word_CALM')),
    );
    expect(wordText.style?.decoration, TextDecoration.lineThrough);
    expect(
      find.byKey(const Key('word_search_all_done_message')),
      findsOneWidget,
    );
  });

  testWidgets('dragging a non-matching line does not mark anything found', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WordSearchGameScreen(puzzle: _fixedPuzzle())),
    );
    await tester.pump();

    final start = tester.getCenter(
      find.byKey(const Key('word_search_cell_5_5')),
    );
    final end = tester.getCenter(find.byKey(const Key('word_search_cell_5_7')));
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    final wordText = tester.widget<Text>(
      find.byKey(const Key('word_search_word_CALM')),
    );
    expect(wordText.style?.decoration, isNot(TextDecoration.lineThrough));
    expect(find.byKey(const Key('word_search_all_done_message')), findsNothing);
  });

  testWidgets('the Done button pops the screen at any progress state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WordSearchGameScreen(puzzle: _fixedPuzzle()),
              ),
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

  testWidgets(
    'with no puzzle injected, generates one from the real word bank',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WordSearchGameScreen()));
      await tester.pump();

      expect(find.byKey(const Key('word_search_word_CALM')), findsOneWidget);
      expect(
        find.byKey(const Key('word_search_word_PROGRESS')),
        findsOneWidget,
      );
    },
  );
}

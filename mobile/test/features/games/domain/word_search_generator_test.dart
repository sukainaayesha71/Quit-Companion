import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/games/domain/word_search_generator.dart';

void main() {
  const words = [
    'CALM',
    'HOPE',
    'FOCUS',
    'PEACE',
    'STRONG',
    'HEALING',
    'BREATHE',
    'PROGRESS',
  ];

  test('generate places every word somewhere in the grid, in-bounds', () {
    final puzzle = const WordSearchGenerator(
      size: 10,
    ).generate(words, random: Random(1));

    expect(puzzle.placements.map((p) => p.word).toSet(), words.toSet());
    for (final placement in puzzle.placements) {
      expect(placement.cells.length, placement.word.length);
      for (final cell in placement.cells) {
        expect(cell.x, inInclusiveRange(0, 9));
        expect(cell.y, inInclusiveRange(0, 9));
      }
    }
  });

  test(
    'every placed word forms a straight line in an allowed forward direction',
    () {
      final puzzle = const WordSearchGenerator(
        size: 10,
      ).generate(words, random: Random(2));

      for (final placement in puzzle.placements) {
        final cells = placement.cells;
        if (cells.length < 2) continue;
        final dRow = cells[1].x - cells[0].x;
        final dCol = cells[1].y - cells[0].y;
        // Forward-only: horizontal (0,1), vertical (1,0), or diagonal-down (1,1).
        expect(
          (dRow == 0 && dCol == 1) ||
              (dRow == 1 && dCol == 0) ||
              (dRow == 1 && dCol == 1),
          isTrue,
          reason: 'unexpected direction ($dRow, $dCol) for ${placement.word}',
        );
        for (var i = 1; i < cells.length; i++) {
          expect(cells[i].x - cells[i - 1].x, dRow);
          expect(cells[i].y - cells[i - 1].y, dCol);
        }
      }
    },
  );

  test(
    'the grid letters match each placement\'s word at every one of its cells',
    () {
      final puzzle = const WordSearchGenerator(
        size: 10,
      ).generate(words, random: Random(3));

      for (final placement in puzzle.placements) {
        for (var i = 0; i < placement.cells.length; i++) {
          final cell = placement.cells[i];
          expect(puzzle.grid[cell.x][cell.y], placement.word[i]);
        }
      }
    },
  );

  test(
    'every non-word cell is filled with a single uppercase letter, never empty',
    () {
      final puzzle = const WordSearchGenerator(
        size: 10,
      ).generate(words, random: Random(4));

      for (final row in puzzle.grid) {
        for (final cell in row) {
          expect(cell.length, 1);
          expect(cell, cell.toUpperCase());
        }
      }
    },
  );

  test('generation is deterministic for a given seed', () {
    final puzzleA = const WordSearchGenerator(
      size: 10,
    ).generate(words, random: Random(42));
    final puzzleB = const WordSearchGenerator(
      size: 10,
    ).generate(words, random: Random(42));

    expect(puzzleA.grid, puzzleB.grid);
  });
}

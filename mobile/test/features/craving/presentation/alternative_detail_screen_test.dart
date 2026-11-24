import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/habit_alternative.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/presentation/screens/alternative_detail_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/alternative_activity_history_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/breathing_bubble_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/bubble_pop_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/craving_countdown_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/memory_match_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/tap_and_pop_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/word_search_game_screen.dart';

const _alternative = HabitAlternative(
  alternativeId: 'stretching',
  title: 'Quick Stretch',
  description: 'Release tension in under a minute',
  category: AlternativeCategory.exercise,
  instructions: 'Stand up, reach your arms overhead, and hold for 10 seconds.',
);

const _bubblePopAlternative = HabitAlternative(
  alternativeId: 'bubble_pop',
  title: 'Bubble Pop Mini-Game',
  description: 'A calm, self-paced distraction',
  category: AlternativeCategory.game,
  instructions:
      'Open the Bubble Pop mini-game and pop bubbles at your own pace.',
);

const _wordPuzzleAlternative = HabitAlternative(
  alternativeId: 'word_puzzle',
  title: 'Quick Word Puzzle',
  description: 'Keep your hands and mind busy',
  category: AlternativeCategory.game,
  instructions:
      'Open the Word Puzzle mini-game and find the hidden calming words.',
);

const _tapAndPopAlternative = HabitAlternative(
  alternativeId: 'tap_pop',
  title: 'Tap & Pop',
  description: 'A quick 30-second reflex challenge',
  category: AlternativeCategory.game,
  instructions:
      'Tap the dot before it fades — see how many you can pop in 30 seconds.',
);

const _memoryMatchAlternative = HabitAlternative(
  alternativeId: 'memory_match',
  title: 'Memory Match',
  description: 'A quick icon-matching game',
  category: AlternativeCategory.game,
  instructions: 'Flip two cards at a time and find every matching pair.',
);

const _cravingCountdownAlternative = HabitAlternative(
  alternativeId: 'craving_countdown',
  title: 'Craving Countdown Challenge',
  description: 'Commit to beating this craving for 3 minutes',
  category: AlternativeCategory.quickFix,
  instructions:
      'Stay with the feeling until the ring fills — you\'ve got this.',
);

void main() {
  testWidgets(
    'renders the title and instructions, and logs an attempt on open',
    (tester) async {
      final repository = FakeHabitAlternativeAttemptRepository();
      final controller = AlternativesController(
        repository,
        now: () => DateTime(2026, 8, 19),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeDetailScreen(
            userId: 'u1',
            alternative: _alternative,
            triggerCategory: TriggerCategory.stress,
            mood: Mood.stressed,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick Stretch'), findsOneWidget);
      expect(
        find.text(
          'Stand up, reach your arms overhead, and hold for 10 seconds.',
        ),
        findsOneWidget,
      );
      expect(repository.attempts, hasLength(1));
      expect(repository.attempts.first.alternativeId, 'stretching');
    },
  );

  testWidgets(
    'tapping "Yes" records a positive outcome and shows the feedback message',
    (tester) async {
      final repository = FakeHabitAlternativeAttemptRepository();
      final controller = AlternativesController(
        repository,
        now: () => DateTime(2026, 8, 19),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeDetailScreen(
            userId: 'u1',
            alternative: _alternative,
            triggerCategory: TriggerCategory.stress,
            mood: Mood.stressed,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('alternative_detail_helped_yes')));
      await tester.pumpAndSettle();

      expect(repository.attempts.single.outcomeHelped, isTrue);
      expect(find.text('Glad that helped!'), findsOneWidget);
    },
  );

  testWidgets('tapping "No" records a negative outcome', (tester) async {
    final repository = FakeHabitAlternativeAttemptRepository();
    final controller = AlternativesController(
      repository,
      now: () => DateTime(2026, 8, 19),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlternativeDetailScreen(
          userId: 'u1',
          alternative: _alternative,
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alternative_detail_helped_no')));
    await tester.pumpAndSettle();

    expect(repository.attempts.single.outcomeHelped, isFalse);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    final controller = AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AlternativeDetailScreen(
                  userId: 'u1',
                  alternative: _alternative,
                  triggerCategory: TriggerCategory.stress,
                  mood: Mood.stressed,
                  controller: controller,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alternative_detail_back_button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlternativeDetailScreen), findsNothing);
  });

  testWidgets('the activity history action opens the user history list', (
    tester,
  ) async {
    final controller = AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlternativeDetailScreen(
          userId: 'u1',
          alternative: _alternative,
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('alternative_detail_activity_history')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlternativeActivityHistoryScreen), findsOneWidget);
    expect(find.byKey(const Key('activity_history_list')), findsOneWidget);
    expect(find.text('stretching'), findsOneWidget);
  });

  testWidgets(
    'shows a Play button for game-category alternatives, not for others',
    (tester) async {
      final controller = AlternativesController(
        FakeHabitAlternativeAttemptRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeDetailScreen(
            userId: 'u1',
            alternative: _alternative, // exercise category
            triggerCategory: TriggerCategory.stress,
            mood: Mood.stressed,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('alternative_detail_play_button')),
        findsNothing,
      );
    },
  );

  testWidgets('tapping Play on Bubble Pop opens BubblePopGameScreen', (
    tester,
  ) async {
    final controller = AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlternativeDetailScreen(
          userId: 'u1',
          alternative: _bubblePopAlternative,
          triggerCategory: TriggerCategory.boredom,
          mood: Mood.bored,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('alternative_detail_play_button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    // BubblePopGameScreen animates/spawns bubbles perpetually, so
    // pumpAndSettle() never returns for it — a couple of fixed pumps is
    // enough to get past the push transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BubblePopGameScreen), findsOneWidget);
  });

  testWidgets('tapping Play on Quick Word Puzzle opens WordSearchGameScreen', (
    tester,
  ) async {
    final controller = AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlternativeDetailScreen(
          userId: 'u1',
          alternative: _wordPuzzleAlternative,
          triggerCategory: TriggerCategory.boredom,
          mood: Mood.bored,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pumpAndSettle();

    expect(find.byType(WordSearchGameScreen), findsOneWidget);
  });

  testWidgets('tapping Play on 4-7-8 Breathing opens BreathingBubbleGameScreen', (
    tester,
  ) async {
    const breathingAlternative = HabitAlternative(
      alternativeId: 'breathing',
      title: '4-7-8 Breathing',
      description: 'Calm your nervous system in under a minute',
      category: AlternativeCategory.exercise,
      instructions:
          'Follow the bubble: breathe in as it grows, hold, then breathe out as it shrinks.',
    );
    final controller = AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlternativeDetailScreen(
          userId: 'u1',
          alternative: breathingAlternative,
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('alternative_detail_play_button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BreathingBubbleGameScreen), findsOneWidget);
  });

  testWidgets('tapping Play on Tap & Pop opens TapAndPopGameScreen', (
    tester,
  ) async {
    final controller = AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlternativeDetailScreen(
          userId: 'u1',
          alternative: _tapAndPopAlternative,
          triggerCategory: TriggerCategory.boredom,
          mood: Mood.bored,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('alternative_detail_play_button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TapAndPopGameScreen), findsOneWidget);
  });

  testWidgets('tapping Play on Memory Match opens MemoryMatchGameScreen', (
    tester,
  ) async {
    final controller = AlternativesController(
      FakeHabitAlternativeAttemptRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AlternativeDetailScreen(
          userId: 'u1',
          alternative: _memoryMatchAlternative,
          triggerCategory: TriggerCategory.boredom,
          mood: Mood.bored,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('alternative_detail_play_button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MemoryMatchGameScreen), findsOneWidget);
  });

  testWidgets(
    'tapping Play on Craving Countdown Challenge opens CravingCountdownGameScreen',
    (tester) async {
      final controller = AlternativesController(
        FakeHabitAlternativeAttemptRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeDetailScreen(
            userId: 'u1',
            alternative: _cravingCountdownAlternative,
            triggerCategory: TriggerCategory.stress,
            mood: Mood.stressed,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('alternative_detail_play_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('alternative_detail_play_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CravingCountdownGameScreen), findsOneWidget);
    },
  );
}

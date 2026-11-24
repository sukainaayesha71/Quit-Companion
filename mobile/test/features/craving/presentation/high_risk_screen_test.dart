import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/presentation/screens/alternative_detail_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/high_risk_screen.dart';

void main() {
  AlternativesController buildController() =>
      AlternativesController(FakeHabitAlternativeAttemptRepository());

  Future<void> pumpScreen(
    WidgetTester tester, {
    AlternativesController? controller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HighRiskScreen(
                  userId: 'u1',
                  triggerCategory: TriggerCategory.stress,
                  mood: Mood.stressed,
                  controller: controller ?? buildController(),
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
  }

  testWidgets(
    'renders the approved 6a layout: header, filters, and all eight alternative cards',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text("You've got this 💪"), findsOneWidget);
      expect(
        find.text('Here are a few things that might help right now.'),
        findsOneWidget,
      );

      expect(find.byKey(const Key('high_risk_filter_all')), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_filter_exercises')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('high_risk_filter_games')), findsOneWidget);

      expect(find.byKey(const Key('high_risk_card_breathing')), findsOneWidget);
      expect(find.text('4-7-8 Breathing'), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_card_cold_water')),
        findsOneWidget,
      );
      expect(find.text('Drink Cold Water'), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_card_short_walk')),
        findsOneWidget,
      );
      expect(find.text('Take a Short Walk'), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_card_bubble_pop')),
        findsOneWidget,
      );
      expect(find.text('Bubble Pop Mini-Game'), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_card_word_puzzle')),
        findsOneWidget,
      );
      expect(find.text('Quick Word Puzzle'), findsOneWidget);
      expect(find.byKey(const Key('high_risk_card_tap_pop')), findsOneWidget);
      expect(find.text('Tap & Pop'), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_card_memory_match')),
        findsOneWidget,
      );
      expect(find.text('Memory Match'), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_card_craving_countdown')),
        findsOneWidget,
      );
      expect(find.text('Craving Countdown Challenge'), findsOneWidget);
    },
  );

  testWidgets(
    'does not fabricate the success-rate personalization number from the reference',
    (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('%'), findsNothing);
    },
  );

  testWidgets(
    'shows general suggestions and reports when history cannot load',
    (tester) async {
      final controller = AlternativesController(
        FakeHabitAlternativeAttemptRepository()
          ..failWith = Exception('offline'),
      );
      await pumpScreen(tester, controller: controller);

      expect(find.byKey(const Key('high_risk_history_error')), findsOneWidget);
      expect(find.byKey(const Key('high_risk_card_breathing')), findsOneWidget);
    },
  );

  testWidgets(
    'FR7 (Module 7): every Try This button is enabled and opens AlternativeDetailScreen',
    (tester) async {
      await pumpScreen(tester);

      final tryThisButtons = find.byWidgetPredicate((w) => w is OutlinedButton);
      expect(tryThisButtons, findsNWidgets(8));
      for (final element in tryThisButtons.evaluate()) {
        final button = element.widget as OutlinedButton;
        expect(button.onPressed, isNotNull);
      }

      await tester.tap(find.byKey(const Key('high_risk_try_this_breathing')));
      await tester.pumpAndSettle();

      expect(find.byType(AlternativeDetailScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Exercises filter shows only exercise-category cards',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('high_risk_filter_exercises')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('high_risk_card_breathing')), findsOneWidget);
      expect(
        find.byKey(const Key('high_risk_card_short_walk')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('high_risk_card_cold_water')), findsNothing);
      expect(find.byKey(const Key('high_risk_card_bubble_pop')), findsNothing);
      expect(find.byKey(const Key('high_risk_card_word_puzzle')), findsNothing);
    },
  );

  testWidgets('tapping the Games filter then All restores the full list', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('high_risk_filter_games')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('high_risk_card_bubble_pop')), findsOneWidget);
    expect(find.byKey(const Key('high_risk_card_breathing')), findsNothing);

    await tester.tap(find.byKey(const Key('high_risk_filter_all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('high_risk_card_breathing')), findsOneWidget);
    expect(find.byKey(const Key('high_risk_card_bubble_pop')), findsOneWidget);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('high_risk_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(HighRiskScreen), findsNothing);
  });

  testWidgets('the "Skip for now" link returns to the previous screen', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.byKey(const Key('high_risk_skip_link')));
    await tester.tap(find.byKey(const Key('high_risk_skip_link')));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(HighRiskScreen), findsNothing);
  });
}

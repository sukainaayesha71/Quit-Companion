import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/games/presentation/screens/craving_countdown_game_screen.dart';
import '../../../support/pump_until.dart';

void main() {
  testWidgets('starts at 3:00 with an encouraging message shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CravingCountdownGameScreen()),
    );
    await tester.pump();

    expect(find.text('3:00'), findsOneWidget);
    expect(find.byKey(const Key('craving_countdown_message')), findsOneWidget);
  });

  testWidgets('the message changes after the first 30-second segment', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CravingCountdownGameScreen()),
    );
    await tester.pump();
    final firstMessage = tester
        .widget<Text>(find.byKey(const Key('craving_countdown_message')))
        .data;

    await pumpUntil(
      tester,
      () =>
          tester
              .widget<Text>(find.byKey(const Key('craving_countdown_message')))
              .data !=
          firstMessage,
      timeout: const Duration(seconds: 15),
    );
  });

  testWidgets('after the full 3 minutes, shows the completion message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CravingCountdownGameScreen()),
    );
    await tester.pump();

    await pumpUntil(
      tester,
      () => find
          .byKey(const Key('craving_countdown_completion_message'))
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    expect(find.text('You beat the craving!'), findsOneWidget);
    expect(
      find.byKey(const Key('craving_countdown_play_again_button')),
      findsOneWidget,
    );
  });

  testWidgets('Play Again resets the timer to 3:00', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CravingCountdownGameScreen()),
    );
    await tester.pump();

    await pumpUntil(
      tester,
      () => find
          .byKey(const Key('craving_countdown_completion_message'))
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    await tester.tap(
      find.byKey(const Key('craving_countdown_play_again_button')),
    );
    await tester.pump();

    expect(find.text('3:00'), findsOneWidget);
  });

  testWidgets('the close button pops the screen at any point', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CravingCountdownGameScreen(),
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
          .byKey(const Key('craving_countdown_close_button'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('craving_countdown_close_button')));
    await pumpUntil(
      tester,
      () => find.byType(CravingCountdownGameScreen).evaluate().isEmpty,
    );

    expect(find.byType(CravingCountdownGameScreen), findsNothing);
  });
}

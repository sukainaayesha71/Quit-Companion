import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_screen.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';

class _PendingHealthBotClient extends FakeHealthBotClient {
  final answer = Completer<HealthBotAnswer>();
  @override
  Future<HealthBotAnswer> ask({
    required String query,
    List<HealthBotTurn> history = const [],
    HealthBotUserContext? userContext,
  }) => answer.future;
}

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'typing indicator disappears after ${fails ? "failure" : "reply"}',
      (tester) async {
        final client = _PendingHealthBotClient();
        final controller = HealthBotController(
          client,
          FakeHealthBotRepository(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: HealthBotScreen(userId: 'u1', controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('healthbot_input_field')),
          'Help with cravings',
        );
        await tester.tap(find.byKey(const Key('healthbot_send_button')));
        await tester.pump();
        expect(
          find.byKey(const Key('healthbot_typing_indicator')),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byKey(const Key('healthbot_typing_indicator')),
          findsOneWidget,
        );
        if (fails) {
          client.answer.completeError(HealthBotClientException('Unavailable'));
        } else {
          client.answer.complete(
            const HealthBotAnswer(
              type: HealthBotAnswerType.matched,
              responseText: 'Try a short distraction.',
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('healthbot_typing_indicator')),
          findsNothing,
        );
      },
    );
  }
  testWidgets('opens long history at the latest exchange', (tester) async {
    final repository = FakeHealthBotRepository();
    for (var i = 0; i < 30; i++) {
      repository.logged.add(
        HealthBotConversation(
          conversationId: '$i',
          userId: 'u1',
          query: 'Question $i',
          botResponse: 'Response $i',
          timestamp: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );
    }
    final controller = HealthBotController(FakeHealthBotClient(), repository);
    await tester.pumpWidget(
      MaterialApp(
        home: HealthBotScreen(userId: 'u1', controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Response 29').hitTestable(), findsOneWidget);
    expect(find.text('Question 0').hitTestable(), findsNothing);
    await tester.drag(
      find.byKey(const Key('healthbot_transcript')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Response 29').hitTestable(), findsNothing);
  });

  HealthBotController buildController({FakeHealthBotClient? client}) {
    return HealthBotController(
      client ?? FakeHealthBotClient(),
      FakeHealthBotRepository(),
    );
  }

  testWidgets(
    'shows the disclaimer and blocks the input field until acknowledged',
    (tester) async {
      final controller = buildController();

      await tester.pumpWidget(
        MaterialApp(
          home: HealthBotScreen(userId: 'u1', controller: controller),
        ),
      );

      expect(
        find.byKey(const Key('healthbot_disclaimer_banner')),
        findsOneWidget,
      );
      expect(find.text('Not a substitute for medical advice.'), findsOneWidget);
      expect(
        find.textContaining('Your messages are sent to Google Gemini'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('healthbot_input_field')), findsNothing);

      await tester.tap(
        find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('healthbot_input_field')), findsOneWidget);
    },
  );

  testWidgets(
    'typing a query and tapping send shows it and the bot reply in the transcript',
    (tester) async {
      final client = FakeHealthBotClient(
        nextAnswer: const HealthBotAnswer(
          type: HealthBotAnswerType.matched,
          responseText: 'Headaches are common.',
        ),
      );
      final controller = buildController(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: HealthBotScreen(userId: 'u1', controller: controller),
        ),
      );

      await tester.tap(
        find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('healthbot_input_field')),
        'I have a headache',
      );
      await tester.tap(find.byKey(const Key('healthbot_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('I have a headache'), findsOneWidget);
      expect(find.text('Headaches are common.'), findsOneWidget);
    },
  );

  testWidgets('tapping a suggested chip sends that exact question', (
    tester,
  ) async {
    final client = FakeHealthBotClient(
      nextAnswer: const HealthBotAnswer(
        type: HealthBotAnswerType.matched,
        responseText: 'Trouble sleeping is common.',
      ),
    );
    final controller = buildController(client: client);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthBotScreen(userId: 'u1', controller: controller),
      ),
    );

    await tester.tap(
      find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('healthbot_chip_sleep')));
    await tester.pumpAndSettle();

    expect(client.askedQueries, ['Why can\'t I sleep?']);
    // The chip label and the now-sent transcript message share the same
    // text, so both the chip itself and the transcript bubble match.
    expect(find.text('Why can\'t I sleep?'), findsNWidgets(2));
  });

  testWidgets('an emergency answer renders with distinct emergency styling', (
    tester,
  ) async {
    final client = FakeHealthBotClient(
      nextAnswer: const HealthBotAnswer(
        type: HealthBotAnswerType.emergency,
        responseText:
            'This sounds like it could be a medical emergency. Please seek emergency medical care immediately.',
      ),
    );
    final controller = buildController(client: client);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthBotScreen(userId: 'u1', controller: controller),
      ),
    );

    await tester.tap(
      find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('healthbot_input_field')),
      'chest pain',
    );
    await tester.tap(find.byKey(const Key('healthbot_send_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('healthbot_message_1_emergency')),
      findsOneWidget,
    );
  });

  testWidgets('an unmatched query shows the exact SRDS fallback text', (
    tester,
  ) async {
    final client = FakeHealthBotClient(
      nextAnswer: const HealthBotAnswer(
        type: HealthBotAnswerType.unmatched,
        responseText:
            'I cannot answer this confidently. Please consult a doctor.',
      ),
    );
    final controller = buildController(client: client);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthBotScreen(userId: 'u1', controller: controller),
      ),
    );

    await tester.tap(
      find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('healthbot_input_field')),
      'random nonsense',
    );
    await tester.tap(find.byKey(const Key('healthbot_send_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('I cannot answer this confidently. Please consult a doctor.'),
      findsOneWidget,
    );
  });

  group('SRDS 4.2 crisis support access', () {
    testWidgets(
      'the app-bar button opens Crisis Support even before the disclaimer is accepted',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: HealthBotScreen(userId: 'u1', controller: buildController()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('healthbot_disclaimer_banner')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('healthbot_crisis_support_button')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CrisisSupportScreen), findsOneWidget);
      },
    );

    testWidgets(
      'an emergency reply keeps its referral text and adds a crisis-support link',
      (tester) async {
        const referral =
            'This sounds like it could be a medical emergency. Please seek emergency medical care immediately.';
        final controller = buildController(
          client: FakeHealthBotClient(
            nextAnswer: const HealthBotAnswer(
              type: HealthBotAnswerType.emergency,
              responseText: referral,
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: HealthBotScreen(userId: 'u1', controller: controller),
          ),
        );
        await tester.tap(
          find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('healthbot_input_field')),
          'I want to end my life',
        );
        await tester.tap(find.byKey(const Key('healthbot_send_button')));
        await tester.pumpAndSettle();

        expect(find.text(referral), findsOneWidget);
        final link = find.byKey(
          const Key('healthbot_emergency_crisis_support_1'),
        );
        expect(link, findsOneWidget);
        // Non-emergency bubbles get no link.
        expect(
          find.byKey(const Key('healthbot_emergency_crisis_support_0')),
          findsNothing,
        );

        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(CrisisSupportScreen), findsOneWidget);
      },
    );
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/http_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/domain/local_health_bot_fallback.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_screen.dart';

/// Phone-test fix (2026-11-23): curated or offline guidance is shown as
/// clean text with an honest note (never a raw "took too long" line and
/// never presented as AI); a reply with no answer offers "Try again".
void main() {
  const source = HealthBotSource(
    title: 'Tips for Quitting (CDC)',
    url: 'https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/index.html',
  );

  group('HttpHealthBotClient', () {
    HttpHealthBotClient clientReturning(Map<String, dynamic> body) =>
        HttpHealthBotClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode(body), 200),
          ),
          getIdToken: () async => 'token',
        );

    test('parses answer_source and fallback_reason', () async {
      final answer = await clientReturning({
        'answer_type': 'matched',
        'response_text': 'Headaches usually ease.',
        'answer_source': 'curated',
        'fallback_reason': 'timeout',
      }).ask(query: 'headache');
      expect(answer.source, HealthBotAnswerSource.curated);
      expect(answer.fallbackReason, HealthBotFallbackReason.timeout);
      expect(answer.responseText, 'Headaches usually ease.');
    });

    test('an older backend without the fields is unknown, not AI', () async {
      final answer = await clientReturning({
        'answer_type': 'matched',
        'response_text': 'x',
      }).ask(query: 'q');
      expect(answer.source, HealthBotAnswerSource.unknown);
      expect(answer.fallbackReason, isNull);
    });

    test('a connection failure is reported as unreachable', () async {
      final client = HttpHealthBotClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((_) async => throw Exception('no route')),
        getIdToken: () async => 'token',
      );
      expect(
        () => client.ask(query: 'q'),
        throwsA(isA<HealthBotUnreachableException>()),
      );
    });
  });

  group('HealthBotController', () {
    Future<HealthBotController> send(
      HealthBotAnswer? answer, {
      Object? failWith,
      FakeHealthBotRepository? repository,
      String text = 'I have a headache',
    }) async {
      final client = FakeHealthBotClient();
      if (answer != null) client.nextAnswer = answer;
      client.failWith = failWith;
      final controller = HealthBotController(
        client,
        repository ?? FakeHealthBotRepository(),
      );
      await controller.sendQuery(userId: 'u1', text: text);
      return controller;
    }

    test('an AI answer has no note and no retry', () async {
      final c = await send(
        const HealthBotAnswer(
          type: HealthBotAnswerType.matched,
          responseText: 'A tailored answer.',
          source: HealthBotAnswerSource.ai,
        ),
      );
      expect(c.transcript.last.text, 'A tailored answer.');
      expect(c.transcript.last.note, isNull);
      expect(c.transcript.last.answerSource, HealthBotAnswerSource.ai);
      expect(c.transcript.last.retryQuery, isNull);
    });

    test(
      'a curated timeout fallback keeps its clean text and sources, no visible note, source recorded',
      () async {
        final c = await send(
          const HealthBotAnswer(
            type: HealthBotAnswerType.matched,
            responseText: 'Headaches usually ease within two weeks.',
            sources: [source],
            source: HealthBotAnswerSource.curated,
            fallbackReason: HealthBotFallbackReason.timeout,
          ),
        );
        final message = c.transcript.last;
        expect(message.text, 'Headaches usually ease within two weeks.');
        // No visible note (owner decision); the origin is kept internally.
        expect(message.note, isNull);
        expect(message.answerSource, HealthBotAnswerSource.curated);
        expect(message.sources, [source]);
        expect(message.retryQuery, isNull);
        expect(message.text, isNot(contains('took too long')));
      },
    );

    test(
      'a curated fallback with no matching answer becomes a friendly message with Try again',
      () async {
        final c = await send(
          const HealthBotAnswer(
            type: HealthBotAnswerType.unmatched,
            responseText:
                'I cannot answer this confidently. Please consult a doctor.',
            source: HealthBotAnswerSource.curated,
            fallbackReason: HealthBotFallbackReason.timeout,
          ),
          text: '  what about tomorrow  ',
        );
        expect(c.transcript.last.text, HealthBotController.noAnswerText);
        expect(c.transcript.last.retryQuery, 'what about tomorrow');
        expect(c.transcript.last.note, isNull);
      },
    );

    test(
      'an AI out-of-scope reply (unmatched, no fallback) is a real answer: no retry',
      () async {
        final c = await send(
          const HealthBotAnswer(
            type: HealthBotAnswerType.unmatched,
            responseText: 'I can only help with quitting nicotine.',
            source: HealthBotAnswerSource.ai,
          ),
        );
        expect(
          c.transcript.last.text,
          'I can only help with quitting nicotine.',
        );
        expect(c.transcript.last.retryQuery, isNull);
      },
    );

    for (final error in [
      HealthBotTimeoutException(
        'The Health-Bot is taking too long to respond.',
      ),
      HealthBotUnreachableException('Could not reach the Health-Bot service.'),
    ]) {
      test(
        '${error.runtimeType}: clean offline guidance with an offline note',
        () async {
          final c = await send(null, failWith: error);
          expect(
            c.transcript.last.text,
            LocalHealthBotFallback.generalGuidance,
          );
          expect(c.transcript.last.note, HealthBotController.offlineNote);
          expect(c.transcript.last.answerSource, HealthBotAnswerSource.offline);
          expect(c.transcript.last.text, isNot(contains('too long')));
          expect(
            c.transcript.last.sources,
            LocalHealthBotFallback.generalSources,
          );
        },
      );
    }

    test(
      'an emergency reply is unchanged: no note, no retry, no sources',
      () async {
        for (final answer in [
          const HealthBotAnswer(
            type: HealthBotAnswerType.emergency,
            responseText: LocalHealthBotFallback.emergencyResponseText,
            source: HealthBotAnswerSource.safety,
          ),
        ]) {
          final c = await send(answer, text: 'I want to end my life');
          expect(c.transcript.last.isEmergency, isTrue);
          expect(
            c.transcript.last.text,
            LocalHealthBotFallback.emergencyResponseText,
          );
          expect(c.transcript.last.note, isNull);
          expect(c.transcript.last.retryQuery, isNull);
        }
        // Offline crisis detection too.
        final offline = await send(
          null,
          failWith: HealthBotTimeoutException('slow'),
          text: 'I want to end my life',
        );
        expect(offline.transcript.last.isEmergency, isTrue);
        expect(offline.transcript.last.note, isNull);
      },
    );

    test(
      'the answer source is saved with the conversation and restored',
      () async {
        final repo = FakeHealthBotRepository();
        await send(
          const HealthBotAnswer(
            type: HealthBotAnswerType.matched,
            responseText: 'Curated text.',
            source: HealthBotAnswerSource.curated,
            fallbackReason: HealthBotFallbackReason.unavailable,
          ),
          repository: repo,
        );
        await Future<void>.delayed(Duration.zero);
        expect(repo.logged.single.note, isNull);
        expect(repo.logged.single.answerSource, HealthBotAnswerSource.curated);

        final restored = HealthBotController(FakeHealthBotClient(), repo);
        await restored.loadHistory('u1');
        expect(restored.transcript.last.note, isNull);
        expect(
          restored.transcript.last.answerSource,
          HealthBotAnswerSource.curated,
        );
        expect(restored.transcript.last.retryQuery, isNull);
      },
    );

    test('older history records without a note load unchanged', () async {
      final repo = FakeHealthBotRepository()
        ..logged.add(
          HealthBotConversation(
            conversationId: '1',
            userId: 'u1',
            query: 'q',
            botResponse: 'old reply',
            timestamp: DateTime(2026, 11, 1),
          ),
        );
      final c = HealthBotController(FakeHealthBotClient(), repo);
      await c.loadHistory('u1');
      expect(c.transcript.last.text, 'old reply');
      expect(c.transcript.last.note, isNull);
    });
  });

  group('HealthBotScreen', () {
    Future<FakeHealthBotClient> pumpAndAsk(
      WidgetTester tester,
      HealthBotAnswer answer, {
      String query = 'I have a headache',
    }) async {
      final client = FakeHealthBotClient(nextAnswer: answer);
      final controller = HealthBotController(client, FakeHealthBotRepository());
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
        query,
      );
      await tester.tap(find.byKey(const Key('healthbot_send_button')));
      await tester.pumpAndSettle();
      return client;
    }

    testWidgets('a curated answer shows only its clean text, with no note', (
      tester,
    ) async {
      await pumpAndAsk(
        tester,
        const HealthBotAnswer(
          type: HealthBotAnswerType.matched,
          responseText: 'Headaches usually ease within two weeks.',
          source: HealthBotAnswerSource.curated,
          fallbackReason: HealthBotFallbackReason.timeout,
        ),
      );
      expect(
        find.text('Headaches usually ease within two weeks.'),
        findsOneWidget,
      );
      // No italic note under a curated answer; nothing claims it is AI.
      expect(find.byKey(const Key('healthbot_note_1')), findsNothing);
      expect(find.textContaining('not AI-generated'), findsNothing);
      expect(find.textContaining('General guidance:'), findsNothing);
      expect(find.textContaining('took too long'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('an AI answer shows no note', (tester) async {
      await pumpAndAsk(
        tester,
        const HealthBotAnswer(
          type: HealthBotAnswerType.matched,
          responseText: 'A tailored answer.',
          source: HealthBotAnswerSource.ai,
        ),
      );
      expect(find.text('A tailored answer.'), findsOneWidget);
      expect(find.byKey(const Key('healthbot_note_1')), findsNothing);
    });

    testWidgets('"Try again" resends the same question', (tester) async {
      final client = await pumpAndAsk(
        tester,
        const HealthBotAnswer(
          type: HealthBotAnswerType.unmatched,
          responseText:
              'I cannot answer this confidently. Please consult a doctor.',
          source: HealthBotAnswerSource.curated,
          fallbackReason: HealthBotFallbackReason.timeout,
        ),
        query: 'how long do cravings last',
      );
      expect(find.text(HealthBotController.noAnswerText), findsOneWidget);
      client.nextAnswer = const HealthBotAnswer(
        type: HealthBotAnswerType.matched,
        responseText: 'Most cravings pass within minutes.',
        source: HealthBotAnswerSource.ai,
      );
      await tester.tap(find.byKey(const Key('healthbot_retry_1')));
      await tester.pumpAndSettle();
      expect(client.askedQueries, [
        'how long do cravings last',
        'how long do cravings last',
      ]);
      expect(find.text('Most cravings pass within minutes.'), findsOneWidget);
    });

    testWidgets(
      'an emergency reply still shows the crisis button and no note',
      (tester) async {
        await pumpAndAsk(
          tester,
          const HealthBotAnswer(
            type: HealthBotAnswerType.emergency,
            responseText: LocalHealthBotFallback.emergencyResponseText,
            source: HealthBotAnswerSource.safety,
          ),
          query: 'I want to end my life',
        );
        expect(
          find.byKey(const Key('healthbot_emergency_crisis_support_1')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('healthbot_note_1')), findsNothing);
        await tester.tap(
          find.byKey(const Key('healthbot_emergency_crisis_support_1')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CrisisSupportScreen), findsOneWidget);
      },
    );
  });
}

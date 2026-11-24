import 'dart:async';
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
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_screen.dart';

/// FR8 Health-Bot improvements: topic sources, response-time budget,
/// curated fallback when the backend is slow/unreachable, and unchanged
/// crisis handling.
const _withdrawal = HealthBotSource(
  title: 'Managing Nicotine Withdrawal (Smokefree.gov, NCI)',
  url:
      'https://smokefree.gov/challenges-when-quitting/withdrawal/managing-nicotine-withdrawal',
);
const _nci = HealthBotSource(
  title:
      'Handling Nicotine Withdrawal and Triggers (National Cancer Institute)',
  url:
      'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
);

void main() {
  group('LocalHealthBotFallback', () {
    const fallback = LocalHealthBotFallback();

    test(
      'crisis phrases get the exact backend emergency referral, no sources',
      () {
        for (final query in [
          'I feel SUICIDAL tonight',
          'I want to end my life',
          "I can't breathe",
          'chest pain since this morning',
        ]) {
          final answer = fallback.answer(query);
          expect(answer.type, HealthBotAnswerType.emergency, reason: query);
          expect(
            answer.responseText,
            LocalHealthBotFallback.emergencyResponseText,
          );
          expect(answer.sources, isEmpty);
        }
      },
    );

    test(
      'other questions get clean, non-diagnostic general guidance with sources, marked offline',
      () {
        final answer = fallback.answer('why am I so tired');
        expect(answer.type, HealthBotAnswerType.matched);
        // No technical prefix in the text; the origin is a separate field.
        expect(answer.responseText, LocalHealthBotFallback.generalGuidance);
        expect(answer.source, HealthBotAnswerSource.offline);
        expect(answer.responseText, contains('check with a doctor'));
        expect(answer.sources, LocalHealthBotFallback.generalSources);
        expect(answer.isLocalFallback, isTrue);
        for (final word in ['you have', 'diagnos', 'mg', 'dose']) {
          expect(
            answer.responseText.toLowerCase().contains(word),
            isFalse,
            reason: word,
          );
        }
      },
    );

    test('the offline emergency reply is marked safety, not AI', () {
      final answer = fallback.answer('I want to end my life');
      expect(answer.source, HealthBotAnswerSource.safety);
      expect(answer.isLocalFallback, isTrue);
    });

    test('general sources are https public-health pages', () {
      for (final source in LocalHealthBotFallback.generalSources) {
        final host = Uri.parse(source.url).host;
        expect(source.url, startsWith('https://'));
        expect(['www.cdc.gov', 'www.cancer.gov'], contains(host));
      }
    });
  });

  group('HttpHealthBotClient FR8', () {
    HttpHealthBotClient build(
      MockClient mock, {
      Duration timeout = HttpHealthBotClient.defaultRequestTimeout,
    }) => HttpHealthBotClient(
      baseUrl: 'http://backend.test',
      httpClient: mock,
      getIdToken: () async => 'token',
      requestTimeout: timeout,
    );

    test('parses titled sources', () async {
      final client = build(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'answer_type': 'matched',
              'response_text': 'Headaches usually fade.',
              'source_urls': [_withdrawal.url, _nci.url],
              'sources': [_withdrawal.toMap(), _nci.toMap()],
            }),
            200,
          ),
        ),
      );

      final answer = await client.ask(query: 'headache');

      expect(answer.sources, [_withdrawal, _nci]);
    });

    test(
      'falls back to source_urls from older backends and drops non-https links',
      () async {
        final client = build(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'answer_type': 'matched',
                'response_text': 'ok',
                'source_urls': [_nci.url, 'http://insecure.example'],
              }),
              200,
            ),
          ),
        );

        final answer = await client.ask(query: 'headache');

        expect(answer.sources, hasLength(1));
        expect(answer.sources.single.url, _nci.url);
        expect(answer.sources.single.title, 'www.cancer.gov');
      },
    );

    test('an emergency answer without sources parses to none', () async {
      final client = build(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'answer_type': 'emergency',
              'response_text': LocalHealthBotFallback.emergencyResponseText,
              'source_urls': <String>[],
              'sources': <Object>[],
            }),
            200,
          ),
        ),
      );
      final answer = await client.ask(query: 'chest pain');
      expect(answer.type, HealthBotAnswerType.emergency);
      expect(answer.sources, isEmpty);
    });

    test(
      'a request slower than the budget throws HealthBotTimeoutException',
      () async {
        final never = Completer<http.Response>();
        final client = build(
          MockClient((_) => never.future),
          timeout: const Duration(milliseconds: 50),
        );

        await expectLater(
          client.ask(query: 'headache'),
          throwsA(isA<HealthBotTimeoutException>()),
        );
      },
    );
  });

  group('HealthBotController FR8', () {
    test(
      'sources from the answer reach the transcript and the saved history',
      () async {
        final repo = FakeHealthBotRepository();
        final controller = HealthBotController(
          FakeHealthBotClient(
            nextAnswer: const HealthBotAnswer(
              type: HealthBotAnswerType.matched,
              responseText: 'Headaches usually fade within weeks.',
              sources: [_withdrawal, _nci],
            ),
          ),
          repo,
        );

        await controller.sendQuery(userId: 'u1', text: 'headache');
        await Future<void>.delayed(Duration.zero);

        expect(controller.transcript.last.sources, [_withdrawal, _nci]);
        expect(repo.logged.single.sources, [_withdrawal, _nci]);
        expect(controller.lastResponseTime, isNotNull);

        // Restored history keeps the sources.
        final restored = HealthBotController(FakeHealthBotClient(), repo);
        await restored.loadHistory('u1');
        expect(restored.transcript.last.sources, [_withdrawal, _nci]);
      },
    );

    test(
      'a backend timeout produces the curated fallback, not an error bubble',
      () async {
        final client = FakeHealthBotClient()
          ..failWith = HealthBotTimeoutException(
            'The Health-Bot is taking too long to respond.',
          );
        final controller = HealthBotController(
          client,
          FakeHealthBotRepository(),
        );

        await controller.sendQuery(userId: 'u1', text: 'why am I so tired');

        final reply = controller.transcript.last;
        // Clean guidance first; the slow backend is explained by a short
        // offline note instead of a raw technical line in the reply.
        expect(reply.text, LocalHealthBotFallback.generalGuidance);
        expect(reply.note, HealthBotController.offlineNote);
        expect(reply.isEmergency, isFalse);
        expect(reply.sources, LocalHealthBotFallback.generalSources);
        expect(controller.status, HealthBotStatus.idle);
      },
    );

    test('offline crisis messages still get the emergency referral', () async {
      final client = FakeHealthBotClient()
        ..failWith = HealthBotClientException(
          'Could not reach the Health-Bot service. Check your connection.',
        );
      final repo = FakeHealthBotRepository();
      final controller = HealthBotController(client, repo);

      await controller.sendQuery(userId: 'u1', text: 'I feel suicidal');
      await Future<void>.delayed(Duration.zero);

      final reply = controller.transcript.last;
      expect(reply.isEmergency, isTrue);
      expect(reply.text, LocalHealthBotFallback.emergencyResponseText);
      expect(reply.sources, isEmpty);
      expect(repo.logged.single.isEmergency, isTrue);
    });

    test('backend emergency answers never show sources even if sent', () async {
      final controller = HealthBotController(
        FakeHealthBotClient(
          nextAnswer: const HealthBotAnswer(
            type: HealthBotAnswerType.emergency,
            responseText: LocalHealthBotFallback.emergencyResponseText,
            sources: [_nci],
          ),
        ),
        FakeHealthBotRepository(),
      );
      await controller.sendQuery(userId: 'u1', text: 'chest pain');
      expect(controller.transcript.last.sources, isEmpty);
    });
  });

  group('HealthBotScreen FR8', () {
    Future<void> openChat(
      WidgetTester tester,
      HealthBotController controller, {
      Future<bool> Function(String url)? openUrl,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HealthBotScreen(
            userId: 'u1',
            controller: controller,
            openUrl: openUrl,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
      );
      await tester.pumpAndSettle();
    }

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(
        find.byKey(const Key('healthbot_input_field')),
        text,
      );
      await tester.tap(find.byKey(const Key('healthbot_send_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows topic sources under a reply and opens them', (
      tester,
    ) async {
      final opened = <String>[];
      final controller = HealthBotController(
        FakeHealthBotClient(
          nextAnswer: const HealthBotAnswer(
            type: HealthBotAnswerType.matched,
            responseText: 'Headaches usually fade within weeks.',
            sources: [_withdrawal, _nci],
          ),
        ),
        FakeHealthBotRepository(),
      );
      await openChat(
        tester,
        controller,
        openUrl: (url) async {
          opened.add(url);
          return true;
        },
      );

      await send(tester, 'I have a headache');

      expect(find.byKey(const Key('healthbot_sources_1')), findsOneWidget);
      expect(find.text(_withdrawal.title), findsOneWidget);
      expect(find.text(_nci.title), findsOneWidget);

      await tester.tap(find.byKey(const Key('healthbot_source_link_0')));
      await tester.pump();
      expect(opened, [_withdrawal.url]);
    });

    testWidgets(
      'an offline crisis message shows the emergency bubble with crisis support and no sources',
      (tester) async {
        final controller = HealthBotController(
          FakeHealthBotClient()..failWith = HealthBotClientException('offline'),
          FakeHealthBotRepository(),
        );
        await openChat(tester, controller);

        await send(tester, 'I want to end my life');

        expect(
          find.byKey(const Key('healthbot_message_1_emergency')),
          findsOneWidget,
        );
        expect(
          find.text(LocalHealthBotFallback.emergencyResponseText),
          findsOneWidget,
        );
        expect(find.byKey(const Key('healthbot_sources_1')), findsNothing);
        await tester.tap(
          find.byKey(const Key('healthbot_emergency_crisis_support_1')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CrisisSupportScreen), findsOneWidget);
      },
    );

    testWidgets('the medical disclaimer is still required on every visit', (
      tester,
    ) async {
      final controller = HealthBotController(
        FakeHealthBotClient(),
        FakeHealthBotRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HealthBotScreen(userId: 'u1', controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('healthbot_disclaimer_banner')),
        findsOneWidget,
      );
      expect(find.text('Not a substitute for medical advice.'), findsOneWidget);
    });
  });
}

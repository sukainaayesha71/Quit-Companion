import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/http_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/domain/health_bot_user_context.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';

const _matched = HealthBotAnswer(
  type: HealthBotAnswerType.matched,
  responseText: 'Nicotine reaches the brain within seconds.',
  source: HealthBotAnswerSource.ai,
);

void main() {
  group('HttpHealthBotClient conversation payload', () {
    Future<Map<String, dynamic>> sentBody(
      Future<void> Function(HttpHealthBotClient client) send,
    ) async {
      late http.Request captured;
      final client = HttpHealthBotClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            '{"answer_type":"matched","response_text":"ok"}',
            200,
          );
        }),
        getIdToken: () async => 'token',
      );
      await send(client);
      return jsonDecode(captured.body) as Map<String, dynamic>;
    }

    test('sends recent history and the user context', () async {
      final body = await sentBody(
        (client) => client.ask(
          query: 'Can you explain this in simple words?',
          history: const [
            HealthBotTurn(fromUser: true, text: 'Why does nicotine hook you?'),
            HealthBotTurn(fromUser: false, text: 'It acts on reward areas.'),
          ],
          userContext: const HealthBotUserContext(
            product: 'vape',
            daysSinceQuit: 3,
            quitStrategy: 'coldTurkey',
          ),
        ),
      );
      expect(body, {
        'query': 'Can you explain this in simple words?',
        'history': [
          {'role': 'user', 'text': 'Why does nicotine hook you?'},
          {'role': 'assistant', 'text': 'It acts on reward areas.'},
        ],
        'user_context': {
          'product': 'vape',
          'days_since_quit': 3,
          'quit_strategy': 'coldTurkey',
        },
      });
    });

    test('a first question sends only the query, as before', () async {
      final body = await sentBody(
        (client) => client.ask(
          query: 'hi',
          userContext: const HealthBotUserContext(),
        ),
      );
      expect(body, {'query': 'hi'});
    });

    test('only known context fields are sent', () async {
      final body = await sentBody(
        (client) => client.ask(
          query: 'hi',
          userContext: const HealthBotUserContext(daysSinceQuit: -2),
        ),
      );
      expect(body['user_context'], {'days_since_quit': -2});
    });

    test('the request budget leaves room for the backend Gemini budget', () {
      expect(
        HttpHealthBotClient.defaultRequestTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 15)),
      );
    });
  });

  group('HealthBotController conversation memory', () {
    test('sends earlier messages oldest first, not the new question', () async {
      final client = FakeHealthBotClient(nextAnswer: _matched);
      final controller = HealthBotController(
        client,
        FakeHealthBotRepository(),
      );

      await controller.sendQuery(userId: 'u1', text: 'Why does nicotine hook you?');
      await controller.sendQuery(userId: 'u1', text: 'explain it simply');

      expect(client.askedHistories.first, isEmpty);
      expect(client.askedHistories.last, const [
        HealthBotTurn(fromUser: true, text: 'Why does nicotine hook you?'),
        HealthBotTurn(fromUser: false, text: _matchedText),
      ]);
    });

    test('keeps only the most recent messages', () async {
      final client = FakeHealthBotClient(nextAnswer: _matched);
      final controller = HealthBotController(
        client,
        FakeHealthBotRepository(),
      );
      for (var i = 0; i < 8; i++) {
        await controller.sendQuery(userId: 'u1', text: 'question $i');
      }
      final history = client.askedHistories.last;
      expect(history, hasLength(HealthBotController.maxHistoryMessages));
      expect(history.last.fromUser, isFalse);
      expect(history.first, const HealthBotTurn(fromUser: true, text: 'question 2'));
    });

    test('user messages are redacted and no-answer placeholders skipped', () async {
      final client = FakeHealthBotClient(nextAnswer: _matched);
      final controller = HealthBotController(
        client,
        FakeHealthBotRepository(),
        currentDisplayName: () => 'Ayesha',
      );
      client.failWith = Exception('offline');
      await controller.sendQuery(
        userId: 'u1',
        text: 'I am Ayesha, mail me at someone@example.com',
      );
      expect(controller.transcript.last.text, HealthBotController.noAnswerText);

      client.failWith = null;
      await controller.sendQuery(userId: 'u1', text: 'and now?');

      final history = client.askedHistories.last;
      expect(history, hasLength(1));
      expect(history.single.fromUser, isTrue);
      expect(history.single.text, isNot(contains('someone@example.com')));
      expect(history.single.text, isNot(contains('Ayesha')));
    });

    test('long replies are trimmed before being sent back', () async {
      final client = FakeHealthBotClient(
        nextAnswer: HealthBotAnswer(
          type: HealthBotAnswerType.matched,
          responseText: 'x' * 3000,
          source: HealthBotAnswerSource.ai,
        ),
      );
      final controller = HealthBotController(
        client,
        FakeHealthBotRepository(),
      );
      await controller.sendQuery(userId: 'u1', text: 'make me a plan');
      await controller.sendQuery(userId: 'u1', text: 'shorter please');
      expect(
        client.askedHistories.last.last.text.length,
        HealthBotController.maxHistoryMessageChars,
      );
    });
  });

  group('HealthBotController user context', () {
    test('loads the context once and reuses it', () async {
      var loads = 0;
      final client = FakeHealthBotClient(nextAnswer: _matched);
      final controller = HealthBotController(
        client,
        FakeHealthBotRepository(),
        loadUserContext: (userId) async {
          loads++;
          return const HealthBotUserContext(product: 'hookah', daysSinceQuit: 4);
        },
      );
      await controller.sendQuery(userId: 'u1', text: 'one');
      await controller.sendQuery(userId: 'u1', text: 'two');

      expect(loads, 1);
      expect(client.askedContexts.last?.product, 'hookah');
      expect(client.askedContexts.last?.daysSinceQuit, 4);
    });

    test('a failing loader never blocks the answer', () async {
      final client = FakeHealthBotClient(nextAnswer: _matched);
      final controller = HealthBotController(
        client,
        FakeHealthBotRepository(),
        loadUserContext: (userId) async => throw Exception('firestore down'),
      );
      await controller.sendQuery(userId: 'u1', text: 'hello');

      expect(client.askedContexts.single, isNull);
      expect(controller.transcript.last.text, _matchedText);
    });

    test('clearSession forgets the cached context', () async {
      var loads = 0;
      final controller = HealthBotController(
        FakeHealthBotClient(nextAnswer: _matched),
        FakeHealthBotRepository(),
        loadUserContext: (userId) async {
          loads++;
          return null;
        },
      );
      await controller.sendQuery(userId: 'u1', text: 'one');
      controller.clearSession();
      await controller.sendQuery(userId: 'u2', text: 'two');
      expect(loads, 2);
    });
  });

  group('healthBotContextFor', () {
    NicotineUser user({
      DateTime? quitDate,
      DateTime? lastRelapseDate,
      ProductType? product,
      QuitStrategy? strategy,
    }) => NicotineUser(
      userId: 'u1',
      email: 'private@example.com',
      name: 'Private Name',
      productType: product,
      quitStrategy: strategy,
      quitDate: quitDate,
      lastRelapseDate: lastRelapseDate,
    );

    test('counts days from the quit date', () {
      final context = healthBotContextFor(
        user(
          quitDate: DateTime(2026, 11, 20, 22),
          product: ProductType.vape,
          strategy: QuitStrategy.gradual,
        ),
        DateTime(2026, 11, 26, 8),
      )!;
      expect(context.daysSinceQuit, 6);
      expect(context.product, 'vape');
      expect(context.quitStrategy, 'gradual');
    });

    test('a later restart resets the count, like the dashboard', () {
      final context = healthBotContextFor(
        user(
          quitDate: DateTime(2026, 11, 1),
          lastRelapseDate: DateTime(2026, 11, 24),
        ),
        DateTime(2026, 11, 26),
      )!;
      expect(context.daysSinceQuit, 2);
    });

    test('a future quit date gives negative days', () {
      final context = healthBotContextFor(
        user(quitDate: DateTime(2026, 12, 1)),
        DateTime(2026, 11, 26),
      )!;
      expect(context.daysSinceQuit, -5);
    });

    test('never includes the name or email', () {
      final context = healthBotContextFor(
        user(quitDate: DateTime(2026, 11, 1), product: ProductType.cigarettes),
        DateTime(2026, 11, 26),
      )!;
      final json = jsonEncode(context.toJson());
      expect(json, isNot(contains('Private Name')));
      expect(json, isNot(contains('private@example.com')));
    });

    test('no profile details gives no context', () {
      expect(healthBotContextFor(user(), DateTime(2026, 11, 26)), isNull);
    });
  });
}

const _matchedText = 'Nicotine reaches the brain within seconds.';

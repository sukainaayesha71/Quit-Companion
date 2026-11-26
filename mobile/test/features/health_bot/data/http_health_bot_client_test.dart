import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/http_health_bot_client.dart';

void main() {
  group('HttpHealthBotClient', () {
    test(
      'ask posts the query, attaches the ID token, and parses a matched answer',
      () async {
        http.Request? captured;
        final mockClient = MockClient((request) async {
          captured = request;
          return http.Response(
            '{"answer_type":"matched","response_text":"Headaches are common."}',
            200,
          );
        });
        final client = HttpHealthBotClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'fake-id-token',
        );

        final answer = await client.ask(query: 'I have a headache');

        expect(answer.type, HealthBotAnswerType.matched);
        expect(answer.responseText, 'Headaches are common.');
        expect(captured!.url.toString(), 'http://backend.test/healthbot/query');
        expect(captured!.headers['Authorization'], 'Bearer fake-id-token');
        expect(jsonDecode(captured!.body), {'query': 'I have a headache'});
      },
    );

    test(
      'ask rejects a missing ID token without calling the backend',
      () async {
        var requestSent = false;
        final mockClient = MockClient((request) async {
          requestSent = true;
          return http.Response(
            '{"answer_type":"unmatched","response_text":"fallback"}',
            200,
          );
        });
        final client = HttpHealthBotClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => null,
        );

        await expectLater(
          client.ask(query: 'hello'),
          throwsA(
            isA<HealthBotClientException>().having(
              (error) => error.message,
              'message',
              'Please sign in to use the Health-Bot.',
            ),
          ),
        );

        expect(requestSent, isFalse);
      },
    );

    test('ask parses emergency and unmatched answer types', () async {
      final emergencyClient = HttpHealthBotClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"answer_type":"emergency","response_text":"seek care"}',
            200,
          ),
        ),
        getIdToken: () async => 'token',
      );
      final unmatchedClient = HttpHealthBotClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"answer_type":"unmatched","response_text":"fallback"}',
            200,
          ),
        ),
        getIdToken: () async => 'token',
      );

      expect(
        (await emergencyClient.ask(query: 'chest pain')).type,
        HealthBotAnswerType.emergency,
      );
      expect(
        (await unmatchedClient.ask(query: 'weather')).type,
        HealthBotAnswerType.unmatched,
      );
    });

    test(
      'a non-200 response throws HealthBotClientException with the backend detail',
      () async {
        final mockClient = MockClient(
          (_) async => http.Response('{"detail":"Service busy."}', 503),
        );
        final client = HttpHealthBotClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'token',
        );

        expect(
          () => client.ask(query: 'hello'),
          throwsA(
            isA<HealthBotClientException>()
                .having((e) => e.message, 'message', 'Service busy.')
                .having((e) => e is HealthBotAuthException, 'is auth', false),
          ),
        );
      },
    );

    test('a 401 becomes an actionable sign-in error', () async {
      final mockClient = MockClient(
        (_) async => http.Response('{"detail":"Invalid token."}', 401),
      );
      final client = HttpHealthBotClient(
        baseUrl: 'http://backend.test',
        httpClient: mockClient,
        getIdToken: () async => 'expired',
      );

      expect(
        () => client.ask(query: 'hello'),
        throwsA(
          isA<HealthBotAuthException>().having(
            (e) => e.message,
            'message',
            'Your sign-in has expired. Please sign in again.',
          ),
        ),
      );
    });

    test(
      'a network failure surfaces as HealthBotClientException, not a raw exception',
      () async {
        final mockClient = MockClient(
          (_) async => throw Exception('socket closed'),
        );
        final client = HttpHealthBotClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'token',
        );

        expect(
          () => client.ask(query: 'hello'),
          throwsA(isA<HealthBotClientException>()),
        );
      },
    );
  });
}

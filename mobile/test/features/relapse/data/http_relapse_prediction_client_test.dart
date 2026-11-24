import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quit_companion/features/relapse/data/http_relapse_prediction_client.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  group('HttpRelapsePredictionClient', () {
    test(
      'predict posts the request body, attaches the ID token, and parses the risk level on success',
      () async {
        http.Request? captured;
        final mockClient = MockClient((request) async {
          captured = request;
          return http.Response('{"risk_level":"high"}', 200);
        });
        final client = HttpRelapsePredictionClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'fake-id-token',
        );

        final risk = await client.predict(
          intensity: 9,
          mood: Mood.stressed,
          triggerCategory: TriggerCategory.socialPressure,
          last24hCount: 1,
        );

        expect(risk, RelapseRiskLevel.high);
        expect(captured!.url.toString(), 'http://backend.test/predict/relapse');
        expect(captured!.headers['Authorization'], 'Bearer fake-id-token');
        expect(jsonDecode(captured!.body), {
          'intensity': 9,
          'mood': 'stressed',
          'trigger_category': 'socialPressure',
          'last_24h_count': 1,
        });
      },
    );

    test(
      'predict omits the Authorization header when no ID token is available',
      () async {
        http.Request? captured;
        final mockClient = MockClient((request) async {
          captured = request;
          return http.Response('{"risk_level":"low"}', 200);
        });
        final client = HttpRelapsePredictionClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => null,
        );

        await client.predict(
          intensity: 1,
          mood: Mood.happy,
          triggerCategory: TriggerCategory.other,
          last24hCount: 1,
        );

        expect(captured!.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('predict parses medium and low risk levels', () async {
      final mediumClient = HttpRelapsePredictionClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient(
          (_) async => http.Response('{"risk_level":"medium"}', 200),
        ),
        getIdToken: () async => 'fake-id-token',
      );
      final lowClient = HttpRelapsePredictionClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient(
          (_) async => http.Response('{"risk_level":"low"}', 200),
        ),
        getIdToken: () async => 'fake-id-token',
      );

      expect(
        await mediumClient.predict(
          intensity: 5,
          mood: Mood.bored,
          triggerCategory: TriggerCategory.other,
          last24hCount: 1,
        ),
        RelapseRiskLevel.medium,
      );
      expect(
        await lowClient.predict(
          intensity: 1,
          mood: Mood.happy,
          triggerCategory: TriggerCategory.other,
          last24hCount: 1,
        ),
        RelapseRiskLevel.low,
      );
    });

    test('a non-200 response throws RelapsePredictionException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"detail":"validation failed"}', 422);
      });
      final client = HttpRelapsePredictionClient(
        baseUrl: 'http://backend.test',
        httpClient: mockClient,
        getIdToken: () async => 'fake-id-token',
      );

      expect(
        () => client.predict(
          intensity: 5,
          mood: Mood.happy,
          triggerCategory: TriggerCategory.other,
          last24hCount: 1,
        ),
        throwsA(isA<RelapsePredictionException>()),
      );
    });

    test(
      'a 401 (missing/invalid auth) response throws RelapsePredictionException with the backend detail',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"detail":"Invalid or expired Firebase ID token."}',
            401,
          );
        });
        final client = HttpRelapsePredictionClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'expired-token',
        );

        expect(
          () => client.predict(
            intensity: 5,
            mood: Mood.happy,
            triggerCategory: TriggerCategory.other,
            last24hCount: 1,
          ),
          throwsA(
            isA<RelapsePredictionException>().having(
              (e) => e.message,
              'message',
              'Invalid or expired Firebase ID token.',
            ),
          ),
        );
      },
    );

    test(
      'predict includes mood-slider fields in the request body when provided',
      () async {
        http.Request? captured;
        final mockClient = MockClient((request) async {
          captured = request;
          return http.Response('{"risk_level":"low"}', 200);
        });
        final client = HttpRelapsePredictionClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'fake-id-token',
        );

        await client.predict(
          intensity: 4,
          mood: Mood.happy,
          triggerCategory: TriggerCategory.other,
          last24hCount: 1,
          moodHappy: 8,
          moodExcited: 7,
          moodEnthusiastic: 6,
          moodContented: 5,
          moodCalm: 4,
          moodIrritable: 3,
          moodAnxious: 2,
          moodStressed: 1,
          moodSad: 0,
          moodBored: 9,
        );

        expect(jsonDecode(captured!.body), {
          'intensity': 4,
          'mood': 'happy',
          'trigger_category': 'other',
          'last_24h_count': 1,
          'mood_happy': 8,
          'mood_excited': 7,
          'mood_enthusiastic': 6,
          'mood_contented': 5,
          'mood_calm': 4,
          'mood_irritable': 3,
          'mood_anxious': 2,
          'mood_stressed': 1,
          'mood_sad': 0,
          'mood_bored': 9,
        });
      },
    );

    test(
      'predict omits mood-slider fields from the request body when not provided',
      () async {
        http.Request? captured;
        final mockClient = MockClient((request) async {
          captured = request;
          return http.Response('{"risk_level":"low"}', 200);
        });
        final client = HttpRelapsePredictionClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'fake-id-token',
        );

        await client.predict(
          intensity: 4,
          mood: Mood.happy,
          triggerCategory: TriggerCategory.other,
          last24hCount: 1,
        );

        final body = jsonDecode(captured!.body) as Map<String, dynamic>;
        expect(body.containsKey('mood_happy'), isFalse);
        expect(body.containsKey('mood_bored'), isFalse);
      },
    );

    test(
      'a network failure surfaces as RelapsePredictionException, not a raw exception',
      () async {
        final mockClient = MockClient((request) async {
          throw Exception('socket closed');
        });
        final client = HttpRelapsePredictionClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
          getIdToken: () async => 'fake-id-token',
        );

        expect(
          () => client.predict(
            intensity: 5,
            mood: Mood.happy,
            triggerCategory: TriggerCategory.other,
            last24hCount: 1,
          ),
          throwsA(isA<RelapsePredictionException>()),
        );
      },
    );
  });
}

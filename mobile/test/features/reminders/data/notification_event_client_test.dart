import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quit_companion/features/reminders/data/notification_event_client.dart';

void main() {
  test('sends an authenticated fixed event to the backend', () async {
    http.Request? capturedRequest;
    final client = HttpNotificationEventClient(
      baseUrl: 'https://api.example.test',
      getIdToken: () async => 'firebase-id-token',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      }),
    );

    await client.send(NotificationEventType.badgeEarned);

    expect(capturedRequest!.url.path, '/notifications/events/badge_earned');
    expect(
      capturedRequest!.headers['Authorization'],
      'Bearer firebase-id-token',
    );
  });

  test('does not send an event without a signed-in Firebase user', () async {
    var requestSent = false;
    final client = HttpNotificationEventClient(
      baseUrl: 'https://api.example.test',
      getIdToken: () async => null,
      httpClient: MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.send(NotificationEventType.restartPlan),
      throwsA(isA<NotificationEventException>()),
    );
    expect(requestSent, isFalse);
  });
}

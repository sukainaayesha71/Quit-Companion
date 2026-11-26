import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_message.dart';
import 'package:quit_companion/features/health_bot/domain/local_health_bot_fallback.dart';

void main() {
  group('HealthBotController', () {
    test(
      'the disclaimer must be acknowledged before it is treated as usable',
      () {
        final controller = HealthBotController(
          FakeHealthBotClient(),
          FakeHealthBotRepository(),
        );

        expect(controller.disclaimerAcknowledged, isFalse);
        controller.acknowledgeDisclaimer();
        expect(controller.disclaimerAcknowledged, isTrue);
      },
    );

    test(
      'sendQuery appends the user message immediately, then the matched bot response',
      () async {
        final client = FakeHealthBotClient(
          nextAnswer: const HealthBotAnswer(
            type: HealthBotAnswerType.matched,
            responseText: 'Headaches are common.',
          ),
        );
        final repository = FakeHealthBotRepository();
        final controller = HealthBotController(
          client,
          repository,
          now: () => DateTime(2026, 8, 19),
        );

        await controller.sendQuery(userId: 'u1', text: 'I have a headache');

        expect(controller.transcript, hasLength(2));
        expect(controller.transcript[0].sender, HealthBotSender.user);
        expect(controller.transcript[0].text, 'I have a headache');
        expect(controller.transcript[1].sender, HealthBotSender.bot);
        expect(controller.transcript[1].text, 'Headaches are common.');
        expect(controller.transcript[1].isEmergency, isFalse);
        expect(client.askedQueries, ['I have a headache']);
      },
    );

    test('an emergency answer appends a message flagged isEmergency', () async {
      final client = FakeHealthBotClient(
        nextAnswer: const HealthBotAnswer(
          type: HealthBotAnswerType.emergency,
          responseText:
              'This sounds like it could be a medical emergency. Please seek emergency medical care immediately.',
        ),
      );
      final controller = HealthBotController(client, FakeHealthBotRepository());

      await controller.sendQuery(userId: 'u1', text: 'chest pain');

      expect(controller.transcript.last.isEmergency, isTrue);
    });

    test('an unmatched answer appends the exact SRDS fallback text', () async {
      final client = FakeHealthBotClient(
        nextAnswer: const HealthBotAnswer(
          type: HealthBotAnswerType.unmatched,
          responseText:
              'I cannot answer this confidently. Please consult a doctor.',
        ),
      );
      final controller = HealthBotController(client, FakeHealthBotRepository());

      await controller.sendQuery(userId: 'u1', text: 'random nonsense');

      expect(
        controller.transcript.last.text,
        'I cannot answer this confidently. Please consult a doctor.',
      );
      expect(controller.transcript.last.isEmergency, isFalse);
    });

    test('every exchange is logged to the repository', () async {
      final repository = FakeHealthBotRepository();
      final controller = HealthBotController(
        FakeHealthBotClient(),
        repository,
        now: () => DateTime(2026, 8, 19),
      );

      await controller.sendQuery(userId: 'u1', text: 'hello');

      expect(repository.logged, hasLength(1));
      expect(repository.logged.first.userId, 'u1');
      expect(repository.logged.first.query, 'hello');
    });

    test(
      'a repository logging failure never blocks or errors the visible chat',
      () async {
        final repository = FakeHealthBotRepository()
          ..failWith = Exception('firestore down');
        final client = FakeHealthBotClient(
          nextAnswer: const HealthBotAnswer(
            type: HealthBotAnswerType.matched,
            responseText: 'ok',
          ),
        );
        final controller = HealthBotController(client, repository);

        await controller.sendQuery(userId: 'u1', text: 'hello');

        expect(controller.transcript, hasLength(2));
        expect(controller.status, HealthBotStatus.idle);
      },
    );

    test(
      'a client failure appends an inline error message instead of throwing',
      () async {
        final client = FakeHealthBotClient()
          ..failWith = Exception('network down');
        final controller = HealthBotController(
          client,
          FakeHealthBotRepository(),
        );

        await controller.sendQuery(userId: 'u1', text: 'hello');

        expect(controller.transcript, hasLength(2));
        expect(controller.errorMessage, isNotNull);
      },
    );

    test(
      'a client error is shown instead of a generic connection message',
      () async {
        final client = FakeHealthBotClient()
          ..failWith = HealthBotClientException(
            'Invalid or expired Firebase ID token.',
          );
        final controller = HealthBotController(
          client,
          FakeHealthBotRepository(),
        );

        await controller.sendQuery(userId: 'u1', text: 'hello');

        // The reply is an honest "no answer" with Try again; server error
        // text is kept for diagnostics but never shown under the reply.
        expect(
          controller.transcript.last.text,
          LocalHealthBotFallback.unavailableText,
        );
        expect(controller.transcript.last.note, isNull);
        expect(controller.transcript.last.retryQuery, 'hello');
        expect(
          controller.errorMessage,
          'Invalid or expired Firebase ID token.',
        );
      },
    );
  });
}

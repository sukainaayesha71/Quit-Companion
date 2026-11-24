import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';

void main() {
  test('logConversation records the conversation', () async {
    final repo = FakeHealthBotRepository();
    final conversation = HealthBotConversation(
      conversationId: 'c1',
      userId: 'user1',
      query: 'I have a headache',
      botResponse: 'Headaches are common.',
      timestamp: DateTime(2026, 8, 19),
    );

    await repo.logConversation(conversation);

    expect(repo.logged, hasLength(1));
    expect(repo.logged.first.query, 'I have a headache');
  });

  test(
    'logConversation throws when failWith is set, simulating a Firestore failure',
    () async {
      final repo = FakeHealthBotRepository()
        ..failWith = Exception('firestore down');

      expect(
        () => repo.logConversation(
          HealthBotConversation(
            conversationId: 'c1',
            userId: 'user1',
            query: 'hi',
            botResponse: 'hello',
            timestamp: DateTime(2026, 8, 19),
          ),
        ),
        throwsException,
      );
    },
  );
}

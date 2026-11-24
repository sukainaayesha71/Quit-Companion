import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_repository.dart';

class FakeHealthBotRepository implements HealthBotRepository {
  final List<HealthBotConversation> logged = [];
  Object? failWith;

  @override
  Future<List<HealthBotConversation>> getConversations(String userId) async {
    if (failWith != null) throw failWith!;
    return logged.where((item) => item.userId == userId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> logConversation(HealthBotConversation conversation) async {
    if (failWith != null) throw failWith!;
    logged.add(conversation);
  }
}

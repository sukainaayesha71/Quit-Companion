import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';

/// HealthBotConversation persistence (SDD §6, Module 6 — Health-Bot, FR8).
/// Private, per-user conversation history.
abstract class HealthBotRepository {
  Future<void> logConversation(HealthBotConversation conversation);
  Future<List<HealthBotConversation>> getConversations(String userId);
}

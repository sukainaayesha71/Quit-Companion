/// SDD §6: HealthBotConversation(sessionId, userId, query, botResponse,
/// timestamp) — the only entity this module defines. Written once per Q&A
/// exchange and reloaded as private conversation history.
library;

import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

class HealthBotConversation {
  final String conversationId;
  final String userId;
  final String query;
  final String botResponse;
  final DateTime timestamp;
  final bool isEmergency;

  /// FR8: sources shown with the reply, so restored history keeps them.
  final List<HealthBotSource> sources;

  /// The reply's source note (see HealthBotMessage.note), so restored
  /// history stays honestly labelled. Absent on older records.
  final String? note;

  /// The reply's origin (HealthBotAnswerSource), so history never treats a
  /// curated or offline reply as AI-generated. Absent on older records.
  final HealthBotAnswerSource? answerSource;

  /// SDD §6 `sessionId`: the chat (Chat History entry) this exchange belongs
  /// to. Absent on exchanges saved before chats existed; those are grouped
  /// by time when read (see health_bot_chats.dart) and never rewritten.
  final String? sessionId;

  const HealthBotConversation({
    required this.conversationId,
    required this.userId,
    required this.query,
    required this.botResponse,
    required this.timestamp,
    this.isEmergency = false,
    this.sources = const [],
    this.note,
    this.answerSource,
    this.sessionId,
  });
}

/// SDD FR8 / Module 6 plan — a single chat-transcript entry. Not an SDD
/// entity itself (the SDD only defines the persisted [HealthBotConversation]
/// audit-log record); this is the Flutter-only UI shape for rendering the
/// conversation.
library;

import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

enum HealthBotSender { user, bot }

class HealthBotMessage {
  final HealthBotSender sender;
  final String text;

  /// True only for the Open-Decision-2 urgent-care bubble — styled
  /// distinctly and never a normal bot response, even if the query also
  /// happened to match a knowledge-base keyword (emergency always wins).
  final bool isEmergency;
  final DateTime timestamp;

  /// FR8 topic-specific trusted sources shown under a bot reply. Always
  /// empty for emergencies and refusals.
  final List<HealthBotSource> sources;

  /// A short, friendly line under a bot reply that isn't AI-generated
  /// (curated library text or offline guidance), or that explains why the
  /// backend couldn't answer (e.g. "Please sign in…"). Never a raw
  /// technical error.
  final String? note;

  /// When set, the reply offers "Try again", which resends this question.
  /// Only for live replies where no answer was available.
  final String? retryQuery;

  /// Where a bot reply came from (AI, curated library, safety rule,
  /// offline). Kept internally and in saved history, not displayed; null
  /// for user messages and older history records.
  final HealthBotAnswerSource? answerSource;

  const HealthBotMessage({
    required this.sender,
    required this.text,
    this.isEmergency = false,
    required this.timestamp,
    this.sources = const [],
    this.note,
    this.retryQuery,
    this.answerSource,
  });
}

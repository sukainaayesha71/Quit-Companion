import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';

/// One Health-Bot conversation (a "chat") for Chat History: the saved
/// question-and-answer exchanges that share a [HealthBotConversation.sessionId].
class HealthBotChat {
  /// The exchanges' sessionId. For exchanges saved before chats existed it
  /// is a stable id derived from the first exchange (see [legacyChatIdFor]).
  final String id;

  /// Oldest first.
  final List<HealthBotConversation> exchanges;

  const HealthBotChat({required this.id, required this.exchanges});

  /// The user's first question, shortened (see [chatTitleFor]).
  String get title => chatTitleFor(exchanges.first.query);

  DateTime get startedAt => exchanges.first.timestamp;
  DateTime get lastMessageAt => exchanges.last.timestamp;

  /// Number of questions asked in this chat.
  int get questionCount => exchanges.length;
}

/// Exchanges saved before chats existed have no sessionId. They are grouped
/// into chats by time instead, without changing the saved documents: a new
/// chat starts after a pause longer than this.
const legacyChatGap = Duration(hours: 1);

const _maxTitleLength = 60;

/// A short, meaningful title: the first question, on one line, shortened at
/// a word boundary.
String chatTitleFor(String firstQuestion) {
  final text = firstQuestion.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return 'Conversation';
  if (text.length <= _maxTitleLength) return text;
  final cut = text.substring(0, _maxTitleLength);
  final space = cut.lastIndexOf(' ');
  return '${(space > 30 ? cut.substring(0, space) : cut).trimRight()}…';
}

/// Stable id for a chat of older exchanges, so continuing it later adds new
/// messages to the same chat.
String legacyChatIdFor(HealthBotConversation firstExchange) =>
    'legacy_${firstExchange.conversationId}';

/// Groups saved exchanges into chats, most recently active first.
///
/// Exchanges with a sessionId belong to that chat. Older exchanges without
/// one are grouped by time ([legacyChatGap]); [legacyBoundary] (the start of
/// a New Chat made before chats were saved) also splits them.
List<HealthBotChat> groupIntoChats(
  Iterable<HealthBotConversation> exchanges, {
  DateTime? legacyBoundary,
}) {
  final sorted = exchanges.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final byId = <String, List<HealthBotConversation>>{};
  HealthBotConversation? previousLegacy;
  String? currentLegacyId;
  for (final exchange in sorted) {
    final sessionId = exchange.sessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      byId.putIfAbsent(sessionId, () => []).add(exchange);
      continue;
    }
    final previous = previousLegacy;
    final startsNewChat =
        previous == null ||
        exchange.timestamp.difference(previous.timestamp) > legacyChatGap ||
        (legacyBoundary != null &&
            previous.timestamp.isBefore(legacyBoundary) &&
            !exchange.timestamp.isBefore(legacyBoundary));
    if (startsNewChat) currentLegacyId = legacyChatIdFor(exchange);
    byId.putIfAbsent(currentLegacyId!, () => []).add(exchange);
    previousLegacy = exchange;
  }
  final chats = [
    for (final entry in byId.entries)
      HealthBotChat(id: entry.key, exchanges: entry.value),
  ]..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  return chats;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "26 Nov 2026, 9:05 PM" (no intl dependency in this app).
String formatChatDateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '${value.day} ${_months[value.month - 1]} ${value.year}, '
      '$hour:$minute $period';
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

/// Real Firestore implementation (SDD §6, Module 6), mirrors
/// FirestoreJournalRepository's per-user-subcollection pattern:
/// nicotineUsers/{userId}/healthBotConversations/{conversationId}. Requires
/// the matching Firestore rules subcollection block (see Module 6 plan
/// Task 8).
class FirestoreHealthBotRepository implements HealthBotRepository {
  final FirebaseFirestore _firestore;

  FirestoreHealthBotRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _conversationsFor(String userId) =>
      _firestore
          .collection('nicotineUsers')
          .doc(userId)
          .collection('healthBotConversations');

  /// How many of the most recent exchanges are read for the chat and Chat
  /// History (one document per question and answer).
  static const historyLimit = 200;

  @override
  Future<List<HealthBotConversation>> getConversations(String userId) async {
    final snapshot = await _conversationsFor(
      userId,
    ).orderBy('timestamp', descending: true).limit(historyLimit).get();
    return snapshot.docs.reversed.map((doc) {
      final data = doc.data();
      return HealthBotConversation(
        conversationId: doc.id,
        userId: userId,
        query: data['query'] as String,
        botResponse: data['botResponse'] as String,
        timestamp: DateTime.parse(data['timestamp'] as String),
        isEmergency: data['isEmergency'] as bool? ?? false,
        // Absent on records saved before FR8 sources existed.
        sources: [
          if (data['sources'] case final List<dynamic> list)
            for (final item in list) ?HealthBotSource.fromMap(item),
        ],
        // Absent on records saved before source notes existed.
        note: data['note'] as String?,
        answerSource: _parseStoredSource(data['answerSource']),
        // Absent on exchanges saved before Chat History.
        sessionId: data['sessionId'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> logConversation(HealthBotConversation conversation) async {
    await _conversationsFor(
      conversation.userId,
    ).doc(conversation.conversationId).set({
      'query': conversation.query,
      'botResponse': conversation.botResponse,
      'timestamp': conversation.timestamp.toIso8601String(),
      'isEmergency': conversation.isEmergency,
      if (conversation.sessionId case final String sessionId)
        'sessionId': sessionId,
      if (conversation.note case final String note) 'note': note,
      if (conversation.answerSource case final HealthBotAnswerSource source)
        'answerSource': source.name,
      if (conversation.sources.isNotEmpty)
        'sources': [for (final s in conversation.sources) s.toMap()],
    });
  }

  /// Stored as the enum name ("ai", "curated", "safety", "offline",
  /// "unknown"); absent on older records.
  static HealthBotAnswerSource? _parseStoredSource(Object? raw) {
    for (final source in HealthBotAnswerSource.values) {
      if (source.name == raw) return source;
    }
    return null;
  }
}

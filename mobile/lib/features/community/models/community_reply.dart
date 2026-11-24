/// Not an SDD-named entity — SRDS UC8 step 9 ("Other users can... reply to
/// the post") requires replies but neither the SDD nor SRDS defines a
/// reply entity's shape. Mirrors CommunityPost's own fields (same
/// anonymized-username, timestamp convention) — same "extend by analogy
/// to the nearest defined entity" precedent as HabitAlternativeAttempt
/// (Module 7) and HealthBotConversation (Module 6).
class CommunityReply {
  final String replyId;
  final String postId;
  final String userId;
  final String anonymizedUsername;
  final String content;
  final DateTime timestamp;

  const CommunityReply({
    required this.replyId,
    required this.postId,
    required this.userId,
    required this.anonymizedUsername,
    required this.content,
    required this.timestamp,
  });
}

import 'package:quit_companion/features/community/models/post_category.dart';

/// SDD §6 / SRDS class diagram: CommunityPost(postId, userId, content,
/// category, timestamp). Extended with [anonymizedUsername] (computed
/// once at post-creation time — SRDS UC8 step 7: "saves the post to
/// Firebase with timestamp and anonymized username" — not a live-editable
/// profile field) and [likeCount] (needed to render the approved UI's
/// like counts; not in the SDD's literal 4-field list — same category of
/// additive gap Module 3/5/7 already hit and documented, not a silent
/// invention). See CommunityPostRepository for how likeCount is derived
/// (a `likes` subcollection, never a client-trusted stored counter).
class CommunityPost {
  final String postId;
  final String userId;
  final String anonymizedUsername;
  final String content;
  final PostCategory category;
  final DateTime timestamp;
  final int likeCount;

  const CommunityPost({
    required this.postId,
    required this.userId,
    required this.anonymizedUsername,
    required this.content,
    required this.category,
    required this.timestamp,
    this.likeCount = 0,
  });
}

import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/community_reply.dart';
import 'package:quit_companion/features/community/models/post_category.dart';

/// CommunityPost/CommunityReply persistence (SDD §6, Module 9 — Community
/// & Peer Support, FR11). The first collection in this app that is NOT a
/// per-user `nicotineUsers/{userId}/...` subcollection — SRDS UC8 is
/// explicit that a post is "visible to all registered users," so this is
/// backed by a top-level `communityPosts` collection instead, readable by
/// any authenticated user (see firestore.rules for the exact access
/// model). Every other collection in this app stays private-per-user;
/// this is the one deliberate exception, not a pattern to reuse
/// elsewhere without the same justification.
abstract class CommunityPostRepository {
  Future<void> createPost(CommunityPost post);
  Future<void> deletePost({required String postId, required String userId});

  /// Newest first, optionally narrowed to [category] (null = All, matching
  /// the approved UI's "All" filter chip).
  Future<List<CommunityPost>> getPosts({PostCategory? category});
  Stream<List<CommunityPost>> watchPosts({PostCategory? category});
  Stream<List<CommunityReply>> watchReplies(String postId);

  Future<bool> hasLiked({required String postId, required String userId});

  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  });

  Future<List<CommunityReply>> getReplies(String postId);

  Future<void> addReply(CommunityReply reply);
}

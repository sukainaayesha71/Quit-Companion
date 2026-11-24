import 'dart:async';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/community_reply.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/community/data/community_post_repository.dart';

class FakeCommunityPostRepository implements CommunityPostRepository {
  final List<CommunityPost> posts = [];
  final Map<String, Set<String>> _likesByPost = {}; // postId -> set of userIds
  final List<CommunityReply> replies = [];
  Object? failWith;
  final _changes = StreamController<void>.broadcast();

  @override
  Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    if (failWith != null) throw failWith!;
    final matches = posts.where((post) => post.postId == postId);
    if (matches.isEmpty) return;
    if (matches.first.userId != userId) {
      throw StateError('You can only delete your own posts.');
    }
    posts.removeWhere((post) => post.postId == postId);
    _likesByPost.remove(postId);
    replies.removeWhere((reply) => reply.postId == postId);
    _changes.add(null);
  }

  @override
  Stream<List<CommunityPost>> watchPosts({PostCategory? category}) =>
      Stream.multi((controller) {
        void emit() {
          unawaited(
            getPosts(
              category: category,
            ).then(controller.add, onError: controller.addError),
          );
        }

        final subscription = _changes.stream.listen((_) => emit());
        controller.onCancel = subscription.cancel;
        emit();
      });

  @override
  Stream<List<CommunityReply>> watchReplies(String postId) => Stream.multi((
    controller,
  ) {
    void emit() {
      unawaited(
        getReplies(postId).then(controller.add, onError: controller.addError),
      );
    }

    final subscription = _changes.stream.listen((_) => emit());
    controller.onCancel = subscription.cancel;
    emit();
  });

  @override
  Future<void> createPost(CommunityPost post) async {
    if (failWith != null) throw failWith!;
    posts.add(post);
    _changes.add(null);
  }

  @override
  Future<List<CommunityPost>> getPosts({PostCategory? category}) async {
    final filtered = category == null
        ? posts
        : posts.where((p) => p.category == category).toList();
    final sorted = List<CommunityPost>.from(filtered)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.map((p) => _withLikeCount(p)).toList();
  }

  CommunityPost _withLikeCount(CommunityPost post) {
    final count = _likesByPost[post.postId]?.length ?? 0;
    return CommunityPost(
      postId: post.postId,
      userId: post.userId,
      anonymizedUsername: post.anonymizedUsername,
      content: post.content,
      category: post.category,
      timestamp: post.timestamp,
      likeCount: count,
    );
  }

  @override
  Future<bool> hasLiked({
    required String postId,
    required String userId,
  }) async {
    return _likesByPost[postId]?.contains(userId) ?? false;
  }

  @override
  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  }) async {
    if (failWith != null) throw failWith!;
    final likes = _likesByPost.putIfAbsent(postId, () => {});
    if (liked) {
      likes.add(userId);
    } else {
      likes.remove(userId);
    }
    _changes.add(null);
  }

  @override
  Future<List<CommunityReply>> getReplies(String postId) async {
    final matching = replies.where((r) => r.postId == postId).toList();
    matching.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return matching;
  }

  @override
  Future<void> addReply(CommunityReply reply) async {
    if (failWith != null) throw failWith!;
    replies.add(reply);
    _changes.add(null);
  }
}

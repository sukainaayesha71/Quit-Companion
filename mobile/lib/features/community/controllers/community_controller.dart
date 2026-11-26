import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/community/data/community_post_repository.dart';
import 'package:quit_companion/features/community/domain/anonymized_username_generator.dart';
import 'package:quit_companion/features/community/domain/content_filter.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/community_reply.dart';
import 'package:quit_companion/features/community/domain/community_post_validator.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/shared/domain/privacy_redactor.dart';

enum CommunityStatus { idle, loading, loaded, error }

/// FR11 (Module 9 — Community & Peer Support): loads/filters the public
/// feed, creates a post (content-filtered per SRDS UC8's alternative
/// flow), toggles a like, and loads/adds replies for a single post at a
/// time (see [repliesForCurrentPost] — this app has no dedicated
/// multi-post reply cache, matching the one-screen-at-a-time navigation
/// every other module uses).
class CommunityController extends ChangeNotifier {
  final CommunityPostRepository _repository;
  final DateTime Function() now;

  CommunityController(this._repository, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  CommunityStatus status = CommunityStatus.idle;
  String? errorMessage;
  List<CommunityPost> posts = [];
  Set<String> likedPostIds = {};
  PostCategory? filter;

  List<CommunityReply> repliesForCurrentPost = [];
  final Set<String> deletingPostIds = {};

  Future<bool> deletePost({
    required String postId,
    required String userId,
  }) async {
    if (!deletingPostIds.add(postId)) return false;
    errorMessage = null;
    notifyListeners();
    try {
      final matching = posts.where((post) => post.postId == postId);
      if (matching.isNotEmpty && matching.first.userId != userId) {
        throw StateError('You can only delete your own posts.');
      }
      await _repository.deletePost(postId: postId, userId: userId);
      posts = posts.where((post) => post.postId != postId).toList();
      likedPostIds.remove(postId);
      return true;
    } catch (error) {
      debugPrint('Could not delete community post: $error');
      errorMessage =
          'Could not delete your post. Check your connection and try again.';
      return false;
    } finally {
      deletingPostIds.remove(postId);
      notifyListeners();
    }
  }

  StreamSubscription<List<CommunityPost>>? _feedSubscription;
  StreamSubscription<List<CommunityReply>>? _replySubscription;
  int _feedVersion = 0;
  int _likeStateRequest = 0;

  static const feedErrorMessage =
      'Could not load community posts. Check your connection and try again.';

  /// Live feed. Posts are shown as soon as they arrive; whether the user
  /// liked each one is looked up separately ([_refreshLikedState]), so a
  /// slow or failed lookup can never leave the screen stuck on a spinner.
  /// An error before any posts arrived shows the error state (with Retry);
  /// after that, the posts already on screen stay visible.
  Future<void> startFeed({
    required String userId,
    PostCategory? category,
  }) async {
    unawaited(_feedSubscription?.cancel());
    final version = ++_feedVersion;
    filter = category;
    status = CommunityStatus.loading;
    errorMessage = null;
    notifyListeners();
    _feedSubscription = _repository
        .watchPosts(category: category)
        .listen(
          (items) {
            if (version != _feedVersion) return;
            posts = items;
            status = CommunityStatus.loaded;
            errorMessage = null;
            notifyListeners();
            unawaited(_refreshLikedState(version, userId, items));
          },
          onError: (Object error) {
            if (version != _feedVersion) return;
            debugPrint('CommunityController feed failed: $error');
            errorMessage = feedErrorMessage;
            if (status != CommunityStatus.loaded) {
              status = CommunityStatus.error;
            }
            notifyListeners();
          },
        );
  }

  Future<void> _refreshLikedState(
    int version,
    String userId,
    List<CommunityPost> items,
  ) async {
    final request = ++_likeStateRequest;
    final liked = <String>{};
    await Future.wait(
      items.map((post) async {
        try {
          if (await _repository.hasLiked(postId: post.postId, userId: userId)) {
            liked.add(post.postId);
          }
        } catch (e) {
          // Non-fatal: the post still shows, just without the liked marker.
          debugPrint('Could not check the like on ${post.postId}: $e');
        }
      }),
    );
    if (version != _feedVersion || request != _likeStateRequest) return;
    likedPostIds = liked;
    notifyListeners();
  }

  void stopFeed() {
    _feedVersion++;
    unawaited(_feedSubscription?.cancel());
    _feedSubscription = null;
  }

  Future<void> startReplies(String postId) async {
    await _replySubscription?.cancel();
    repliesForCurrentPost = [];
    _replySubscription = _repository
        .watchReplies(postId)
        .listen(
          (items) {
            repliesForCurrentPost = items;
            notifyListeners();
          },
          onError: (Object error) {
            errorMessage = 'Could not load live replies.';
            notifyListeners();
          },
        );
  }

  void stopReplies() {
    unawaited(_replySubscription?.cancel());
    _replySubscription = null;
  }

  @override
  void dispose() {
    stopFeed();
    stopReplies();
    super.dispose();
  }

  Future<void> loadFeed({
    required String userId,
    PostCategory? category,
  }) async {
    filter = category;
    status = CommunityStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      posts = await _repository.getPosts(category: category);
      final liked = <String>{};
      for (final post in posts) {
        if (await _repository.hasLiked(postId: post.postId, userId: userId)) {
          liked.add(post.postId);
        }
      }
      likedPostIds = liked;
      status = CommunityStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('CommunityController.loadFeed failed: $e');
      errorMessage =
          'Could not load the community feed. Check your connection and try again.';
      status = CommunityStatus.error;
      notifyListeners();
    }
  }

  Future<void> setFilter({
    required String userId,
    PostCategory? category,
  }) async {
    if (_feedSubscription != null) {
      await startFeed(userId: userId, category: category);
    } else {
      await loadFeed(userId: userId, category: category);
    }
  }

  Future<bool> createPost({
    required String userId,
    required String content,
    required PostCategory category,
  }) async {
    final prepared = _validate(userId, content, isReply: false);
    if (prepared == null) return false;
    if (!isContentAllowed(content)) {
      errorMessage =
          'This post could not be shared — please rephrase and try again.';
      notifyListeners();
      return false;
    }
    try {
      final timestamp = now();
      await _repository.createPost(
        CommunityPost(
          postId: timestamp.microsecondsSinceEpoch.toString(),
          userId: userId,
          anonymizedUsername: generateAnonymizedUsername(userId),
          content: prepared,
          category: category,
          timestamp: timestamp,
        ),
      );
      await loadFeed(userId: userId, category: filter);
      return true;
    } catch (e) {
      debugPrint('CommunityController.createPost failed: $e');
      errorMessage =
          'Could not share your post. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final currentlyLiked = likedPostIds.contains(postId);
    try {
      await _repository.setLiked(
        postId: postId,
        userId: userId,
        liked: !currentlyLiked,
      );
      if (currentlyLiked) {
        likedPostIds.remove(postId);
      } else {
        likedPostIds.add(postId);
      }
      posts = [
        for (final post in posts)
          if (post.postId == postId)
            CommunityPost(
              postId: post.postId,
              userId: post.userId,
              anonymizedUsername: post.anonymizedUsername,
              content: post.content,
              category: post.category,
              timestamp: post.timestamp,
              likeCount: post.likeCount + (currentlyLiked ? -1 : 1),
            )
          else
            post,
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('CommunityController.toggleLike failed (non-fatal): $e');
    }
  }

  Future<void> loadReplies(String postId) async {
    try {
      repliesForCurrentPost = await _repository.getReplies(postId);
      notifyListeners();
    } catch (e) {
      debugPrint('CommunityController.loadReplies failed: $e');
      errorMessage =
          'Could not load replies. Check your connection and try again.';
      notifyListeners();
    }
  }

  Future<bool> addReply({
    required String postId,
    required String userId,
    required String content,
  }) async {
    final prepared = _validate(userId, content, isReply: true);
    if (prepared == null) return false;
    if (postId.trim().isEmpty) {
      errorMessage = 'This post is no longer available.';
      notifyListeners();
      return false;
    }
    if (!isContentAllowed(content)) {
      errorMessage =
          'This reply could not be shared — please rephrase and try again.';
      notifyListeners();
      return false;
    }
    try {
      final timestamp = now();
      await _repository.addReply(
        CommunityReply(
          replyId: timestamp.microsecondsSinceEpoch.toString(),
          postId: postId,
          userId: userId,
          anonymizedUsername: generateAnonymizedUsername(userId),
          content: prepared,
          timestamp: timestamp,
        ),
      );
      await loadReplies(postId);
      return true;
    } catch (e) {
      debugPrint('CommunityController.addReply failed: $e');
      errorMessage =
          'Could not post your reply. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  /// FR10: returns the exact text that will be stored (trimmed, contact
  /// details redacted), or null with [errorMessage] set. The stored text is
  /// re-checked because redaction can change its length, and
  /// firestore.rules enforces the same limit on what is actually written.
  String? _validate(String userId, String content, {required bool isReply}) {
    String? fail(String message) {
      errorMessage = message;
      notifyListeners();
      return null;
    }

    if (userId.trim().isEmpty) {
      return fail('Please sign in again to share in the community.');
    }
    final error = validateCommunityText(content);
    if (error != null) {
      return fail(
        communityTextErrorMessage(
          error,
          isReply: isReply,
          length: normalizeCommunityText(content).length,
        ),
      );
    }
    final prepared = redactContactDetails(normalizeCommunityText(content));
    final preparedError = validateCommunityText(prepared);
    if (preparedError != null) {
      return fail(
        communityTextErrorMessage(
          preparedError,
          isReply: isReply,
          length: prepared.length,
        ),
      );
    }
    return prepared;
  }
}

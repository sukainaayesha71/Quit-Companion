import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/community_reply.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/community/data/community_post_repository.dart';
import 'package:quit_companion/shared/data/content_deletion_client.dart';

/// Real Firestore implementation — top-level `communityPosts/{postId}`
/// (not per-user, see CommunityPostRepository's doc comment), with
/// `likes/{userId}` and `replies/{replyId}` subcollections per post.
/// [likeCount] is always computed by reading the `likes` subcollection's
/// size, never trusted as a client-writable counter field on the post
/// document itself — avoids a write-contention/security hole where any
/// user could set an arbitrary count.
class FirestoreCommunityPostRepository implements CommunityPostRepository {
  final FirebaseFirestore _firestore;
  // Initialize on first use for repository instances retained by hot reload.
  ContentDeletionClient? _deletionClient;

  FirestoreCommunityPostRepository({
    FirebaseFirestore? firestore,
    ContentDeletionClient? deletionClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _deletionClient = deletionClient;

  @override
  Future<void> deletePost({required String postId, required String userId}) =>
      (_deletionClient ??= ContentDeletionClient()).delete(
        '/community/posts/${Uri.encodeComponent(postId)}',
      );

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('communityPosts');

  @override
  Stream<List<CommunityPost>> watchPosts({PostCategory? category}) {
    Query<Map<String, dynamic>> query = _posts
        .orderBy('timestamp', descending: true)
        .limit(50);
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    late StreamController<List<CommunityPost>> controller;
    StreamSubscription? postsSubscription;
    final likesSubscriptions = <StreamSubscription>[];
    var generation = 0;
    controller = StreamController<List<CommunityPost>>(
      onListen: () {
        postsSubscription = query.snapshots().listen((snapshot) {
          final current = ++generation;
          for (final subscription in likesSubscriptions) {
            unawaited(subscription.cancel());
          }
          likesSubscriptions.clear();
          final counts = <String, int>{};
          void emit() {
            if (controller.isClosed || current != generation) return;
            final posts = <CommunityPost>[];
            for (final doc in snapshot.docs) {
              final post = _postFrom(doc.id, doc.data(), counts[doc.id] ?? 0);
              if (post != null) posts.add(post);
            }
            controller.add(posts);
          }

          emit();
          for (final doc in snapshot.docs) {
            likesSubscriptions.add(
              doc.reference.collection('likes').snapshots().listen((likes) {
                counts[doc.id] = likes.size;
                emit();
              }, onError: controller.addError),
            );
          }
        }, onError: controller.addError);
      },
      onCancel: () async {
        generation++;
        await postsSubscription?.cancel();
        for (final subscription in likesSubscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// One malformed document must not take down the whole feed: it is
  /// skipped (and logged) instead of throwing inside the snapshot listener,
  /// where the error would never reach the screen.
  CommunityPost? _postFrom(String id, Map<String, dynamic> data, int likes) {
    try {
      return CommunityPost(
        postId: id,
        userId: data['userId'] as String,
        anonymizedUsername: data['anonymizedUsername'] as String,
        content: data['content'] as String,
        category: PostCategory.values.firstWhere(
          (c) => c.name == data['category'],
        ),
        timestamp: DateTime.parse(data['timestamp'] as String),
        likeCount: likes,
      );
    } catch (e) {
      debugPrint('Skipping malformed community post $id: $e');
      return null;
    }
  }

  @override
  Stream<List<CommunityReply>> watchReplies(String postId) => _posts
      .doc(postId)
      .collection('replies')
      .orderBy('timestamp')
      .snapshots()
      .map((snapshot) {
        final replies = <CommunityReply>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            replies.add(
              CommunityReply(
                replyId: doc.id,
                postId: postId,
                userId: data['userId'] as String,
                anonymizedUsername: data['anonymizedUsername'] as String,
                content: data['content'] as String,
                timestamp: DateTime.parse(data['timestamp'] as String),
              ),
            );
          } catch (e) {
            debugPrint('Skipping malformed reply ${doc.id}: $e');
          }
        }
        return replies;
      });

  @override
  Future<void> createPost(CommunityPost post) async {
    await _posts.doc(post.postId).set({
      'userId': post.userId,
      'anonymizedUsername': post.anonymizedUsername,
      'content': post.content,
      'category': post.category.name,
      'timestamp': post.timestamp.toIso8601String(),
    });
  }

  @override
  Future<List<CommunityPost>> getPosts({PostCategory? category}) async {
    Query<Map<String, dynamic>> query = _posts.orderBy(
      'timestamp',
      descending: true,
    );
    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    final snapshot = await query.get();
    final results = <CommunityPost>[];
    for (final doc in snapshot.docs) {
      final likesSnapshot = await _posts.doc(doc.id).collection('likes').get();
      final post = _postFrom(doc.id, doc.data(), likesSnapshot.docs.length);
      if (post != null) results.add(post);
    }
    return results;
  }

  @override
  Future<bool> hasLiked({
    required String postId,
    required String userId,
  }) async {
    final doc = await _posts.doc(postId).collection('likes').doc(userId).get();
    return doc.exists;
  }

  @override
  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  }) async {
    final likeDoc = _posts.doc(postId).collection('likes').doc(userId);
    if (liked) {
      await likeDoc.set({'likedAt': DateTime.now().toIso8601String()});
    } else {
      await likeDoc.delete();
    }
  }

  @override
  Future<List<CommunityReply>> getReplies(String postId) async {
    final snapshot = await _posts
        .doc(postId)
        .collection('replies')
        .orderBy('timestamp')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CommunityReply(
        replyId: doc.id,
        postId: postId,
        userId: data['userId'] as String,
        anonymizedUsername: data['anonymizedUsername'] as String,
        content: data['content'] as String,
        timestamp: DateTime.parse(data['timestamp'] as String),
      );
    }).toList();
  }

  @override
  Future<void> addReply(CommunityReply reply) async {
    await _posts
        .doc(reply.postId)
        .collection('replies')
        .doc(reply.replyId)
        .set({
          'userId': reply.userId,
          'anonymizedUsername': reply.anonymizedUsername,
          'content': reply.content,
          'timestamp': reply.timestamp.toIso8601String(),
        });
  }
}

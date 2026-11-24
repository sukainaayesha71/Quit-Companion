import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/community_reply.dart';
import 'package:quit_companion/features/community/models/post_category.dart';

CommunityPost _post({
  required String postId,
  required PostCategory category,
  required DateTime timestamp,
}) {
  return CommunityPost(
    postId: postId,
    userId: 'u1',
    anonymizedUsername: 'QuitWarrior_22',
    content: 'Day 15 nicotine-free!',
    category: category,
    timestamp: timestamp,
  );
}

void main() {
  test(
    'getPosts returns everything, newest first, when no category filter is given',
    () async {
      final repo = FakeCommunityPostRepository();
      await repo.createPost(
        _post(
          postId: 'a',
          category: PostCategory.milestone,
          timestamp: DateTime(2026, 8, 1),
        ),
      );
      await repo.createPost(
        _post(
          postId: 'b',
          category: PostCategory.tip,
          timestamp: DateTime(2026, 8, 10),
        ),
      );

      final posts = await repo.getPosts();

      expect(posts.map((p) => p.postId), ['b', 'a']);
    },
  );

  test('getPosts filters by category when given', () async {
    final repo = FakeCommunityPostRepository();
    await repo.createPost(
      _post(
        postId: 'a',
        category: PostCategory.milestone,
        timestamp: DateTime(2026, 8, 1),
      ),
    );
    await repo.createPost(
      _post(
        postId: 'b',
        category: PostCategory.tip,
        timestamp: DateTime(2026, 8, 10),
      ),
    );

    final posts = await repo.getPosts(category: PostCategory.tip);

    expect(posts.map((p) => p.postId), ['b']);
  });

  test(
    'setLiked(true) then hasLiked reflects it, and getPosts reports the count',
    () async {
      final repo = FakeCommunityPostRepository();
      await repo.createPost(
        _post(
          postId: 'a',
          category: PostCategory.milestone,
          timestamp: DateTime(2026, 8, 1),
        ),
      );

      expect(await repo.hasLiked(postId: 'a', userId: 'liker1'), isFalse);
      await repo.setLiked(postId: 'a', userId: 'liker1', liked: true);
      expect(await repo.hasLiked(postId: 'a', userId: 'liker1'), isTrue);

      final posts = await repo.getPosts();
      expect(posts.single.likeCount, 1);
    },
  );

  test('setLiked(false) unlikes and decrements the count', () async {
    final repo = FakeCommunityPostRepository();
    await repo.createPost(
      _post(
        postId: 'a',
        category: PostCategory.milestone,
        timestamp: DateTime(2026, 8, 1),
      ),
    );
    await repo.setLiked(postId: 'a', userId: 'liker1', liked: true);

    await repo.setLiked(postId: 'a', userId: 'liker1', liked: false);

    expect(await repo.hasLiked(postId: 'a', userId: 'liker1'), isFalse);
    expect((await repo.getPosts()).single.likeCount, 0);
  });

  test(
    'addReply then getReplies returns replies for that post, oldest first',
    () async {
      final repo = FakeCommunityPostRepository();
      await repo.addReply(
        CommunityReply(
          replyId: 'r2',
          postId: 'a',
          userId: 'u2',
          anonymizedUsername: 'FreshStart_5',
          content: 'later reply',
          timestamp: DateTime(2026, 8, 10),
        ),
      );
      await repo.addReply(
        CommunityReply(
          replyId: 'r1',
          postId: 'a',
          userId: 'u3',
          anonymizedUsername: 'BraveSoul_9',
          content: 'earlier reply',
          timestamp: DateTime(2026, 8, 5),
        ),
      );

      final replies = await repo.getReplies('a');

      expect(replies.map((r) => r.replyId), ['r1', 'r2']);
    },
  );

  test(
    'createPost throws when failWith is set, simulating a Firestore failure',
    () async {
      final repo = FakeCommunityPostRepository()
        ..failWith = Exception('firestore down');

      expect(
        () => repo.createPost(
          _post(
            postId: 'a',
            category: PostCategory.milestone,
            timestamp: DateTime(2026, 8, 1),
          ),
        ),
        throwsException,
      );
    },
  );
}

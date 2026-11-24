import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';

void main() {
  group('CommunityController', () {
    test(
      'loadFeed populates posts, newest first, and tracks which the current user liked',
      () async {
        final repository = FakeCommunityPostRepository();
        await repository.createPost(
          CommunityPost(
            postId: 'a',
            userId: 'author1',
            anonymizedUsername: 'QuitWarrior_22',
            content: 'Day 15!',
            category: PostCategory.milestone,
            timestamp: DateTime(2026, 8, 1),
          ),
        );
        await repository.setLiked(postId: 'a', userId: 'u1', liked: true);
        final controller = CommunityController(
          repository,
          now: () => DateTime(2026, 8, 19),
        );

        await controller.loadFeed(userId: 'u1');

        expect(controller.status, CommunityStatus.loaded);
        expect(controller.posts, hasLength(1));
        expect(controller.likedPostIds, {'a'});
      },
    );

    test('setFilter reloads the feed scoped to that category', () async {
      final repository = FakeCommunityPostRepository();
      await repository.createPost(
        CommunityPost(
          postId: 'a',
          userId: 'author1',
          anonymizedUsername: 'QuitWarrior_22',
          content: 'A milestone post',
          category: PostCategory.milestone,
          timestamp: DateTime(2026, 8, 1),
        ),
      );
      await repository.createPost(
        CommunityPost(
          postId: 'b',
          userId: 'author1',
          anonymizedUsername: 'QuitWarrior_22',
          content: 'A tip post',
          category: PostCategory.tip,
          timestamp: DateTime(2026, 8, 2),
        ),
      );
      final controller = CommunityController(
        repository,
        now: () => DateTime(2026, 8, 19),
      );
      await controller.loadFeed(userId: 'u1');

      await controller.setFilter(userId: 'u1', category: PostCategory.tip);

      expect(controller.filter, PostCategory.tip);
      expect(controller.posts.map((p) => p.postId), ['b']);
    });

    test(
      'createPost with clean content saves it under a generated anonymized username and reloads the feed',
      () async {
        final repository = FakeCommunityPostRepository();
        final controller = CommunityController(
          repository,
          now: () => DateTime(2026, 8, 19),
        );

        final result = await controller.createPost(
          userId: 'u1',
          content: 'Staying strong today!',
          category: PostCategory.motivation,
        );

        expect(result, isTrue);
        expect(repository.posts, hasLength(1));
        expect(repository.posts.first.anonymizedUsername, isNotEmpty);
        expect(repository.posts.first.userId, 'u1');
        expect(controller.posts, hasLength(1));
      },
    );

    test(
      'createPost with blocked content is rejected, not saved, and surfaces an error',
      () async {
        final repository = FakeCommunityPostRepository();
        final controller = CommunityController(
          repository,
          now: () => DateTime(2026, 8, 19),
        );

        final result = await controller.createPost(
          userId: 'u1',
          content: 'You are such an idiot',
          category: PostCategory.question,
        );

        expect(result, isFalse);
        expect(repository.posts, isEmpty);
        expect(controller.errorMessage, isNotNull);
      },
    );

    test(
      'toggleLike flips the like state and updates the local like count',
      () async {
        final repository = FakeCommunityPostRepository();
        await repository.createPost(
          CommunityPost(
            postId: 'a',
            userId: 'author1',
            anonymizedUsername: 'QuitWarrior_22',
            content: 'Day 15!',
            category: PostCategory.milestone,
            timestamp: DateTime(2026, 8, 1),
          ),
        );
        final controller = CommunityController(
          repository,
          now: () => DateTime(2026, 8, 19),
        );
        await controller.loadFeed(userId: 'u1');

        await controller.toggleLike(postId: 'a', userId: 'u1');
        expect(controller.likedPostIds, {'a'});
        expect(controller.posts.first.likeCount, 1);

        await controller.toggleLike(postId: 'a', userId: 'u1');
        expect(controller.likedPostIds, isEmpty);
        expect(controller.posts.first.likeCount, 0);
      },
    );

    test(
      'loadReplies then addReply appends a new reply visible in repliesForCurrentPost',
      () async {
        final repository = FakeCommunityPostRepository();
        final controller = CommunityController(
          repository,
          now: () => DateTime(2026, 8, 19),
        );

        await controller.loadReplies('a');
        expect(controller.repliesForCurrentPost, isEmpty);

        await controller.addReply(
          postId: 'a',
          userId: 'u1',
          content: 'Great job!',
        );

        expect(controller.repliesForCurrentPost, hasLength(1));
        expect(controller.repliesForCurrentPost.first.content, 'Great job!');
      },
    );
  });
}

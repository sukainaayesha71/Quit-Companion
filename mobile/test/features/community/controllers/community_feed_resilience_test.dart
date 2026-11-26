import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';

/// The feed must never sit on a spinner or a blank area: posts show as soon
/// as they arrive, like lookups can't block them, and a failure before any
/// posts becomes a visible error state with Retry.
class _ScriptedRepo extends FakeCommunityPostRepository {
  StreamController<List<CommunityPost>> feed =
      StreamController<List<CommunityPost>>();
  Completer<bool>? likeGate;
  Object? likeError;

  @override
  Stream<List<CommunityPost>> watchPosts({PostCategory? category}) {
    feed = StreamController<List<CommunityPost>>();
    return feed.stream;
  }

  @override
  Future<bool> hasLiked({required String postId, required String userId}) {
    if (likeError != null) return Future.error(likeError!);
    return likeGate?.future ?? Future.value(postId == 'p1');
  }
}

CommunityPost _post(String id) => CommunityPost(
  postId: id,
  userId: 'someone',
  anonymizedUsername: 'Calm Fox',
  content: 'Day $id without smoking',
  category: PostCategory.milestone,
  timestamp: DateTime(2026, 11, 20),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('posts are shown immediately even while like lookups are pending', () async {
    final repo = _ScriptedRepo()..likeGate = Completer<bool>();
    final controller = CommunityController(repo);
    await controller.startFeed(userId: 'me');

    repo.feed.add([_post('p1'), _post('p2')]);
    await _settle();

    expect(controller.status, CommunityStatus.loaded);
    expect(controller.posts.map((p) => p.postId), ['p1', 'p2']);

    repo.likeGate!.complete(true);
    await _settle();
    await _settle();
    expect(controller.likedPostIds, {'p1', 'p2'});
  });

  test('a failing like lookup never hides the posts', () async {
    final repo = _ScriptedRepo()..likeError = Exception('offline');
    final controller = CommunityController(repo);
    await controller.startFeed(userId: 'me');

    repo.feed.add([_post('p1')]);
    await _settle();
    await _settle();

    expect(controller.status, CommunityStatus.loaded);
    expect(controller.posts, hasLength(1));
    expect(controller.likedPostIds, isEmpty);
  });

  test('a feed error before any posts shows the error state; Retry recovers', () async {
    final repo = _ScriptedRepo();
    final controller = CommunityController(repo);
    await controller.startFeed(userId: 'me');

    repo.feed.addError(Exception('permission-denied'));
    await _settle();
    expect(controller.status, CommunityStatus.error);
    expect(controller.errorMessage, CommunityController.feedErrorMessage);

    await controller.startFeed(userId: 'me'); // what the Retry button does
    repo.feed.add([_post('p1')]);
    await _settle();
    expect(controller.status, CommunityStatus.loaded);
    expect(controller.errorMessage, isNull);
  });

  test('an error after posts loaded keeps the posts on screen', () async {
    final repo = _ScriptedRepo();
    final controller = CommunityController(repo);
    await controller.startFeed(userId: 'me');
    repo.feed.add([_post('p1')]);
    await _settle();

    repo.feed.addError(Exception('connection dropped'));
    await _settle();

    expect(controller.status, CommunityStatus.loaded);
    expect(controller.posts, hasLength(1));
  });

  test('an empty feed is a loaded state (the screen shows its empty state)', () async {
    final repo = _ScriptedRepo();
    final controller = CommunityController(repo);
    await controller.startFeed(userId: 'me');
    repo.feed.add(const []);
    await _settle();
    expect(controller.status, CommunityStatus.loaded);
    expect(controller.posts, isEmpty);
  });
}

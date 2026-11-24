import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/community/presentation/screens/community_screen.dart';
import 'package:quit_companion/features/community/presentation/screens/new_post_screen.dart';
import 'package:quit_companion/features/community/presentation/screens/post_replies_screen.dart';

void main() {
  final fixedNow = DateTime(2026, 8, 19, 12, 0);

  CommunityController buildController() =>
      CommunityController(FakeCommunityPostRepository(), now: () => fixedNow);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required CommunityController controller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityScreen(userId: 'u1', controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders the approved layout: title, filter chips, and every post from the feed',
    (tester) async {
      final repository = FakeCommunityPostRepository();
      await repository.createPost(
        CommunityPost(
          postId: 'a',
          userId: 'author1',
          anonymizedUsername: 'QuitWarrior_22',
          content:
              "Day 15 nicotine-free! Some days are harder than others but I'm still going.",
          category: PostCategory.milestone,
          timestamp: fixedNow.subtract(const Duration(hours: 2)),
        ),
      );
      final controller = CommunityController(repository, now: () => fixedNow);

      await pumpScreen(tester, controller: controller);

      expect(find.text('Community'), findsOneWidget);
      expect(find.byKey(const Key('community_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('community_filter_tip')), findsOneWidget);
      expect(
        find.byKey(const Key('community_filter_milestone')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community_filter_question')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('community_filter_motivation')),
        findsOneWidget,
      );

      expect(find.text('QuitWarrior_22'), findsOneWidget);
      expect(find.text('Milestone'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
      expect(find.textContaining('Day 15 nicotine-free!'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // like count
      expect(find.text('Reply'), findsOneWidget);
    },
  );

  testWidgets(
    'an empty feed shows an empty-state message, not a blank screen',
    (tester) async {
      await pumpScreen(tester, controller: buildController());

      expect(find.byKey(const Key('community_empty_state')), findsOneWidget);
    },
  );

  testWidgets('tapping a filter chip narrows the feed to that category', (
    tester,
  ) async {
    final repository = FakeCommunityPostRepository();
    await repository.createPost(
      CommunityPost(
        postId: 'a',
        userId: 'author1',
        anonymizedUsername: 'QuitWarrior_22',
        content: 'A milestone post',
        category: PostCategory.milestone,
        timestamp: fixedNow,
      ),
    );
    await repository.createPost(
      CommunityPost(
        postId: 'b',
        userId: 'author1',
        anonymizedUsername: 'FreshStart_5',
        content: 'A tip post',
        category: PostCategory.tip,
        timestamp: fixedNow,
      ),
    );
    final controller = CommunityController(repository, now: () => fixedNow);

    await pumpScreen(tester, controller: controller);
    expect(find.textContaining('A milestone post'), findsOneWidget);
    expect(find.textContaining('A tip post'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community_filter_tip')));
    await tester.pumpAndSettle();

    expect(find.textContaining('A tip post'), findsOneWidget);
    expect(find.textContaining('A milestone post'), findsNothing);
  });

  testWidgets('tapping the like button toggles the liked state and count', (
    tester,
  ) async {
    final repository = FakeCommunityPostRepository();
    await repository.createPost(
      CommunityPost(
        postId: 'a',
        userId: 'author1',
        anonymizedUsername: 'QuitWarrior_22',
        content: 'Day 15!',
        category: PostCategory.milestone,
        timestamp: fixedNow,
      ),
    );
    final controller = CommunityController(repository, now: () => fixedNow);

    await pumpScreen(tester, controller: controller);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community_like_a')));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tapping the + button opens NewPostScreen', (tester) async {
    await pumpScreen(tester, controller: buildController());

    await tester.tap(find.byKey(const Key('community_new_post_button')));
    await tester.pumpAndSettle();

    expect(find.byType(NewPostScreen), findsOneWidget);
  });

  testWidgets('tapping Reply opens PostRepliesScreen for that post', (
    tester,
  ) async {
    final repository = FakeCommunityPostRepository();
    await repository.createPost(
      CommunityPost(
        postId: 'a',
        userId: 'author1',
        anonymizedUsername: 'QuitWarrior_22',
        content: 'Day 15!',
        category: PostCategory.milestone,
        timestamp: fixedNow,
      ),
    );
    final controller = CommunityController(repository, now: () => fixedNow);

    await pumpScreen(tester, controller: controller);
    await tester.tap(find.byKey(const Key('community_reply_a')));
    await tester.pumpAndSettle();

    expect(find.byType(PostRepliesScreen), findsOneWidget);
  });
}

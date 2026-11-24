import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_reply.dart';
import 'package:quit_companion/features/community/presentation/screens/post_replies_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    CommunityController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PostRepliesScreen(
          userId: 'u1',
          postId: 'a',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads and renders existing replies for the post', (
    tester,
  ) async {
    final repository = FakeCommunityPostRepository();
    await repository.addReply(
      CommunityReply(
        replyId: 'r1',
        postId: 'a',
        userId: 'u2',
        anonymizedUsername: 'FreshStart_5',
        content: 'So proud of you!',
        timestamp: DateTime(2026, 8, 18),
      ),
    );
    final controller = CommunityController(
      repository,
      now: () => DateTime(2026, 8, 19),
    );

    await pumpScreen(tester, controller);

    expect(find.text('FreshStart_5'), findsOneWidget);
    expect(find.text('So proud of you!'), findsOneWidget);
  });

  testWidgets('an empty reply list shows an empty-state message', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      CommunityController(FakeCommunityPostRepository()),
    );

    expect(find.byKey(const Key('post_replies_empty_state')), findsOneWidget);
  });

  testWidgets('submitting a reply appends it to the list', (tester) async {
    final repository = FakeCommunityPostRepository();
    final controller = CommunityController(
      repository,
      now: () => DateTime(2026, 8, 19),
    );
    await pumpScreen(tester, controller);

    await tester.enterText(
      find.byKey(const Key('post_replies_input_field')),
      'Keep it up!',
    );
    await tester.tap(find.byKey(const Key('post_replies_send_button')));
    await tester.pumpAndSettle();

    expect(find.text('Keep it up!'), findsOneWidget);
    expect(repository.replies, hasLength(1));
  });
}

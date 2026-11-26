import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/community/presentation/screens/community_screen.dart';
import 'package:quit_companion/features/community/presentation/screens/new_post_screen.dart';

class _FailingOnceRepo extends FakeCommunityPostRepository {
  int calls = 0;

  @override
  Stream<List<CommunityPost>> watchPosts({PostCategory? category}) {
    calls++;
    if (calls == 1) return Stream.error(Exception('permission-denied'));
    return Stream.value([
      CommunityPost(
        postId: 'p1',
        userId: 'someone',
        anonymizedUsername: 'Calm Fox',
        content: 'One week smoke-free today!',
        category: PostCategory.milestone,
        timestamp: DateTime(2026, 11, 20),
      ),
    ]);
  }
}

Future<void> _pump(WidgetTester tester, CommunityController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CommunityScreen(userId: 'me', controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty feed shows a helpful empty state with Create a post', (
    tester,
  ) async {
    await _pump(tester, CommunityController(FakeCommunityPostRepository()));

    expect(find.byKey(const Key('community_empty_state')), findsOneWidget);
    expect(find.text('No posts yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community_empty_create_button')));
    await tester.pumpAndSettle();
    expect(find.byType(NewPostScreen), findsOneWidget);
  });

  testWidgets('a load failure shows an error with Try again, which recovers', (
    tester,
  ) async {
    await _pump(tester, CommunityController(_FailingOnceRepo()));

    expect(find.byKey(const Key('community_error_state')), findsOneWidget);
    expect(
      find.text(CommunityController.feedErrorMessage),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('community_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community_error_state')), findsNothing);
    expect(find.text('One week smoke-free today!'), findsOneWidget);
  });
}

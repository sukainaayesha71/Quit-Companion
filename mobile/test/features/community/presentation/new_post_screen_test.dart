import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/presentation/screens/new_post_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    CommunityController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewPostScreen(userId: 'u1', controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a content field, category selector, and Post button', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      CommunityController(FakeCommunityPostRepository()),
    );

    expect(find.byKey(const Key('new_post_content_field')), findsOneWidget);
    expect(
      find.byKey(const Key('new_post_category_milestone')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new_post_category_tip')), findsOneWidget);
    expect(find.byKey(const Key('new_post_category_question')), findsOneWidget);
    expect(
      find.byKey(const Key('new_post_category_motivation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new_post_submit_button')), findsOneWidget);
  });

  testWidgets('submitting valid content and a category pops back to the feed', (
    tester,
  ) async {
    final repository = FakeCommunityPostRepository();
    final controller = CommunityController(
      repository,
      now: () => DateTime(2026, 8, 19),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    NewPostScreen(userId: 'u1', controller: controller),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('new_post_content_field')),
      'Staying strong today!',
    );
    await tester.tap(find.byKey(const Key('new_post_category_motivation')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('new_post_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(NewPostScreen), findsNothing);
    expect(repository.posts, hasLength(1));
    expect(repository.posts.first.content, 'Staying strong today!');
  });

  testWidgets(
    'blocked content shows an inline error and does not navigate away',
    (tester) async {
      final controller = CommunityController(FakeCommunityPostRepository());
      await pumpScreen(tester, controller);

      await tester.enterText(
        find.byKey(const Key('new_post_content_field')),
        'you are an idiot',
      );
      await tester.tap(find.byKey(const Key('new_post_category_tip')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('new_post_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(NewPostScreen), findsOneWidget);
      expect(find.byKey(const Key('new_post_error_text')), findsOneWidget);
    },
  );

  testWidgets(
    'submitting without selecting a category shows a validation error',
    (tester) async {
      final controller = CommunityController(FakeCommunityPostRepository());
      await pumpScreen(tester, controller);

      await tester.enterText(
        find.byKey(const Key('new_post_content_field')),
        'Hello everyone',
      );
      await tester.tap(find.byKey(const Key('new_post_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('new_post_validation_error')),
        findsOneWidget,
      );
    },
  );
}

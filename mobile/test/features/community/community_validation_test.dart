import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/domain/community_post_validator.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/community/presentation/screens/new_post_screen.dart';
import 'package:quit_companion/features/community/presentation/screens/post_replies_screen.dart';

/// FR10 community post validation.
void main() {
  group('validateCommunityText', () {
    test('accepts normal text, emoji and multi-line posts', () {
      expect(validateCommunityText('Day 3 smoke-free!'), isNull);
      expect(validateCommunityText('One week 🎉💪'), isNull);
      expect(validateCommunityText('Line one\nLine two\n\tindented'), isNull);
      expect(validateCommunityText('  padded  '), isNull);
    });

    test('rejects empty, whitespace-only and invisible-only text', () {
      for (final text in ['', '   ', '\n\t \r\n', '​​', ' ﻿ ⁠ ']) {
        expect(
          validateCommunityText(text),
          CommunityTextError.empty,
          reason: text.codeUnits.toString(),
        );
      }
    });

    test('enforces the 2000-character limit after trimming', () {
      expect(validateCommunityText('a' * 2000), isNull);
      expect(validateCommunityText('  ${'a' * 2000}  '), isNull);
      expect(validateCommunityText('a' * 2001), CommunityTextError.tooLong);
    });

    test('rejects control characters and broken (unpaired) surrogates', () {
      expect(
        validateCommunityText('hello\u0000world'),
        CommunityTextError.invalidCharacters,
      );
      expect(
        validateCommunityText('bell\u0007'),
        CommunityTextError.invalidCharacters,
      );
      expect(
        validateCommunityText('broken \uD83D text'),
        CommunityTextError.invalidCharacters,
      );
      expect(
        validateCommunityText('lone \uDE00 low'),
        CommunityTextError.invalidCharacters,
      );
    });

    test('messages are specific and mention the limit', () {
      expect(
        communityTextErrorMessage(
          CommunityTextError.tooLong,
          isReply: false,
          length: 2100,
        ),
        contains('2000 characters (currently 2100)'),
      );
      expect(
        communityTextErrorMessage(CommunityTextError.empty, isReply: true),
        'Write a reply before sending.',
      );
    });
  });

  group('CommunityController validation', () {
    late FakeCommunityPostRepository repo;
    late CommunityController controller;

    setUp(() {
      repo = FakeCommunityPostRepository();
      controller = CommunityController(
        repo,
        now: () => DateTime(2026, 11, 23, 10),
      );
    });

    Future<bool> post(String content, {String userId = 'u1'}) =>
        controller.createPost(
          userId: userId,
          content: content,
          category: PostCategory.tip,
        );

    test('a valid post is saved trimmed', () async {
      expect(await post('  Drink water when a craving hits.  '), isTrue);
      final saved = (await repo.getPosts()).single;
      expect(saved.content, 'Drink water when a craving hits.');
      expect(controller.errorMessage, isNull);
    });

    test(
      'a 2000-character post is accepted; 2001 is rejected and not saved',
      () async {
        expect(await post('a' * 2000), isTrue);
        expect(await post('b' * 2001), isFalse);
        expect(controller.errorMessage, contains('2000 characters'));
        expect(await repo.getPosts(), hasLength(1));
      },
    );

    test(
      'empty, whitespace-only and invalid posts are rejected and not saved',
      () async {
        for (final content in ['', '    ', '​', 'bad\u0000char']) {
          expect(
            await post(content),
            isFalse,
            reason: content.codeUnits.toString(),
          );
          expect(controller.errorMessage, isNotNull);
        }
        expect(await repo.getPosts(), isEmpty);
      },
    );

    test('a missing user is rejected', () async {
      expect(await post('hello', userId: '  '), isFalse);
      expect(controller.errorMessage, contains('sign in'));
    });

    test('the existing content filter still blocks flagged posts', () async {
      expect(await post('you are stupid'), isFalse);
      expect(controller.errorMessage, contains('could not be shared'));
    });

    test(
      'redaction that would push the stored text over the limit is caught',
      () async {
        // "[email removed]" (15 chars) replaces a 6-char email, adding 9.
        final fits = '${'a' * 1980} x@y.co'; // 1987 raw -> 1996 stored
        expect(await post(fits), isTrue);

        final growsPastLimit =
            '${'a' * 1985} x@y.co'; // 1992 raw -> 2001 stored
        expect(validateCommunityText(growsPastLimit), isNull);
        expect(await post(growsPastLimit), isFalse);
        expect(controller.errorMessage, contains('(currently 2001)'));
        expect(await repo.getPosts(), hasLength(1));
      },
    );

    test(
      'replies are validated the same way; valid replies, likes still work',
      () async {
        expect(await post('Proud of a week!'), isTrue);
        final postId = (await repo.getPosts()).single.postId;

        expect(
          await controller.addReply(
            postId: postId,
            userId: 'u2',
            content: '   ',
          ),
          isFalse,
        );
        expect(controller.errorMessage, 'Write a reply before sending.');
        expect(
          await controller.addReply(
            postId: postId,
            userId: 'u2',
            content: 'c' * 2001,
          ),
          isFalse,
        );
        expect(
          await controller.addReply(
            postId: postId,
            userId: 'u2',
            content: 'Well done!',
          ),
          isTrue,
        );
        expect((await repo.getReplies(postId)).single.content, 'Well done!');

        await controller.loadFeed(userId: 'u2');
        await controller.toggleLike(postId: postId, userId: 'u2');
        expect(controller.likedPostIds, contains(postId));
        expect(controller.posts.single.likeCount, 1);
      },
    );
  });

  group('compose screens', () {
    CommunityController build() => CommunityController(
      FakeCommunityPostRepository(),
      now: () => DateTime(2026, 11, 23),
    );

    Future<void> pumpNewPost(
      WidgetTester tester,
      CommunityController controller,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
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
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a whitespace-only post shows an inline message and stays on screen',
      (tester) async {
        final controller = build();
        await pumpNewPost(tester, controller);

        await tester.enterText(
          find.byKey(const Key('new_post_content_field')),
          '   ',
        );
        await tester.tap(find.byKey(const Key('new_post_category_tip')));
        await tester.tap(find.byKey(const Key('new_post_submit_button')));
        await tester.pumpAndSettle();

        expect(find.text('Write something before posting.'), findsOneWidget);
        expect(find.byType(NewPostScreen), findsOneWidget);
      },
    );

    testWidgets(
      'an over-long post shows the limit, is not truncated, and is not posted',
      (tester) async {
        final controller = build();
        await pumpNewPost(tester, controller);
        final text = 'x' * 2050;

        await tester.enterText(
          find.byKey(const Key('new_post_content_field')),
          text,
        );
        await tester.pump();
        expect(find.text('2050/2000'), findsOneWidget);
        await tester.tap(find.byKey(const Key('new_post_category_question')));
        await tester.tap(find.byKey(const Key('new_post_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('the limit is 2000 characters (currently 2050)'),
          findsOneWidget,
        );
        final field = tester.widget<TextField>(
          find.byKey(const Key('new_post_content_field')),
        );
        expect(
          field.controller!.text,
          text,
          reason: 'never silently truncated',
        );
        expect(find.byType(NewPostScreen), findsOneWidget);
      },
    );

    testWidgets('content and category errors can show together', (
      tester,
    ) async {
      await pumpNewPost(tester, build());
      await tester.tap(find.byKey(const Key('new_post_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Write something before posting.'), findsOneWidget);
      expect(
        find.byKey(const Key('new_post_validation_error')),
        findsOneWidget,
      );
    });

    testWidgets('a valid post still saves and returns to the feed', (
      tester,
    ) async {
      final controller = build();
      await pumpNewPost(tester, controller);
      await tester.enterText(
        find.byKey(const Key('new_post_content_field')),
        'Hit 30 days!',
      );
      await tester.tap(find.byKey(const Key('new_post_category_milestone')));
      await tester.tap(find.byKey(const Key('new_post_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(NewPostScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
      'replies: blank shows a message; near-limit shows a counter; valid sends',
      (tester) async {
        final repo = FakeCommunityPostRepository();
        final controller = CommunityController(
          repo,
          now: () => DateTime(2026, 11, 23),
        );
        await controller.createPost(
          userId: 'u1',
          content: 'Day 5',
          category: PostCategory.milestone,
        );
        final postId = (await repo.getPosts()).single.postId;

        await tester.pumpWidget(
          MaterialApp(
            home: PostRepliesScreen(
              postId: postId,
              userId: 'u2',
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('post_replies_input_field')),
          '  ',
        );
        await tester.tap(find.byKey(const Key('post_replies_send_button')));
        await tester.pumpAndSettle();
        expect(find.text('Write a reply before sending.'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('post_replies_input_field')),
          'y' * 1900,
        );
        await tester.pump();
        expect(find.byKey(const Key('post_replies_counter')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('post_replies_input_field')),
          'Keep going!',
        );
        await tester.pump();
        expect(find.byKey(const Key('post_replies_counter')), findsNothing);
        await tester.tap(find.byKey(const Key('post_replies_send_button')));
        await tester.pumpAndSettle();
        expect(find.text('Keep going!'), findsOneWidget);
      },
    );
  });
}

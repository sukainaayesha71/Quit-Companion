import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_video_library.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_video.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/article_detail_screen.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/knowledge_hub_screen.dart';

/// FR12 Knowledge Hub educational videos.
void main() {
  group('verified video library', () {
    test('covers all four required topics', () {
      final topics = knowledgeVideoLibrary.map((v) => v.topic).toSet();
      expect(topics, VideoTopic.values.toSet());
    });

    test(
      'every entry has a title, description, trusted source and well-formed link',
      () {
        final ids = <String>{};
        final youtube = RegExp(
          r'^https://www\.youtube\.com/watch\?v=[A-Za-z0-9_-]{11}$',
        );
        for (final v in knowledgeVideoLibrary) {
          expect(ids.add(v.videoId), isTrue, reason: 'duplicate ${v.videoId}');
          expect(v.title.trim(), isNotEmpty);
          expect(
            v.description.trim().length,
            greaterThan(20),
            reason: v.videoId,
          );
          expect(v.verification.trim(), isNotEmpty, reason: v.videoId);
          expect(v.sourceName, 'CDC');
          switch (v.platform) {
            case VideoPlatform.youtube:
              expect(youtube.hasMatch(v.url), isTrue, reason: v.url);
            case VideoPlatform.webPage:
              expect(Uri.parse(v.url).host, 'www.cdc.gov', reason: v.url);
              expect(v.url, startsWith('https://'));
          }
        }
      },
    );

    test('no video URL is repeated', () {
      final urls = knowledgeVideoLibrary.map((v) => v.url).toList();
      expect(urls.toSet().length, urls.length);
    });

    test('controller groups videos by topic in the defined order', () {
      final controller = KnowledgeHubController(
        FakeArticleBookmarkRepository(),
      );
      final groups = controller.videosByTopic;
      expect(groups.keys.toList(), VideoTopic.values);
      expect(
        groups.values.fold<int>(0, (n, list) => n + list.length),
        knowledgeVideoLibrary.length,
      );
    });
  });

  group('KnowledgeHubScreen videos', () {
    Future<void> pump(
      WidgetTester tester, {
      KnowledgeHubController? controller,
      Future<bool> Function(String url)? openUrl,
      Size size = const Size(800, 6000),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: KnowledgeHubScreen(
            userId: 'u1',
            controller:
                controller ??
                KnowledgeHubController(FakeArticleBookmarkRepository()),
            openUrl: openUrl,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'articles stay the default view; Videos lists every video under its topic',
      (tester) async {
        await pump(tester);

        expect(find.text('Lungs at Day 3'), findsOneWidget);
        expect(find.byKey(const Key('knowledge_video_list')), findsNothing);

        await tester.tap(find.byKey(const Key('knowledge_tab_videos')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('knowledge_video_list')), findsOneWidget);
        expect(find.byKey(const Key('knowledge_filter_all')), findsNothing);
        expect(find.text('Lungs at Day 3'), findsNothing);
        for (final topic in VideoTopic.values) {
          expect(
            find.byKey(Key('knowledge_video_topic_${topic.name}')),
            findsOneWidget,
          );
        }
        for (final video in knowledgeVideoLibrary) {
          expect(
            find.byKey(Key('knowledge_video_${video.videoId}')),
            findsOneWidget,
          );
          expect(find.text(video.title), findsOneWidget);
          expect(find.text(video.description), findsOneWidget);
        }
        expect(find.text('CDC · YouTube'), findsWidgets);
      },
    );

    testWidgets('tapping a video opens its exact verified URL externally', (
      tester,
    ) async {
      final opened = <String>[];
      await pump(
        tester,
        openUrl: (url) async {
          opened.add(url);
          return true;
        },
      );
      await tester.tap(find.byKey(const Key('knowledge_tab_videos')));
      await tester.pumpAndSettle();

      final youtubeVideo = knowledgeVideoLibrary.firstWhere(
        (v) => v.platform == VideoPlatform.youtube,
      );
      final pageVideo = knowledgeVideoLibrary.firstWhere(
        (v) => v.platform == VideoPlatform.webPage,
      );
      await tester.tap(
        find.byKey(Key('knowledge_video_${youtubeVideo.videoId}')),
      );
      await tester.pump();
      await tester.tap(find.byKey(Key('knowledge_video_${pageVideo.videoId}')));
      await tester.pump();

      expect(opened, [youtubeVideo.url, pageVideo.url]);
      expect(find.byType(ArticleDetailScreen), findsNothing);
    });

    testWidgets('if the link cannot be opened the user is told', (
      tester,
    ) async {
      await pump(tester, openUrl: (_) async => false);
      await tester.tap(find.byKey(const Key('knowledge_tab_videos')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          Key('knowledge_video_${knowledgeVideoLibrary.first.videoId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not open the video'), findsOneWidget);
    });

    testWidgets(
      'switching back to Articles keeps filters, bookmarks and article navigation working',
      (tester) async {
        final repository = FakeArticleBookmarkRepository();
        await repository.setBookmarked(
          userId: 'u1',
          articleId: 'health_benefits',
          bookmarked: true,
        );
        await pump(tester, controller: KnowledgeHubController(repository));

        await tester.tap(find.byKey(const Key('knowledge_tab_videos')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('knowledge_tab_articles')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('knowledge_filter_saved')), findsOneWidget);
        expect(
          find.byKey(const Key('knowledge_bookmark_health_benefits_filled')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('knowledge_filter_saved')));
        await tester.pumpAndSettle();
        expect(find.text('Lungs at Day 3'), findsNothing);
        await tester.tap(
          find.byKey(const Key('knowledge_article_health_benefits')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ArticleDetailScreen), findsOneWidget);
      },
    );

    testWidgets('the video list fits a 320x640 screen at 1.5x text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, size: const Size(320, 640));

      await tester.tap(find.byKey(const Key('knowledge_tab_videos')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 10; i++) {
        await tester.drag(
          find.byKey(const Key('knowledge_video_list')),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}

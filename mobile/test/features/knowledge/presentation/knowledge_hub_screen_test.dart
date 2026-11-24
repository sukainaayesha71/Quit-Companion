import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/article_detail_screen.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/knowledge_hub_screen.dart';

void main() {
  KnowledgeHubController buildController() =>
      KnowledgeHubController(FakeArticleBookmarkRepository());

  Future<void> pumpScreen(
    WidgetTester tester, {
    KnowledgeHubController? controller,
  }) async {
    // The 2-column article grid is taller than the default 800x600 test
    // surface — enlarge it so every card in the fixed 16-article library
    // is actually built and visible, matching how a real device's taller
    // viewport renders this screen.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeHubScreen(
          userId: 'u1',
          controller: controller ?? buildController(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders the approved layout: title, search, category chips and article cards',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('Knowledge Hub'), findsOneWidget);
      expect(find.byKey(const Key('knowledge_search_icon')), findsOneWidget);
      expect(find.byKey(const Key('knowledge_filter_all')), findsOneWidget);
      // Owner-approved categories (2026-11-23): four groups + Health Risks.
      for (final category in KnowledgeCategory.values) {
        expect(
          find.byKey(
            Key('knowledge_filter_${category.name}'),
            skipOffstage: false,
          ),
          findsOneWidget,
          reason: category.name,
        );
      }
      // The first cards of the library render with title, summary and a
      // length-based reading time.
      expect(find.text('Lungs at Day 3'), findsOneWidget);
      expect(
        find.byKey(const Key('knowledge_summary_lungs_day_3')),
        findsOneWidget,
      );
      expect(find.textContaining('min read'), findsWidgets);
    },
  );

  testWidgets(
    'tapping a filter chip narrows the article grid to that category',
    (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(
        find.byKey(const Key('knowledge_filter_healthRisks')),
      );
      await tester.tap(find.byKey(const Key('knowledge_filter_healthRisks')));
      await tester.pumpAndSettle();

      expect(find.text('Your Lungs on Smoke'), findsOneWidget);
      expect(find.text('Smoke and the Heart'), findsOneWidget);
      expect(find.text('Lungs at Day 3'), findsNothing);
    },
  );

  testWidgets('tapping an article card opens ArticleDetailScreen', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.byKey(const Key('knowledge_article_health_benefits')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ArticleDetailScreen), findsOneWidget);
  });

  testWidgets('a bookmarked article shows a filled bookmark icon on its card', (
    tester,
  ) async {
    final repository = FakeArticleBookmarkRepository();
    await repository.setBookmarked(
      userId: 'u1',
      articleId: 'health_benefits',
      bookmarked: true,
    );
    final controller = KnowledgeHubController(repository);

    await pumpScreen(tester, controller: controller);

    expect(
      find.byKey(const Key('knowledge_bookmark_health_benefits_filled')),
      findsOneWidget,
    );
  });
}

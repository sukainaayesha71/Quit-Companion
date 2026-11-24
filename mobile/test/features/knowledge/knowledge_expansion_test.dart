import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_article_library.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_article_library_expanded.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_resource_library.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/article_detail_screen.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/knowledge_hub_screen.dart';

/// Knowledge Hub expansion (2026-11-23): content integrity, search,
/// categories, external resources, disclaimer and bookmark preservation.
void main() {
  const originalIds = [
    'lungs_day_3',
    'health_benefits',
    'why_anxious',
    'brain_on_cravings',
    'heart_day_7',
    'science_of_addiction',
    'lungs_on_smoke',
    'smoke_and_heart',
    'tobacco_and_cancer',
    'vaping_beyond_vapor',
    'secondhand_smoke',
    'brain_on_nicotine',
    'withdrawal_timeline',
    'quitting_20min_15yr',
    'long_term_payoff',
    'what_actually_works',
  ];

  group('library content', () {
    test('16 original + 21 new articles, all with unique ids', () {
      expect(expandedKnowledgeArticles, hasLength(21));
      expect(knowledgeArticleLibrary, hasLength(37));
      final ids = knowledgeArticleLibrary.map((a) => a.articleId).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('original article ids are unchanged, so saved bookmarks still '
        'resolve', () {
      final ids = knowledgeArticleLibrary.map((a) => a.articleId).toSet();
      expect(ids.containsAll(originalIds), isTrue);
    });

    test('every category has articles; every article has a summary and '
        'at least one trusted resource', () {
      for (final category in KnowledgeCategory.values) {
        expect(
          knowledgeArticleLibrary.where((a) => a.category == category),
          isNotEmpty,
          reason: category.name,
        );
      }
      for (final article in knowledgeArticleLibrary) {
        expect(article.summary.trim(), isNotEmpty, reason: article.articleId);
        expect(article.resources, isNotEmpty, reason: article.articleId);
      }
    });

    test('every resource link is https on its organisation\'s own host', () {
      final all = {
        for (final a in knowledgeArticleLibrary) ...a.resources,
        ...knowledgeResourceLibrary,
      };
      for (final r in all) {
        final uri = Uri.parse(r.url);
        expect(uri.scheme, 'https', reason: r.url);
        expect(uri.host, r.organization.host, reason: r.url);
        expect(r.title.trim(), isNotEmpty);
      }
    });

    test('no medicine dosages appear in article text', () {
      final dose = RegExp(
        r'\b\d+(\.\d+)?\s*(mg|milligram)',
        caseSensitive: false,
      );
      for (final a in knowledgeArticleLibrary) {
        expect(dose.hasMatch(a.body), isFalse, reason: a.articleId);
      }
    });

    test('reading time is words ÷ 200, rounded up, minimum 1', () {
      String words(int n) => List.filled(n, 'word').join(' ');
      KnowledgeArticle article(int n) => KnowledgeArticle(
        articleId: 'x',
        title: 't',
        category: KnowledgeCategory.healthWellness,
        summary: 's',
        body: words(n),
      );
      expect(article(5).readTimeMinutes, 1);
      expect(article(200).readTimeMinutes, 1);
      expect(article(201).readTimeMinutes, 2);
      expect(article(450).readTimeMinutes, 3);
    });
  });

  group('controller search', () {
    late KnowledgeHubController controller;
    setUp(() async {
      controller = KnowledgeHubController(FakeArticleBookmarkRepository());
      await controller.loadArticles(userId: 'u1');
    });

    test('matches title, summary or body, case-insensitively', () {
      controller.setQuery('SLEEP');
      final ids = controller.filteredArticles.map((a) => a.articleId);
      expect(ids, contains('sleep_after_quitting'));
      expect(ids, isNot(contains('lungs_on_smoke')));
    });

    test('combines with the category filter; no match gives an empty list', () {
      controller.setQuery('craving');
      controller.setFilter(KnowledgeCategory.cravingsRelapse);
      expect(
        controller.filteredArticles.every(
          (a) => a.category == KnowledgeCategory.cravingsRelapse,
        ),
        isTrue,
      );
      controller.setQuery('zzzz-not-a-topic');
      expect(controller.filteredArticles, isEmpty);
      controller.setQuery('');
      controller.setFilter(null);
      expect(controller.filteredArticles, hasLength(37));
    });

    test('bookmarks still work for original and new articles', () async {
      await controller.toggleBookmark(userId: 'u1', articleId: 'lungs_day_3');
      await controller.toggleBookmark(
        userId: 'u1',
        articleId: 'sleep_after_quitting',
      );
      controller.setSavedOnly(true);
      expect(
        controller.filteredArticles.map((a) => a.articleId),
        containsAll(['lungs_day_3', 'sleep_after_quitting']),
      );
    });
  });

  group('hub screen', () {
    Future<List<String>> pumpHub(WidgetTester tester) async {
      final opened = <String>[];
      final controller = KnowledgeHubController(
        FakeArticleBookmarkRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: KnowledgeHubScreen(
            userId: 'u1',
            controller: controller,
            openUrl: (url) async {
              opened.add(url);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('the search icon opens a working search field', (tester) async {
      await pumpHub(tester);
      await tester.tap(find.byKey(const Key('knowledge_search_icon')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('knowledge_search_field')),
        'improving your sleep',
      );
      await tester.pumpAndSettle();
      expect(find.text('Improving Your Sleep After Quitting'), findsOneWidget);
      expect(find.text('Lungs at Day 3'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('knowledge_search_field')),
        'zzzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('No articles match "zzzz".'), findsOneWidget);

      await tester.tap(find.byKey(const Key('knowledge_search_icon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('knowledge_search_field')), findsNothing);
      expect(find.text('Lungs at Day 3'), findsOneWidget);
    });

    testWidgets('Links view lists trusted resources marked External and '
        'opens them', (tester) async {
      final opened = await pumpHub(tester);
      await tester.tap(find.byKey(const Key('knowledge_tab_resources')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('knowledge_resources_intro')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('knowledge_resource_org_who')),
        findsOneWidget,
      );
      expect(find.text('External'), findsWidgets);
      await tester.tap(find.text('Tobacco and nicotine (fact sheet)'));
      await tester.pumpAndSettle();
      expect(opened, [KnowledgeResources.whoTobacco.url]);
    });
  });

  group('article detail', () {
    testWidgets('shows summary, labelled external links, and the medical '
        'disclaimer', (tester) async {
      final opened = <String>[];
      final article = knowledgeArticleLibrary.firstWhere(
        (a) => a.articleId == 'sleep_after_quitting',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ArticleDetailScreen(
            userId: 'u1',
            article: article,
            controller: KnowledgeHubController(FakeArticleBookmarkRepository()),
            openUrl: (url) async {
              opened.add(url);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('article_detail_summary')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('article_detail_disclaimer')),
        300,
      );
      expect(
        find.byKey(const Key('article_detail_resources_heading')),
        findsOneWidget,
      );
      expect(find.text(ArticleDetailScreen.medicalDisclaimer), findsOneWidget);
      expect(find.text('External'), findsNWidgets(article.resources.length));

      await tester.tap(find.byKey(const Key('article_resource_0')));
      await tester.pumpAndSettle();
      expect(opened, [article.resources.first.url]);
    });
  });
}

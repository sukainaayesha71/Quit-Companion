import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/article_detail_screen.dart';

const _article = KnowledgeArticle(
  articleId: 'health_benefits',
  title: 'Health Benefits',
  category: KnowledgeCategory.addictionRecovery,
  summary: 'The health gains that begin within a day of quitting.',
  body: 'Quitting nicotine brings measurable health benefits...',
);

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    KnowledgeHubController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleDetailScreen(
          userId: 'u1',
          article: _article,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the title, read time, and full body', (tester) async {
    await pumpScreen(
      tester,
      KnowledgeHubController(FakeArticleBookmarkRepository()),
    );

    expect(find.text('Health Benefits'), findsOneWidget);
    // Reading time is now calculated from length (owner decision,
    // 2026-11-23): this 7-word body is 1 min.
    expect(find.textContaining('1 min read'), findsOneWidget);
    expect(
      find.textContaining(
        'Quitting nicotine brings measurable health benefits',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the bookmark icon toggles the bookmark', (tester) async {
    final repository = FakeArticleBookmarkRepository();
    final controller = KnowledgeHubController(repository);
    await controller.loadArticles(userId: 'u1');

    await pumpScreen(tester, controller);

    await tester.tap(find.byKey(const Key('article_detail_bookmark_button')));
    await tester.pumpAndSettle();

    expect(await repository.getBookmarkedArticleIds('u1'), {'health_benefits'});
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    final controller = KnowledgeHubController(FakeArticleBookmarkRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArticleDetailScreen(
                  userId: 'u1',
                  article: _article,
                  controller: controller,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('article_detail_back_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ArticleDetailScreen), findsNothing);
  });
}

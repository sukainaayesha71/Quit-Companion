import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';

void main() {
  test(
    'getBookmarkedArticleIds returns empty for a user with no bookmarks',
    () async {
      final repo = FakeArticleBookmarkRepository();

      expect(await repo.getBookmarkedArticleIds('u1'), isEmpty);
    },
  );

  test(
    'setBookmarked(true) then getBookmarkedArticleIds reflects it',
    () async {
      final repo = FakeArticleBookmarkRepository();

      await repo.setBookmarked(
        userId: 'u1',
        articleId: 'health_benefits',
        bookmarked: true,
      );

      expect(await repo.getBookmarkedArticleIds('u1'), {'health_benefits'});
    },
  );

  test('setBookmarked(false) removes it', () async {
    final repo = FakeArticleBookmarkRepository();
    await repo.setBookmarked(
      userId: 'u1',
      articleId: 'health_benefits',
      bookmarked: true,
    );

    await repo.setBookmarked(
      userId: 'u1',
      articleId: 'health_benefits',
      bookmarked: false,
    );

    expect(await repo.getBookmarkedArticleIds('u1'), isEmpty);
  });

  test('bookmarks are scoped per user', () async {
    final repo = FakeArticleBookmarkRepository();
    await repo.setBookmarked(
      userId: 'u1',
      articleId: 'health_benefits',
      bookmarked: true,
    );

    expect(await repo.getBookmarkedArticleIds('u2'), isEmpty);
  });

  test(
    'setBookmarked throws when failWith is set, simulating a Firestore failure',
    () async {
      final repo = FakeArticleBookmarkRepository()
        ..failWith = Exception('firestore down');

      expect(
        () => repo.setBookmarked(
          userId: 'u1',
          articleId: 'health_benefits',
          bookmarked: true,
        ),
        throwsException,
      );
    },
  );
}

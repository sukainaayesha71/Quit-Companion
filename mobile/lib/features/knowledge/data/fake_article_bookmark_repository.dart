import 'package:quit_companion/features/knowledge/data/article_bookmark_repository.dart';

class FakeArticleBookmarkRepository implements ArticleBookmarkRepository {
  final Map<String, Set<String>> _bookmarksByUser = {};
  Object? failWith;

  @override
  Future<Set<String>> getBookmarkedArticleIds(String userId) async {
    return Set<String>.from(_bookmarksByUser[userId] ?? {});
  }

  @override
  Future<void> setBookmarked({
    required String userId,
    required String articleId,
    required bool bookmarked,
  }) async {
    if (failWith != null) throw failWith!;
    final set = _bookmarksByUser.putIfAbsent(userId, () => {});
    if (bookmarked) {
      set.add(articleId);
    } else {
      set.remove(articleId);
    }
  }
}

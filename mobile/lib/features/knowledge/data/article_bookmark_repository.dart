/// Article bookmarks (docs/UI_Design/knowledge hub 14.png shows a
/// bookmark icon on one card). Not an SDD/SRDS-defined entity — a small,
/// obviously-needed piece of user state the mockup implies but neither
/// document names. Private per-user, so this follows the normal
/// nicotineUsers/{userId}/... subcollection pattern (unlike Module 9's
/// CommunityPost, this is never shared with other users).
abstract class ArticleBookmarkRepository {
  Future<Set<String>> getBookmarkedArticleIds(String userId);

  Future<void> setBookmarked({
    required String userId,
    required String articleId,
    required bool bookmarked,
  });
}

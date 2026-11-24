import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/knowledge/data/article_bookmark_repository.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_article_library.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_resource_library.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_video_library.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_video.dart';

enum KnowledgeHubStatus { idle, loading, loaded, error }

/// FR13 (Module 10 — Knowledge Hub & Education): exposes the fixed
/// article library (never fetched — it's a compile-time constant, see
/// knowledge_article_library.dart), a category filter, and per-user
/// bookmarks (docs/UI_Design/knowledge hub 14.png's bookmark icon).
class KnowledgeHubController extends ChangeNotifier {
  final ArticleBookmarkRepository _bookmarkRepository;

  KnowledgeHubController(this._bookmarkRepository);

  KnowledgeHubStatus status = KnowledgeHubStatus.idle;
  String? errorMessage;
  List<KnowledgeArticle> articles = knowledgeArticleLibrary;

  /// FR12 educational videos (verified external links, see
  /// knowledge_video_library.dart). Not bookmarkable: bookmarks stay
  /// article-only so the existing Firestore bookmark data is unchanged.
  List<KnowledgeVideo> videos = knowledgeVideoLibrary;

  /// Videos grouped by topic, in VideoTopic order, skipping empty topics.
  Map<VideoTopic, List<KnowledgeVideo>> get videosByTopic => {
    for (final topic in VideoTopic.values)
      if (videos.any((v) => v.topic == topic))
        topic: videos.where((v) => v.topic == topic).toList(),
  };

  /// Trusted external resources for the hub's "Resources" view.
  List<KnowledgeResource> resources = knowledgeResourceLibrary;

  Set<String> bookmarkedArticleIds = {};
  KnowledgeCategory? filter;
  bool savedOnly = false;

  /// Free-text search over article title, summary and body.
  String query = '';

  List<KnowledgeArticle> get filteredArticles => articles
      .where(
        (a) =>
            (filter == null || a.category == filter) &&
            (!savedOnly || bookmarkedArticleIds.contains(a.articleId)) &&
            a.matches(query),
      )
      .toList();

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setSavedOnly(bool value) {
    savedOnly = value;
    notifyListeners();
  }

  Future<void> loadArticles({required String userId}) async {
    status = KnowledgeHubStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      bookmarkedArticleIds = await _bookmarkRepository.getBookmarkedArticleIds(
        userId,
      );
      status = KnowledgeHubStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('KnowledgeHubController.loadArticles failed: $e');
      errorMessage =
          'Could not load your bookmarks. Check your connection and try again.';
      status = KnowledgeHubStatus.error;
      notifyListeners();
    }
  }

  void setFilter(KnowledgeCategory? category) {
    filter = category;
    notifyListeners();
  }

  Future<void> toggleBookmark({
    required String userId,
    required String articleId,
  }) async {
    final currentlyBookmarked = bookmarkedArticleIds.contains(articleId);
    try {
      await _bookmarkRepository.setBookmarked(
        userId: userId,
        articleId: articleId,
        bookmarked: !currentlyBookmarked,
      );
      if (currentlyBookmarked) {
        bookmarkedArticleIds.remove(articleId);
      } else {
        bookmarkedArticleIds.add(articleId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint(
        'KnowledgeHubController.toggleBookmark failed (non-fatal): $e',
      );
    }
  }
}

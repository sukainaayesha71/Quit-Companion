import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quit_companion/features/knowledge/data/article_bookmark_repository.dart';

/// Real Firestore implementation — nicotineUsers/{userId}/articleBookmarks/{articleId},
/// existence of the doc means "bookmarked" (same existence-as-boolean
/// pattern as Module 9's likes subcollection).
class FirestoreArticleBookmarkRepository implements ArticleBookmarkRepository {
  final FirebaseFirestore _firestore;

  FirestoreArticleBookmarkRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _bookmarksFor(String userId) =>
      _firestore
          .collection('nicotineUsers')
          .doc(userId)
          .collection('articleBookmarks');

  @override
  Future<Set<String>> getBookmarkedArticleIds(String userId) async {
    final snapshot = await _bookmarksFor(userId).get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  @override
  Future<void> setBookmarked({
    required String userId,
    required String articleId,
    required bool bookmarked,
  }) async {
    final doc = _bookmarksFor(userId).doc(articleId);
    if (bookmarked) {
      await doc.set({'bookmarkedAt': DateTime.now().toIso8601String()});
    } else {
      await doc.delete();
    }
  }
}

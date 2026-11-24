import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quit_companion/features/rewards/models/badge.dart' as models;
import 'package:quit_companion/features/rewards/data/badge_repository.dart';

/// Real Firestore implementation (Module 8), mirrors every other module's
/// per-user-subcollection pattern:
/// nicotineUsers/{userId}/badges/{badgeId}.
class FirestoreBadgeRepository implements BadgeRepository {
  final FirebaseFirestore _firestore;

  FirestoreBadgeRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _badgesFor(String userId) =>
      _firestore.collection('nicotineUsers').doc(userId).collection('badges');

  @override
  Future<void> saveBadge(models.Badge badge) async {
    await _badgesFor(badge.userId).doc(badge.badgeId).set({
      'badgeType': badge.badgeType.name,
      'dateEarned': badge.dateEarned.toIso8601String(),
    });
  }

  @override
  Future<List<models.Badge>> getBadges(String userId) async {
    final snapshot = await _badgesFor(userId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return models.Badge(
        badgeId: doc.id,
        userId: userId,
        badgeType: models.BadgeType.values.firstWhere(
          (t) => t.name == data['badgeType'],
        ),
        dateEarned: DateTime.parse(data['dateEarned'] as String),
      );
    }).toList();
  }
}

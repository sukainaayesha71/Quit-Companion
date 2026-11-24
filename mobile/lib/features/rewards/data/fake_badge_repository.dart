import 'package:quit_companion/features/rewards/models/badge.dart' as models;
import 'package:quit_companion/features/rewards/data/badge_repository.dart';

class FakeBadgeRepository implements BadgeRepository {
  final List<models.Badge> _badges = [];
  Object? failWith;

  @override
  Future<void> saveBadge(models.Badge badge) async {
    if (failWith != null) throw failWith!;
    _badges.add(badge);
  }

  @override
  Future<List<models.Badge>> getBadges(String userId) async {
    return _badges.where((b) => b.userId == userId).toList();
  }
}

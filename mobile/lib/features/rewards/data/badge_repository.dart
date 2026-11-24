import 'package:quit_companion/features/rewards/models/badge.dart' as models;

/// Badge persistence (SDD §6, Module 8 — Gamification & Rewards, FR9).
abstract class BadgeRepository {
  Future<void> saveBadge(models.Badge badge);

  Future<List<models.Badge>> getBadges(String userId);
}

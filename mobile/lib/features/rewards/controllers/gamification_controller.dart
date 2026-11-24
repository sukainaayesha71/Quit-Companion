import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/rewards/data/badge_repository.dart';
import 'package:quit_companion/features/reminders/data/notification_event_client.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/rewards/domain/badge_checker.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/tracking/domain/engagement_streak_calculator.dart';
import 'package:quit_companion/features/rewards/models/badge.dart' as models;

enum GamificationStatus { idle, loading, loaded, error }

/// FR9 (Module 8 — Gamification & Rewards): checks/awards newly-earned
/// badges (SDD §7.3 Check_Milestones) and exposes the phase-appropriate
/// streak for display. Nicotine-free days and the Reduction Streak are
/// consumed from DashboardStateCalculator rather than recomputed here.
class GamificationController extends ChangeNotifier {
  final UserRepository _userRepository;
  final UsageLogRepository _usageLogRepository;
  final CravingLogRepository _cravingLogRepository;
  final BadgeRepository _badgeRepository;
  final NotificationEventClient _notificationEventClient;
  final DashboardStateCalculator _dashboardStateCalculator;
  final DateTime Function() now;

  GamificationController(
    this._userRepository,
    this._usageLogRepository,
    this._cravingLogRepository,
    this._badgeRepository,
    this._dashboardStateCalculator, {
    NotificationEventClient? notificationEventClient,
    DateTime Function()? now,
  }) : _notificationEventClient =
           notificationEventClient ?? const NoopNotificationEventClient(),
       now = now ?? DateTime.now;

  GamificationStatus status = GamificationStatus.idle;
  String? errorMessage;
  bool isNicotineFreePhase = false;
  List<models.Badge> earnedBadges = [];
  List<models.BadgeType> newlyEarnedBadgeTypes = [];
  int? nicotineFreeStreak;
  int? reductionStreak;
  int engagementStreak = 0;
  int get totalPoints => earnedBadges
      .map((b) => b.badgeType)
      .toSet()
      .fold(0, (sum, type) => sum + type.points);

  List<models.Badge> get rewardsHistory => [...earnedBadges]
    ..sort((first, second) => second.dateEarned.compareTo(first.dateEarned));

  // FR9 / UC7 "Congratulatory Pop-up": badges awarded during this app
  // session wait here until a screen (Dashboard or Rewards) shows them.
  // `newlyEarnedBadgeTypes` cannot drive the dialog on its own because the
  // next loadRewards — e.g. opening Rewards right after the Dashboard
  // awarded a badge — resets it to []. Each badge type is queued at most
  // once per user per session, so concurrent loads or reopening a screen
  // can never replay a celebration.
  final List<models.Badge> _pendingCelebrations = [];
  final Set<models.BadgeType> _queuedCelebrationTypes = {};
  String? _celebrationUserId;

  /// Badges earned but not yet celebrated, oldest first.
  List<models.Badge> get pendingCelebrations =>
      List.unmodifiable(_pendingCelebrations);

  bool get hasPendingCelebration => _pendingCelebrations.isNotEmpty;

  /// Removes and returns the next badge to celebrate, or null if none. Once
  /// taken, a badge is never offered again — that's what makes the pop-up
  /// one-time even with Dashboard and Rewards both listening.
  models.Badge? takeNextCelebration() {
    if (_pendingCelebrations.isEmpty) return null;
    return _pendingCelebrations.removeAt(0);
  }

  /// Removes and returns every badge waiting to be celebrated, oldest
  /// first. Badges earned together (e.g. several tiers reached at once
  /// after time away) are celebrated in ONE dialog rather than a chain of
  /// modals that block the screen.
  List<models.Badge> takeAllCelebrations() {
    final all = List<models.Badge>.of(_pendingCelebrations);
    _pendingCelebrations.clear();
    return all;
  }

  /// Logout / account deletion: drop everything tied to the signed-out
  /// account so the next account on this device never sees its badges.
  void clearSession() {
    _pendingCelebrations.clear();
    _queuedCelebrationTypes.clear();
    _celebrationUserId = null;
    earnedBadges = [];
    newlyEarnedBadgeTypes = [];
    status = GamificationStatus.idle;
    notifyListeners();
  }

  void _resetCelebrationsIfUserChanged(String userId) {
    if (_celebrationUserId == userId) return;
    _celebrationUserId = userId;
    _pendingCelebrations.clear();
    _queuedCelebrationTypes.clear();
  }

  void _queueCelebration(models.Badge badge) {
    if (_queuedCelebrationTypes.add(badge.badgeType)) {
      _pendingCelebrations.add(badge);
    }
  }

  Future<void> loadRewards(String userId) async {
    _resetCelebrationsIfUserChanged(userId);
    status = GamificationStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final user = await _userRepository.getUser(userId);
      if (user == null) {
        throw StateError('No NicotineUser found for $userId.');
      }
      final usageLogs = await _usageLogRepository.getUsageLogs(userId);
      final cravingLogs = await _cravingLogRepository.getRecentLogs(
        userId,
        DateTime(2000),
      );
      final existingBadges = await _badgeRepository.getBadges(userId);

      engagementStreak = computeEngagementStreak(
        activityDates: [
          for (final log in usageLogs) log.date,
          for (final log in cravingLogs) log.timestamp,
        ],
        today: now(),
      );

      final state = _dashboardStateCalculator.calculate(
        user: user,
        usageLogs: usageLogs,
        cravingsResisted: 0,
      );
      if (state is CountdownState) {
        isNicotineFreePhase = false;
        nicotineFreeStreak = null;
        reductionStreak = state.reductionStreak;
        earnedBadges = existingBadges;
        newlyEarnedBadgeTypes = [];
      } else if (state is NicotineFreeState) {
        isNicotineFreePhase = true;
        nicotineFreeStreak = state.nicotineFreeDays;
        reductionStreak = null;
        final existingTypes = existingBadges.map((b) => b.badgeType).toSet();
        final newly = checkNewlyEarnedBadges(
          nicotineFreeDays: state.nicotineFreeDays,
          alreadyEarned: existingTypes,
        );
        for (final type in newly) {
          final badge = models.Badge(
            badgeId: '${userId}_${type.name}',
            userId: userId,
            badgeType: type,
            dateEarned: now(),
          );
          await _badgeRepository.saveBadge(badge);
          existingBadges.add(badge);
          // Queued only after a successful save, so a failed write never
          // celebrates a badge the user doesn't actually have.
          _queueCelebration(badge);
        }
        if (newly.isNotEmpty) {
          try {
            await _notificationEventClient.send(
              NotificationEventType.badgeEarned,
            );
          } catch (e) {
            debugPrint('Could not send badge-earned notification: $e');
          }
        }
        earnedBadges = existingBadges;
        newlyEarnedBadgeTypes = newly;
      }
      status = GamificationStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('GamificationController.loadRewards failed: $e');
      errorMessage =
          'Could not load your rewards. Check your connection and try again.';
      status = GamificationStatus.error;
      notifyListeners();
    }
  }
}

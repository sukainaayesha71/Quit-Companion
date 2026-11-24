import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/journal/data/journal_repository.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/tracking/domain/longest_streak_calculator.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/data/habit_alternative_attempt_repository.dart';

enum TrackStatus { idle, loading, loaded, error }

class TrackActivityItem {
  final DateTime date;
  final String title;
  final String subtitle;
  final bool isRelapse;

  const TrackActivityItem({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.isRelapse,
  });
}

class TrackMonthlySummary {
  final DateTime month;
  final int cravingCount;
  final int relapseCount;

  const TrackMonthlySummary({
    required this.month,
    required this.cravingCount,
    required this.relapseCount,
  });
}

class TrackRiskHistoryItem {
  final DateTime date;
  final TriggerCategory triggerCategory;
  final RelapseRiskLevel riskLevel;
  final bool pending;

  const TrackRiskHistoryItem({
    required this.date,
    required this.triggerCategory,
    required this.riskLevel,
    this.pending = false,
  });
}

/// Aggregates Track screen stats from data Modules 3/5 already persist —
/// no new Firestore collection, no fabricated metrics. See
/// docs/superpowers/specs/2026-09-02-track-profile-nav-design.md §3.
class TrackController extends ChangeNotifier {
  final CravingLogRepository _cravingLogRepository;
  final JournalRepository _journalRepository;
  final UserRepository _userRepository;
  final DateTime Function() now;
  final HabitAlternativeAttemptRepository? _attemptRepository;

  TrackController(
    this._cravingLogRepository,
    this._journalRepository,
    this._userRepository, {
    DateTime Function()? now,
    HabitAlternativeAttemptRepository? attemptRepository,
  }) : now = now ?? DateTime.now,
       _attemptRepository = attemptRepository;

  TrackStatus status = TrackStatus.idle;
  String? errorMessage;
  int totalCravingsLogged = 0;
  int cravingsResisted = 0;
  double? resistedPercent;
  int longestStreakDays = 0;
  Map<TriggerCategory, int> triggerBreakdown = {};
  List<TrackActivityItem> recentActivity = [];
  List<TrackMonthlySummary> monthlySummaries = [];
  List<TrackRiskHistoryItem> riskHistory = [];
  List<CravingLog> cravingHistory = [];

  /// UC3: ids of craving logs saved on this device but not yet confirmed by
  /// the server (empty when the repository doesn't queue offline writes).
  Set<String> pendingSyncLogIds = {};
  int habitAttempts = 0;
  int completedHabitAttempts = 0;
  int helpfulHabitAttempts = 0;
  String? habitErrorMessage;

  Future<bool> deleteCraving(CravingLog log) async {
    try {
      await _cravingLogRepository.deleteLog(
        userId: log.userId,
        logId: log.logId,
      );
      await loadTrack(log.userId);
      return status == TrackStatus.loaded;
    } catch (_) {
      errorMessage = 'Could not delete this craving. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadTrack(String userId) async {
    status = TrackStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final user = await _userRepository.getUser(userId);
      if (user == null || user.quitDate == null) {
        errorMessage = 'Your quit plan is not set up yet.';
        status = TrackStatus.error;
        notifyListeners();
        return;
      }
      final quitDate = user.quitDate!;
      // All-time lower bound: cravings/relapses logged before the quit date
      // (e.g. during a Countdown-phase taper) are real user data and must
      // still surface in totals/breakdown/activity — quitDate is only the
      // anchor for the longest-streak calculation below, not a data cutoff.
      final allTime = DateTime.fromMillisecondsSinceEpoch(0);
      final cravingLogs = await _cravingLogRepository.getRecentLogs(
        userId,
        allTime,
      );
      cravingHistory = [...cravingLogs]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final syncSource = _cravingLogRepository;
      pendingSyncLogIds = syncSource is SyncStatusCravingLogRepository
          ? await (syncSource as SyncStatusCravingLogRepository)
                .pendingSyncLogIds(userId)
          : <String>{};
      habitAttempts = completedHabitAttempts = helpfulHabitAttempts = 0;
      habitErrorMessage = null;
      if (_attemptRepository != null) {
        try {
          final attempts = await _attemptRepository.getAttempts(userId);
          habitAttempts = attempts.length;
          completedHabitAttempts = attempts
              .where((a) => a.outcomeHelped != null)
              .length;
          helpfulHabitAttempts = attempts
              .where((a) => a.outcomeHelped == true)
              .length;
        } catch (_) {
          habitErrorMessage =
              'Habit statistics are unavailable. Please refresh to retry.';
        }
      }
      final resisted = await _cravingLogRepository.countCravingsResistedSince(
        userId,
        allTime,
      );
      final journalEntries = await _journalRepository.getEntries(userId);
      final relapses = journalEntries.where((e) => e.relapseFlag).toList();

      totalCravingsLogged = cravingLogs.length;
      cravingsResisted = resisted;
      final universe = resisted + relapses.length;
      resistedPercent = universe == 0 ? null : resisted / universe;

      final today = now();
      if (today.isBefore(quitDate)) {
        // Still in the Countdown phase — the user hasn't reached their quit
        // day yet, so there's no smoke-free streak to report. Reporting
        // computeLongestStreakDays's quitDate-vs-today gap here would just
        // be daysUntilQuit mislabeled as a streak.
        longestStreakDays = 0;
      } else {
        final postQuitRelapseDates = [
          for (final r in relapses)
            if (!r.entryDate.isBefore(quitDate)) r.entryDate,
        ];
        longestStreakDays = computeLongestStreakDays(
          quitDate: quitDate,
          relapseDates: postQuitRelapseDates,
          today: today,
        );
      }

      triggerBreakdown = {for (final t in TriggerCategory.values) t: 0};
      for (final log in cravingLogs) {
        triggerBreakdown[log.triggerCategory] =
            (triggerBreakdown[log.triggerCategory] ?? 0) + 1;
      }

      final activity = <TrackActivityItem>[
        for (final log in cravingLogs)
          TrackActivityItem(
            date: log.timestamp,
            title: 'Craving logged',
            subtitle: log.triggerCategory.label,
            isRelapse: false,
          ),
        for (final r in relapses)
          TrackActivityItem(
            date: r.entryDate,
            title: 'Relapse logged',
            subtitle: r.triggerCategory != null
                ? r.triggerCategory!.label
                : 'No trigger noted',
            isRelapse: true,
          ),
      ]..sort((a, b) => b.date.compareTo(a.date));
      recentActivity = activity.take(10).toList();

      final monthlyCounts = <DateTime, ({int cravings, int relapses})>{};
      for (final log in cravingLogs) {
        final month = DateTime(log.timestamp.year, log.timestamp.month);
        final counts = monthlyCounts[month] ?? (cravings: 0, relapses: 0);
        monthlyCounts[month] = (
          cravings: counts.cravings + 1,
          relapses: counts.relapses,
        );
      }
      for (final relapse in relapses) {
        final month = DateTime(relapse.entryDate.year, relapse.entryDate.month);
        final counts = monthlyCounts[month] ?? (cravings: 0, relapses: 0);
        monthlyCounts[month] = (
          cravings: counts.cravings,
          relapses: counts.relapses + 1,
        );
      }
      monthlySummaries = [
        for (final entry in monthlyCounts.entries)
          TrackMonthlySummary(
            month: entry.key,
            cravingCount: entry.value.cravings,
            relapseCount: entry.value.relapses,
          ),
      ]..sort((a, b) => b.month.compareTo(a.month));

      riskHistory = [
        for (final log in cravingLogs)
          TrackRiskHistoryItem(
            date: log.timestamp,
            triggerCategory: log.triggerCategory,
            riskLevel: log.relapseRiskScore,
            pending: log.riskAssessmentPending,
          ),
      ]..sort((a, b) => b.date.compareTo(a.date));

      status = TrackStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('TrackController.loadTrack failed: $e');
      errorMessage =
          'Could not load your progress. Check your connection and try again.';
      status = TrackStatus.error;
      notifyListeners();
    }
  }
}

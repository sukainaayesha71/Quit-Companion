import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/dashboard/domain/health_recovery_milestones.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';

/// Result of SDD §7.2 Get_Dashboard_State — either phase, never both.
sealed class DashboardState {}

/// Before quitDate. Reduction-related fields are non-null only for GRADUAL
/// (SDD §7.2: DATE_BASED shows only DaysUntilQuit — "no usage-reduction
/// data to show").
class CountdownState extends DashboardState {
  final int daysUntilQuit;
  final double? todayTarget;
  final int? reductionStreak;
  final double? moneySavedSoFar;
  final DateTime plannedQuitDate;
  final List<HealthRecoveryMilestone> healthRecoveryTimeline;

  CountdownState({
    required this.daysUntilQuit,
    required this.plannedQuitDate,
    required this.healthRecoveryTimeline,
    this.todayTarget,
    this.reductionStreak,
    this.moneySavedSoFar,
  });

  /// The three reduction fields are only ever set together (GRADUAL only,
  /// SDD §7.2) — checking one is a reliable, self-documenting proxy.
  bool get isGradual => reductionStreak != null;
}

/// From quitDate onward (EffectiveStart accounts for a later relapse).
/// Recovery milestones come only from the fixed, cited Knowledge Hub
/// articles. Smoking-specific claims are included only for cigarette users.
class NicotineFreeState extends DashboardState {
  final int nicotineFreeDays;
  final double moneySaved;
  final int cravingsResisted;
  final DateTime recoveryStartDate;
  final List<HealthRecoveryMilestone> healthRecoveryTimeline;

  NicotineFreeState({
    required this.nicotineFreeDays,
    required this.moneySaved,
    required this.cravingsResisted,
    required this.recoveryStartDate,
    required this.healthRecoveryTimeline,
  });
}

/// Pure implementation of SDD §7.2 Get_Dashboard_State. No I/O — callers
/// (DashboardController) fetch the NicotineUser/UsageLogs/cravings count
/// and pass them in, mirroring QuitDateCalculator's testable style.
class DashboardStateCalculator {
  final DateTime Function() now;

  DashboardStateCalculator({DateTime Function()? now})
    : now = now ?? DateTime.now;

  DashboardState calculate({
    required NicotineUser user,
    required List<UsageLog> usageLogs,
    required int cravingsResisted,
  }) {
    final quitDate = user.quitDate;
    if (quitDate == null) {
      throw StateError(
        'Cannot compute dashboard state before quitDate is set (SDD FR3).',
      );
    }
    final today = _dateOnly(now());
    final quitDay = _dateOnly(quitDate);

    if (today.isBefore(quitDay)) {
      return _countdownState(user, usageLogs, today, quitDay);
    }
    return _nicotineFreeState(user, today, quitDay, cravingsResisted);
  }

  CountdownState _countdownState(
    NicotineUser user,
    List<UsageLog> usageLogs,
    DateTime today,
    DateTime quitDay,
  ) {
    final daysUntilQuit = quitDay.difference(today).inDays;
    if (user.quitStrategy != QuitStrategy.gradual) {
      return CountdownState(
        daysUntilQuit: daysUntilQuit,
        plannedQuitDate: quitDay,
        healthRecoveryTimeline: healthRecoveryMilestonesFor(user.productType),
      );
    }

    final schedule = user.reductionSchedule ?? const {};
    final todayTarget = schedule[today];
    final baselineDailyUsage = user.baselineDailyUsage ?? 0;
    final costPerUnit = user.costPerUnit ?? 0;

    return CountdownState(
      daysUntilQuit: daysUntilQuit,
      plannedQuitDate: quitDay,
      healthRecoveryTimeline: healthRecoveryMilestonesFor(user.productType),
      todayTarget: todayTarget,
      reductionStreak: _computeReductionStreak(usageLogs),
      moneySavedSoFar: _computeMoneySavedSoFar(
        usageLogs,
        baselineDailyUsage,
        costPerUnit,
      ),
    );
  }

  NicotineFreeState _nicotineFreeState(
    NicotineUser user,
    DateTime today,
    DateTime quitDay,
    int cravingsResisted,
  ) {
    final lastRelapseDate = user.lastRelapseDate != null
        ? _dateOnly(user.lastRelapseDate!)
        : null;
    final effectiveStart =
        (lastRelapseDate != null && lastRelapseDate.isAfter(quitDay))
        ? lastRelapseDate
        : quitDay;
    final nicotineFreeDays = today.difference(effectiveStart).inDays;
    final baselineDailyUsage = user.baselineDailyUsage ?? 0;
    final costPerUnit = user.costPerUnit ?? 0;

    return NicotineFreeState(
      nicotineFreeDays: nicotineFreeDays,
      moneySaved: nicotineFreeDays * baselineDailyUsage * costPerUnit,
      cravingsResisted: cravingsResisted,
      recoveryStartDate: effectiveStart,
      healthRecoveryTimeline: healthRecoveryMilestonesFor(user.productType),
    );
  }

  /// FR10: consecutive days (counting back from the most recently logged
  /// day) where actualUsage <= that day's targetUsage. A missing day (no
  /// log) or an over-target day both break the streak.
  int _computeReductionStreak(List<UsageLog> usageLogs) {
    final byDate = {for (final log in usageLogs) _dateOnly(log.date): log};
    if (byDate.isEmpty) return 0;

    final mostRecentDate = byDate.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    var streak = 0;
    var cursor = mostRecentDate;
    while (true) {
      final log = byDate[cursor];
      if (log == null || log.actualUsage > log.targetUsage) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// FR16 Countdown-phase formula: SUM (baselineDailyUsage - actualDailyUsage) * costPerUnit.
  double _computeMoneySavedSoFar(
    List<UsageLog> usageLogs,
    double baselineDailyUsage,
    double costPerUnit,
  ) {
    var total = 0.0;
    for (final log in usageLogs) {
      total += (baselineDailyUsage - log.actualUsage) * costPerUnit;
    }
    return total;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';

/// FR11 / SRDS UC9 alternative flow: "high-risk behaviour pattern detected
/// → gentle check-in". The SRDS never specifies the detection rule, so this
/// reuses rules that already exist in the project rather than inventing one:
///
/// - **High risk** is the existing FR5 relapse-risk prediction stored on
///   each craving log (`relapseRiskScore == high`). Logs whose assessment is
///   still pending (offline) don't count — their score is a placeholder.
/// - **Pattern** is WeeklyPlanCalculator's existing rule: two or more
///   high-risk cravings within the last 7 days.
///
/// Pure: no I/O, no clock. HighRiskCheckInScheduler gathers the inputs.
enum CheckInSkipReason {
  notHighRisk,
  noPattern,
  recentRelapse,
  remindersOff,
  noPermission,
  alreadyHandled,
  cooldown,
}

class CheckInDecision {
  final DateTime? scheduleAt;
  final CheckInSkipReason? skipReason;

  const CheckInDecision.schedule(DateTime at)
    : scheduleAt = at,
      skipReason = null;
  const CheckInDecision.skip(CheckInSkipReason reason)
    : scheduleAt = null,
      skipReason = reason;

  bool get shouldSchedule => scheduleAt != null;

  @override
  String toString() =>
      shouldSchedule ? 'schedule($scheduleAt)' : 'skip(${skipReason!.name})';
}

class HighRiskCheckInPolicy {
  /// Same threshold and window as WeeklyPlanCalculator's "a few intense
  /// cravings this week" goal (lib/features/goals/domain/weekly_plan_calculator.dart).
  static const patternMinHighRiskLogs = 2;
  static const patternWindow = Duration(days: 7);

  /// The check-in comes a little after the craving: the moment itself is
  /// already handled in-app (HighRiskScreen alternatives).
  static const checkInDelay = Duration(hours: 2);

  /// At most one check-in per day, whatever triggered it.
  static const cooldown = Duration(hours: 24);

  /// A check-in falling between [quietStartHour] and [quietEndHour] is moved
  /// to [quietEndHour]:00 the next morning rather than waking the user.
  static const quietStartHour = 22;
  static const quietEndHour = 9;

  const HighRiskCheckInPolicy();

  CheckInDecision decide({
    required CravingLog savedLog,
    required List<CravingLog> recentLogs,
    required DateTime now,
    required bool remindersEnabled,
    required bool permissionGranted,
    DateTime? lastRelapseDate,
    DateTime? lastCheckInScheduledAt,
    String? lastTriggerLogId,
  }) {
    if (!_isHighRisk(savedLog)) {
      return const CheckInDecision.skip(CheckInSkipReason.notHighRisk);
    }

    final since = now.subtract(patternWindow);
    final highRiskIds = <String>{
      for (final log in [...recentLogs, savedLog])
        if (_isHighRisk(log) && !log.timestamp.isBefore(since)) log.logId,
    };
    if (highRiskIds.length < patternMinHighRiskLogs) {
      return const CheckInDecision.skip(CheckInSkipReason.noPattern);
    }

    // A confirmed relapse (Relapse Log, which sets lastRelapseDate = today)
    // today or yesterday means the user is already in the restart-plan flow;
    // a "how are you holding up" nudge would read as tone-deaf.
    if (lastRelapseDate != null) {
      final today = DateTime(now.year, now.month, now.day);
      final relapseDay = DateTime(
        lastRelapseDate.year,
        lastRelapseDate.month,
        lastRelapseDate.day,
      );
      if (!relapseDay.isBefore(today.subtract(const Duration(days: 1)))) {
        return const CheckInDecision.skip(CheckInSkipReason.recentRelapse);
      }
    }

    if (!remindersEnabled) {
      return const CheckInDecision.skip(CheckInSkipReason.remindersOff);
    }
    if (!permissionGranted) {
      return const CheckInDecision.skip(CheckInSkipReason.noPermission);
    }

    if (lastTriggerLogId == savedLog.logId) {
      return const CheckInDecision.skip(CheckInSkipReason.alreadyHandled);
    }
    if (lastCheckInScheduledAt != null &&
        now.difference(lastCheckInScheduledAt) < cooldown) {
      return const CheckInDecision.skip(CheckInSkipReason.cooldown);
    }

    return CheckInDecision.schedule(_checkInTime(now));
  }

  bool _isHighRisk(CravingLog log) =>
      log.relapseRiskScore == RelapseRiskLevel.high &&
      !log.riskAssessmentPending;

  DateTime _checkInTime(DateTime now) {
    final at = now.add(checkInDelay);
    if (at.hour >= quietStartHour) {
      return DateTime(at.year, at.month, at.day + 1, quietEndHour);
    }
    if (at.hour < quietEndHour) {
      return DateTime(at.year, at.month, at.day, quietEndHour);
    }
    return at;
  }
}

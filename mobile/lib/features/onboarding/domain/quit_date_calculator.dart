import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';

/// Implements SDD §7.1 Determine_Quit_Date and the linear-taper
/// reductionSchedule described in SDD §6 (GRADUAL only).
class QuitDateCalculator {
  final DateTime Function() now;

  QuitDateCalculator({DateTime Function()? now}) : now = now ?? DateTime.now;

  ({DateTime quitDate, Map<DateTime, double>? reductionSchedule})
  determineQuitDate({
    required QuitStrategy quitStrategy,
    required double baselineDailyUsage,
    DateTime? selectedTargetDate,
  }) {
    final today = _dateOnly(now());
    switch (quitStrategy) {
      case QuitStrategy.coldTurkey:
        return (quitDate: today, reductionSchedule: null);
      case QuitStrategy.dateBased:
        final target = _requireFutureTargetDate(selectedTargetDate, today);
        return (quitDate: target, reductionSchedule: null);
      case QuitStrategy.gradual:
        final target = _requireFutureTargetDate(selectedTargetDate, today);
        final schedule = _buildLinearTaper(baselineDailyUsage, today, target);
        return (quitDate: target, reductionSchedule: schedule);
    }
  }

  DateTime _requireFutureTargetDate(
    DateTime? selectedTargetDate,
    DateTime today,
  ) {
    if (selectedTargetDate == null) {
      throw ArgumentError(
        'selectedTargetDate is required for this quit strategy — no default duration exists (SDD FR3).',
      );
    }
    final target = _dateOnly(selectedTargetDate);
    if (!target.isAfter(today)) {
      throw ArgumentError('selectedTargetDate must be after today.');
    }
    return target;
  }

  Map<DateTime, double> _buildLinearTaper(
    double baselineDailyUsage,
    DateTime today,
    DateTime quitDate,
  ) {
    final totalDays = quitDate.difference(today).inDays;
    final schedule = <DateTime, double>{};
    for (var d = 0; d <= totalDays; d++) {
      final date = today.add(Duration(days: d));
      schedule[date] = baselineDailyUsage * (totalDays - d) / totalDays;
    }
    return schedule;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

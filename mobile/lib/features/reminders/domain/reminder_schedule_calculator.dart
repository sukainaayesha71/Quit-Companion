/// A single daily reminder time (device-local wall-clock time, no date/
/// timezone attached — the scheduling layer repeats it every day). Kept
/// as a tiny pure-Dart value type rather than `TimeOfDay` so this file
/// has no Flutter/material dependency, matching every other domain
/// calculator in this codebase (DashboardStateCalculator, etc.).
class ReminderTime {
  final int hour;
  final int minute;

  const ReminderTime({required this.hour, required this.minute});

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

const _windowStartMinutes = 9 * 60; // 09:00
const _windowEndMinutes = 21 * 60; // 21:00

/// FR14 (SRDS FR13): "3 to 5 daily EMA prompts." Neither document
/// specifies actual times, only the count — this deterministically
/// spaces [dailyFrequency] reminders across a fixed 09:00-21:00
/// waking-hours window (a reasonable, documented default; not
/// user-configurable per-reminder, since the spec only asks for a count,
/// not scheduling granularity — see the Module 11 implementation record
/// Step 4 for the full reasoning). Each reminder sits at the midpoint of
/// an equal-width slice of the window, so reminders are spread evenly
/// rather than clustered at either end.
List<ReminderTime> computeReminderTimes(int dailyFrequency) {
  if (dailyFrequency < 3 || dailyFrequency > 5) {
    throw ArgumentError.value(
      dailyFrequency,
      'dailyFrequency',
      'must be between 3 and 5 (SRDS FR13)',
    );
  }
  final windowMinutes = _windowEndMinutes - _windowStartMinutes;
  final sliceSize = windowMinutes / dailyFrequency;
  return [
    for (var i = 0; i < dailyFrequency; i++)
      _fromMinutes(_windowStartMinutes + (sliceSize * (i + 0.5)).round()),
  ];
}

ReminderTime _fromMinutes(int totalMinutes) {
  return ReminderTime(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
}

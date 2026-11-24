import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/reminders/domain/reminder_schedule_calculator.dart';

void main() {
  group('computeReminderTimes', () {
    test('returns exactly dailyFrequency times', () {
      expect(computeReminderTimes(3), hasLength(3));
      expect(computeReminderTimes(4), hasLength(4));
      expect(computeReminderTimes(5), hasLength(5));
    });

    test('every time falls within the 09:00-21:00 waking-hours window', () {
      for (final frequency in [3, 4, 5]) {
        for (final time in computeReminderTimes(frequency)) {
          final minutesSinceMidnight = time.hour * 60 + time.minute;
          expect(minutesSinceMidnight, greaterThanOrEqualTo(9 * 60));
          expect(minutesSinceMidnight, lessThanOrEqualTo(21 * 60));
        }
      }
    });

    test('times are strictly increasing and evenly spaced', () {
      final times = computeReminderTimes(4);
      final minutes = times.map((t) => t.hour * 60 + t.minute).toList();

      for (var i = 1; i < minutes.length; i++) {
        expect(minutes[i], greaterThan(minutes[i - 1]));
      }
      final gap = minutes[1] - minutes[0];
      for (var i = 1; i < minutes.length; i++) {
        expect(minutes[i] - minutes[i - 1], gap);
      }
    });

    test('is deterministic for a given frequency', () {
      expect(computeReminderTimes(4), computeReminderTimes(4));
    });

    test('rejects a frequency outside the SRDS-specified 3-5 range', () {
      expect(() => computeReminderTimes(2), throwsArgumentError);
      expect(() => computeReminderTimes(6), throwsArgumentError);
    });
  });
}

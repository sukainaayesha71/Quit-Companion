import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/domain/longest_streak_calculator.dart';

void main() {
  test(
    'with no relapses, the streak is the full span from quitDate to today',
    () {
      final result = computeLongestStreakDays(
        quitDate: DateTime(2026, 8, 1),
        relapseDates: [],
        today: DateTime(2026, 8, 11),
      );
      expect(result, 10);
    },
  );

  test('takes the longest gap across multiple relapses', () {
    final result = computeLongestStreakDays(
      quitDate: DateTime(2026, 8, 1),
      relapseDates: [DateTime(2026, 8, 3), DateTime(2026, 8, 20)],
      today: DateTime(2026, 8, 25),
    );
    // Gaps: quitDate->relapse1 = 2, relapse1->relapse2 = 17, relapse2->today = 5.
    expect(result, 17);
  });

  test('unsorted relapse dates are handled correctly', () {
    final result = computeLongestStreakDays(
      quitDate: DateTime(2026, 8, 1),
      relapseDates: [DateTime(2026, 8, 20), DateTime(2026, 8, 3)],
      today: DateTime(2026, 8, 25),
    );
    expect(result, 17);
  });
}

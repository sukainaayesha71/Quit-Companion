import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/domain/engagement_streak_calculator.dart';

void main() {
  group('computeEngagementStreak', () {
    test('returns 0 with no activity at all', () {
      expect(
        computeEngagementStreak(
          activityDates: [],
          today: DateTime(2026, 8, 19),
        ),
        0,
      );
    });

    test('counts consecutive days ending today', () {
      final activity = [
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 19),
      ];
      expect(
        computeEngagementStreak(
          activityDates: activity,
          today: DateTime(2026, 8, 19),
        ),
        3,
      );
    });

    test('a gap breaks the streak', () {
      final activity = [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 19),
      ];
      expect(
        computeEngagementStreak(
          activityDates: activity,
          today: DateTime(2026, 8, 19),
        ),
        2,
      );
    });

    test(
      'no activity yet today still counts yesterday\'s streak (grace period)',
      () {
        final activity = [DateTime(2026, 8, 17), DateTime(2026, 8, 18)];
        expect(
          computeEngagementStreak(
            activityDates: activity,
            today: DateTime(2026, 8, 19),
          ),
          2,
        );
      },
    );

    test('duplicate same-day entries only count once', () {
      final activity = [DateTime(2026, 8, 19, 9), DateTime(2026, 8, 19, 21)];
      expect(
        computeEngagementStreak(
          activityDates: activity,
          today: DateTime(2026, 8, 19),
        ),
        1,
      );
    });
  });
}

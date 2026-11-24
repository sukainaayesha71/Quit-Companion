import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/rewards/domain/badge_checker.dart';
import 'package:quit_companion/features/rewards/models/badge.dart' as models;

void main() {
  group('checkNewlyEarnedBadges', () {
    test('returns no badges before the first threshold is reached', () {
      expect(
        checkNewlyEarnedBadges(nicotineFreeDays: 0, alreadyEarned: {}),
        isEmpty,
      );
    });

    test('awards First Day Hero exactly at 1 day', () {
      final earned = checkNewlyEarnedBadges(
        nicotineFreeDays: 1,
        alreadyEarned: {},
      );
      expect(earned, [models.BadgeType.firstDayHero]);
    });

    test(
      'catch-up awards every threshold reached since the last check, not just an exact match',
      () {
        // A user who doesn't open the app on exactly day 7 must not silently
        // lose the '1 Week Warrior' badge — see this file's header comment.
        final earned = checkNewlyEarnedBadges(
          nicotineFreeDays: 10,
          alreadyEarned: {},
        );
        expect(earned, [
          models.BadgeType.firstDayHero,
          models.BadgeType.oneWeekWarrior,
        ]);
      },
    );

    test('never re-awards a badge already in alreadyEarned', () {
      final earned = checkNewlyEarnedBadges(
        nicotineFreeDays: 10,
        alreadyEarned: {models.BadgeType.firstDayHero},
      );
      expect(earned, [models.BadgeType.oneWeekWarrior]);
    });

    test('all six tiers awarded once nicotineFreeDays reaches 365', () {
      final earned = checkNewlyEarnedBadges(
        nicotineFreeDays: 400,
        alreadyEarned: {},
      );
      expect(earned, models.BadgeType.values);
    });

    test(
      'a negative nicotineFreeDays (should not happen, but defensively) awards nothing',
      () {
        expect(
          checkNewlyEarnedBadges(nicotineFreeDays: -1, alreadyEarned: {}),
          isEmpty,
        );
      },
    );
  });
}

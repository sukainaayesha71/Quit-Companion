import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

CravingLog _log({
  required String logId,
  required String userId,
  required DateTime timestamp,
  Mood mood = Mood.happy,
  TriggerCategory triggerCategory = TriggerCategory.other,
}) {
  return CravingLog(
    logId: logId,
    userId: userId,
    cravingIntensity: 3,
    mood: mood,
    triggerCategory: triggerCategory,
    locationContext: 'Home',
    activity: 'Home',
    timestamp: timestamp,
    relapseRiskScore: RelapseRiskLevel.low,
  );
}

void main() {
  test(
    'countCravingsResistedSince always returns 0 until any craving is logged',
    () async {
      final repo = FakeCravingLogRepository();

      expect(
        await repo.countCravingsResistedSince('user1', DateTime(2026, 8, 1)),
        0,
      );
    },
  );

  test(
    'logCraving makes the entry count toward countCravingsResistedSince from that point on',
    () async {
      final repo = FakeCravingLogRepository();
      await repo.logCraving(
        _log(logId: 'a', userId: 'user1', timestamp: DateTime(2026, 8, 10)),
      );

      expect(
        await repo.countCravingsResistedSince('user1', DateTime(2026, 8, 1)),
        1,
      );
      expect(
        await repo.countCravingsResistedSince('user1', DateTime(2026, 8, 15)),
        0,
      ); // logged before `since`
    },
  );

  test('countCravingsResistedSince only counts the requested userId', () async {
    final repo = FakeCravingLogRepository();
    await repo.logCraving(
      _log(logId: 'a', userId: 'user1', timestamp: DateTime(2026, 8, 10)),
    );
    await repo.logCraving(
      _log(logId: 'b', userId: 'user2', timestamp: DateTime(2026, 8, 10)),
    );

    expect(
      await repo.countCravingsResistedSince('user1', DateTime(2026, 8, 1)),
      1,
    );
  });

  test(
    'countLoggedSince counts logs at or after the given instant, for the 24h relapse-risk rule',
    () async {
      final repo = FakeCravingLogRepository();
      await repo.logCraving(
        _log(logId: 'a', userId: 'user1', timestamp: DateTime(2026, 8, 15, 10)),
      );
      await repo.logCraving(
        _log(logId: 'b', userId: 'user1', timestamp: DateTime(2026, 8, 15, 11)),
      );
      await repo.logCraving(
        _log(logId: 'c', userId: 'user1', timestamp: DateTime(2026, 8, 13)),
      ); // >24h earlier

      final since = DateTime(2026, 8, 14, 12); // 24h before 2026-08-15 12:00
      expect(await repo.countLoggedSince('user1', since), 2);
    },
  );

  test(
    'getRecentLogs returns full CravingLog records at/after `since`, for the requested user only, oldest first',
    () async {
      final repo = FakeCravingLogRepository();
      await repo.logCraving(
        _log(
          logId: 'later',
          userId: 'user1',
          timestamp: DateTime(2026, 8, 15),
          mood: Mood.stressed,
          triggerCategory: TriggerCategory.socialPressure,
        ),
      );
      await repo.logCraving(
        _log(
          logId: 'earlier',
          userId: 'user1',
          timestamp: DateTime(2026, 8, 13),
        ),
      );
      await repo.logCraving(
        _log(
          logId: 'too-old',
          userId: 'user1',
          timestamp: DateTime(2026, 8, 1),
        ),
      );
      await repo.logCraving(
        _log(
          logId: 'other-user',
          userId: 'user2',
          timestamp: DateTime(2026, 8, 14),
        ),
      );

      final logs = await repo.getRecentLogs('user1', DateTime(2026, 8, 10));

      expect(logs.map((l) => l.logId), ['earlier', 'later']);
      expect(logs.every((l) => l.userId == 'user1'), isTrue);
      expect(logs.last.mood, Mood.stressed);
      expect(logs.last.triggerCategory, TriggerCategory.socialPressure);
    },
  );

  test(
    'a CravingLog with no mood-slider values (pre-Open-Decision-6 record) logs and reads back with null fields',
    () async {
      final repo = FakeCravingLogRepository();
      // No moodHappy/.../moodBored args — simulates a record shaped like
      // anything logged before Open Decision 6 added these fields.
      await repo.logCraving(
        _log(
          logId: 'legacy',
          userId: 'user1',
          timestamp: DateTime(2026, 8, 10),
        ),
      );

      final logs = await repo.getRecentLogs('user1', DateTime(2026, 8, 1));

      expect(logs.single.moodHappy, isNull);
      expect(logs.single.moodExcited, isNull);
      expect(logs.single.moodBored, isNull);
    },
  );

  test(
    'a CravingLog with explicit mood-slider values (Open Decision 6) round-trips them unchanged',
    () async {
      final repo = FakeCravingLogRepository();
      final log = CravingLog(
        logId: 'with-mood',
        userId: 'user1',
        cravingIntensity: 6,
        mood: Mood.stressed,
        triggerCategory: TriggerCategory.stress,
        locationContext: 'Work',
        activity: 'Work',
        timestamp: DateTime(2026, 8, 15),
        relapseRiskScore: RelapseRiskLevel.medium,
        moodHappy: 2,
        moodExcited: 3,
        moodEnthusiastic: 4,
        moodContented: 1,
        moodCalm: 0,
        moodIrritable: 8,
        moodAnxious: 9,
        moodStressed: 9.5,
        moodSad: 6,
        moodBored: 1,
      );
      await repo.logCraving(log);

      final saved = (await repo.getRecentLogs(
        'user1',
        DateTime(2026, 8, 1),
      )).single;

      expect(saved.moodHappy, 2);
      expect(saved.moodAnxious, 9);
      expect(saved.moodStressed, 9.5);
      expect(saved.moodBored, 1);
    },
  );
}

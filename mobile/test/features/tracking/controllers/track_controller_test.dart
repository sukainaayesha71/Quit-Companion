import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  final fixedToday = DateTime(2026, 9, 2);

  CravingLog log(
    String id,
    DateTime ts,
    TriggerCategory trigger, {
    RelapseRiskLevel risk = RelapseRiskLevel.low,
  }) => CravingLog(
    logId: id,
    userId: 'u1',
    cravingIntensity: 5,
    mood: Mood.stressed,
    triggerCategory: trigger,
    locationContext: 'Home',
    activity: 'Home',
    timestamp: ts,
    relapseRiskScore: risk,
  );

  test(
    'aggregates cravings, resisted percent, streak, breakdown, and activity',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitDate: DateTime(2026, 8, 1),
        ),
      );

      final cravingLogRepository = FakeCravingLogRepository();
      await cravingLogRepository.logCraving(
        log('c1', DateTime(2026, 8, 5), TriggerCategory.stress),
      );
      await cravingLogRepository.logCraving(
        log('c2', DateTime(2026, 8, 6), TriggerCategory.stress),
      );
      await cravingLogRepository.logCraving(
        log(
          'c3',
          DateTime(2026, 8, 22),
          TriggerCategory.boredom,
          risk: RelapseRiskLevel.high,
        ),
      );
      await cravingLogRepository.logCraving(
        log(
          'c4',
          DateTime(2026, 9, 1),
          TriggerCategory.socialPressure,
          risk: RelapseRiskLevel.medium,
        ),
      );

      final journalRepository = FakeJournalRepository();
      await journalRepository.saveEntry(
        JournalEntry(
          entryId: 'r1',
          userId: 'u1',
          entryDate: DateTime(2026, 8, 10),
          relapseFlag: true,
          triggerCategory: TriggerCategory.socialPressure,
        ),
      );

      final controller = TrackController(
        cravingLogRepository,
        journalRepository,
        userRepository,
        now: () => fixedToday,
      );
      await controller.loadTrack('u1');

      expect(controller.status, TrackStatus.loaded);
      expect(controller.totalCravingsLogged, 4);
      expect(controller.cravingsResisted, 4);
      expect(
        controller.resistedPercent,
        closeTo(0.8, 0.001),
      ); // 4 resisted / (4 resisted + 1 relapse)
      expect(controller.longestStreakDays, 23);
      expect(controller.triggerBreakdown[TriggerCategory.stress], 2);
      expect(controller.triggerBreakdown[TriggerCategory.boredom], 1);
      expect(
        controller.recentActivity.first.isRelapse,
        isFalse,
      ); // c4 (9/1) is the newest event
      expect(controller.monthlySummaries, hasLength(2));
      expect(controller.monthlySummaries.first.month, DateTime(2026, 9));
      expect(controller.monthlySummaries.first.cravingCount, 1);
      expect(controller.monthlySummaries.first.relapseCount, 0);
      expect(controller.monthlySummaries.last.month, DateTime(2026, 8));
      expect(controller.monthlySummaries.last.cravingCount, 3);
      expect(controller.monthlySummaries.last.relapseCount, 1);
      expect(controller.riskHistory.map((item) => item.riskLevel), [
        RelapseRiskLevel.medium,
        RelapseRiskLevel.high,
        RelapseRiskLevel.low,
        RelapseRiskLevel.low,
      ]);
    },
  );

  test(
    'resistedPercent is null with no craving or relapse data at all',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitDate: DateTime(2026, 8, 1),
        ),
      );
      final controller = TrackController(
        FakeCravingLogRepository(),
        FakeJournalRepository(),
        userRepository,
        now: () => fixedToday,
      );

      await controller.loadTrack('u1');

      expect(controller.resistedPercent, isNull);
      expect(controller.totalCravingsLogged, 0);
      expect(controller.monthlySummaries, isEmpty);
      expect(controller.riskHistory, isEmpty);
    },
  );

  test('Countdown-phase user (quitDate in the future) sees real pre-quit-date '
      'logs and no fabricated streak', () async {
    final userRepository = FakeUserRepository();
    // quitDate is AFTER fixedToday — this user hasn't quit yet.
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitDate: DateTime(2026, 10, 1),
      ),
    );

    final cravingLogRepository = FakeCravingLogRepository();
    // Logged during the taper, before both "today" and the future quitDate.
    await cravingLogRepository.logCraving(
      log('c1', DateTime(2026, 8, 20), TriggerCategory.stress),
    );
    await cravingLogRepository.logCraving(
      log('c2', DateTime(2026, 8, 25), TriggerCategory.boredom),
    );

    final controller = TrackController(
      cravingLogRepository,
      FakeJournalRepository(),
      userRepository,
      now: () => fixedToday,
    );
    await controller.loadTrack('u1');

    expect(controller.status, TrackStatus.loaded);
    expect(
      controller.totalCravingsLogged,
      2,
    ); // real pre-quit-date logs, not fabricated to 0
    expect(
      controller.longestStreakDays,
      0,
    ); // not daysUntilQuit mislabeled as a streak
  });
}

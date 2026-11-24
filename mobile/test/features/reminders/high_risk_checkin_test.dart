import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/relapse/controllers/relapse_controller.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';
import 'package:quit_companion/features/relapse/domain/restart_plan_calculator.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/reminders/data/check_in_state_store.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/data/high_risk_checkin_scheduler.dart';
import 'package:quit_companion/features/reminders/domain/high_risk_checkin_policy.dart';
import 'package:quit_companion/features/reminders/models/reminder_settings.dart';

/// FR11 / UC9 gentle check-in notifications.
final _now = DateTime(2026, 11, 23, 14); // 2 pm

CravingLog _log(
  String id,
  DateTime at, {
  RelapseRiskLevel risk = RelapseRiskLevel.high,
  bool pending = false,
}) => CravingLog(
  logId: id,
  userId: 'u1',
  cravingIntensity: 9,
  mood: Mood.stressed,
  triggerCategory: TriggerCategory.stress,
  locationContext: 'Work',
  activity: 'Working/studying',
  timestamp: at,
  relapseRiskScore: risk,
  riskAssessmentPending: pending,
);

void main() {
  group('HighRiskCheckInPolicy', () {
    const policy = HighRiskCheckInPolicy();
    final earlierHigh = _log('earlier', _now.subtract(const Duration(days: 2)));

    CheckInDecision decide(
      CravingLog saved, {
      List<CravingLog>? recent,
      DateTime? now,
      bool reminders = true,
      bool permission = true,
      DateTime? relapse,
      DateTime? lastScheduled,
      String? lastTrigger,
    }) => policy.decide(
      savedLog: saved,
      recentLogs: recent ?? [earlierHigh],
      now: now ?? _now,
      remindersEnabled: reminders,
      permissionGranted: permission,
      lastRelapseDate: relapse,
      lastCheckInScheduledAt: lastScheduled,
      lastTriggerLogId: lastTrigger,
    );

    test(
      'a second high-risk craving within 7 days schedules a check-in 2 h later',
      () {
        final d = decide(_log('new', _now));
        expect(d.shouldSchedule, isTrue);
        expect(d.scheduleAt, _now.add(const Duration(hours: 2)));
      },
    );

    test('non-high or still-pending assessments never trigger', () {
      expect(
        decide(_log('m', _now, risk: RelapseRiskLevel.medium)).skipReason,
        CheckInSkipReason.notHighRisk,
      );
      expect(
        decide(_log('p', _now, pending: true)).skipReason,
        CheckInSkipReason.notHighRisk,
      );
    });

    test('a single high-risk craving is not a pattern', () {
      expect(
        decide(_log('new', _now), recent: []).skipReason,
        CheckInSkipReason.noPattern,
      );
    });

    test(
      'high-risk cravings older than 7 days, or pending ones, do not count',
      () {
        final old = _log('old', _now.subtract(const Duration(days: 8)));
        final pendingHigh = _log(
          'ph',
          _now.subtract(const Duration(hours: 3)),
          pending: true,
        );
        expect(
          decide(_log('new', _now), recent: [old, pendingHigh]).skipReason,
          CheckInSkipReason.noPattern,
        );
      },
    );

    test('a relapse logged today or yesterday excludes the check-in', () {
      expect(
        decide(_log('new', _now), relapse: DateTime(2026, 11, 23)).skipReason,
        CheckInSkipReason.recentRelapse,
      );
      expect(
        decide(_log('new', _now), relapse: DateTime(2026, 11, 22)).skipReason,
        CheckInSkipReason.recentRelapse,
      );
      expect(
        decide(
          _log('new', _now),
          relapse: DateTime(2026, 11, 20),
        ).shouldSchedule,
        isTrue,
      );
    });

    test('respects the reminder setting and notification permission', () {
      expect(
        decide(_log('new', _now), reminders: false).skipReason,
        CheckInSkipReason.remindersOff,
      );
      expect(
        decide(_log('new', _now), permission: false).skipReason,
        CheckInSkipReason.noPermission,
      );
    });

    test(
      'the same craving, or any within 24 h of the last check-in, is not re-notified',
      () {
        expect(
          decide(_log('new', _now), lastTrigger: 'new').skipReason,
          CheckInSkipReason.alreadyHandled,
        );
        expect(
          decide(
            _log('new', _now),
            lastScheduled: _now.subtract(const Duration(hours: 23)),
          ).skipReason,
          CheckInSkipReason.cooldown,
        );
        expect(
          decide(
            _log('new', _now),
            lastScheduled: _now.subtract(const Duration(hours: 25)),
          ).shouldSchedule,
          isTrue,
        );
      },
    );

    test('check-ins that would land in quiet hours move to 9 am', () {
      final evening = DateTime(2026, 11, 23, 21);
      expect(
        decide(_log('new', evening), now: evening).scheduleAt,
        DateTime(2026, 11, 24, 9),
      );
      final night = DateTime(2026, 11, 23, 3);
      expect(
        decide(_log('new', night), now: night).scheduleAt,
        DateTime(2026, 11, 23, 9),
      );
    });
  });

  group('HighRiskCheckInScheduler', () {
    late FakeCravingLogRepository cravings;
    late FakeUserRepository users;
    late FakeReminderSettingsRepository settings;
    late FakeReminderNotificationService notifications;
    late InMemoryCheckInStateStore store;
    var clock = _now;

    HighRiskCheckInScheduler build() => HighRiskCheckInScheduler(
      cravingLogRepository: cravings,
      userRepository: users,
      settingsRepository: settings,
      notificationService: notifications,
      stateStore: store,
      now: () => clock,
    );

    setUp(() async {
      clock = _now;
      cravings = FakeCravingLogRepository();
      users = FakeUserRepository();
      await users.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 11, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      settings = FakeReminderSettingsRepository();
      await settings.saveSettings(
        const ReminderSettings(enabled: true, dailyFrequency: 4),
      );
      notifications = FakeReminderNotificationService();
      store = InMemoryCheckInStateStore();
      await cravings.logCraving(
        _log('earlier', _now.subtract(const Duration(days: 1))),
      );
    });

    Future<CheckInDecision?> logHigh(
      HighRiskCheckInScheduler s,
      String id,
    ) async {
      final log = _log(id, clock);
      await cravings.logCraving(log);
      return s.onCravingLogged('u1', log);
    }

    test('schedules one gentle notification and remembers it', () async {
      final decision = await logHigh(build(), 'new');

      expect(decision!.shouldSchedule, isTrue);
      final n = notifications.oneOffs[HighRiskCheckInScheduler.notificationId]!;
      expect(n.at, _now.add(const Duration(hours: 2)));
      expect(n.title, HighRiskCheckInScheduler.title);
      expect(n.body, HighRiskCheckInScheduler.body);
      expect((await store.read('u1')).lastTriggerLogId, 'new');
      // Daily reminders untouched.
      expect(notifications.cancelCallCount, 0);
    });

    test('wording is supportive and non-judgmental', () {
      final text =
          '${HighRiskCheckInScheduler.title} ${HighRiskCheckInScheduler.body}'
              .toLowerCase();
      for (final word in [
        'relapse',
        'fail',
        'slip',
        'warning',
        'danger',
        'you should',
        "don't",
        'risk',
      ]) {
        expect(text.contains(word), isFalse, reason: word);
      }
    });

    test(
      'no duplicates: repeat events within 24 h schedule only once, even across restarts',
      () async {
        await logHigh(build(), 'a');
        clock = clock.add(const Duration(hours: 1));
        final second = await logHigh(
          build(),
          'b',
        ); // new instance = app restart
        clock = clock.add(const Duration(hours: 1));
        final again = await build().onCravingLogged('u1', _log('b', clock));

        expect(second!.skipReason, CheckInSkipReason.cooldown);
        expect(again!.skipReason, isNotNull);
        expect(notifications.oneOffScheduleCalls, 1);
        expect(notifications.oneOffs, hasLength(1));
      },
    );

    test(
      'without notification permission nothing is scheduled and no prompt is shown',
      () async {
        notifications.permissionGranted = false;

        final decision = await logHigh(build(), 'new');

        expect(decision!.skipReason, CheckInSkipReason.noPermission);
        expect(notifications.oneOffs, isEmpty);
        expect(notifications.permissionRequests, 0);
        expect(notifications.permissionChecks, 1);
      },
    );

    test('with daily reminders switched off nothing is scheduled', () async {
      await settings.saveSettings(ReminderSettings.defaults);
      final decision = await logHigh(build(), 'new');
      expect(decision!.skipReason, CheckInSkipReason.remindersOff);
      expect(notifications.oneOffs, isEmpty);
    });

    test('a confirmed relapse today means no check-in', () async {
      final user = await users.getUser('u1');
      await users.saveUser(
        user!.copyWith(lastRelapseDate: DateTime(2026, 11, 23)),
      );

      final decision = await logHigh(build(), 'new');

      expect(decision!.skipReason, CheckInSkipReason.recentRelapse);
      expect(notifications.oneOffs, isEmpty);
    });

    test('logging a relapse cancels a pending check-in', () async {
      final scheduler = build();
      await logHigh(scheduler, 'new');
      expect(notifications.oneOffs, isNotEmpty);

      await scheduler.onRelapseLogged('u1');

      expect(notifications.oneOffs, isEmpty);
    });

    test('never throws: a failing dependency just means no check-in', () async {
      notifications.failWith = Exception('plugin unavailable');
      final decision = await logHigh(build(), 'new');
      expect(decision, isNull);
    });
  });

  group('wiring into existing controllers', () {
    late FakeCravingLogRepository cravings;
    late FakeUserRepository users;
    late FakeReminderSettingsRepository settings;
    late FakeReminderNotificationService notifications;
    late HighRiskCheckInScheduler scheduler;

    setUp(() async {
      cravings = FakeCravingLogRepository();
      users = FakeUserRepository();
      await users.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 11, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      settings = FakeReminderSettingsRepository();
      await settings.saveSettings(
        const ReminderSettings(enabled: true, dailyFrequency: 4),
      );
      notifications = FakeReminderNotificationService();
      scheduler = HighRiskCheckInScheduler(
        cravingLogRepository: cravings,
        userRepository: users,
        settingsRepository: settings,
        notificationService: notifications,
        stateStore: InMemoryCheckInStateStore(),
        now: () => _now,
      );
    });

    CravingLogController cravingController(RelapseRiskLevel risk) =>
        CravingLogController(
          cravings,
          FakeRelapsePredictionClient(fixedRiskLevel: risk),
          now: () => _now,
          checkInScheduler: scheduler,
        );

    Future<void> submit(CravingLogController c) => c.submitCraving(
      userId: 'u1',
      intensity: 9,
      mood: Mood.stressed,
      triggerCategory: TriggerCategory.stress,
      locationContext: 'Work',
      activity: 'Working/studying',
    );

    test(
      'CravingLogController schedules after a repeated high-risk prediction',
      () async {
        await cravings.logCraving(
          _log('earlier', _now.subtract(const Duration(days: 1))),
        );
        final c = cravingController(RelapseRiskLevel.high);

        await submit(c);
        final decision = await c.pendingCheckIn;

        expect(c.status, CravingLogStatus.success);
        expect(decision!.shouldSchedule, isTrue);
        expect(notifications.oneOffs, hasLength(1));
      },
    );

    test('low-risk cravings never schedule anything', () async {
      await cravings.logCraving(
        _log('earlier', _now.subtract(const Duration(days: 1))),
      );
      final c = cravingController(RelapseRiskLevel.low);

      await submit(c);
      await c.pendingCheckIn;

      expect(notifications.oneOffs, isEmpty);
    });

    test(
      'an offline (pending) assessment does not schedule a check-in',
      () async {
        await cravings.logCraving(
          _log('earlier', _now.subtract(const Duration(days: 1))),
        );
        final c = CravingLogController(
          cravings,
          FakeRelapsePredictionClient(fail: true),
          now: () => _now,
          checkInScheduler: scheduler,
        );

        await submit(c);
        await c.pendingCheckIn;

        expect(c.assessmentPending, isTrue);
        expect(notifications.oneOffs, isEmpty);
      },
    );

    test(
      'RelapseController cancels a pending check-in when a relapse is logged',
      () async {
        await cravings.logCraving(
          _log('earlier', _now.subtract(const Duration(days: 1))),
        );
        final c = cravingController(RelapseRiskLevel.high);
        await submit(c);
        await c.pendingCheckIn;
        expect(notifications.oneOffs, hasLength(1));

        final relapse = RelapseController(
          FakeJournalRepository(),
          users,
          cravings,
          RestartPlanCalculator(),
          now: () => _now,
          checkInScheduler: scheduler,
        );
        final ok = await relapse.submitRelapse(
          userId: 'u1',
          productUsed: ProductType.cigarettes,
          triggerCategory: TriggerCategory.stress,
          mood: RelapseMood.sad,
        );

        expect(ok, isTrue);
        expect(notifications.oneOffs, isEmpty);
      },
    );

    test(
      'turning daily reminders off cancels a pending check-in; logout clears it too',
      () async {
        await notifications.scheduleOneOffNotification(
          id: HighRiskCheckInScheduler.notificationId,
          at: _now,
          title: 't',
          body: 'b',
        );
        final reminders = ReminderController(settings, notifications);
        await reminders.loadSettings();

        expect(await reminders.setEnabled(false), isTrue);
        expect(notifications.oneOffs, isEmpty);

        await notifications.scheduleOneOffNotification(
          id: HighRiskCheckInScheduler.notificationId,
          at: _now,
          title: 't',
          body: 'b',
        );
        await reminders.suspendForLogout();
        expect(notifications.oneOffs, isEmpty);
      },
    );

    test(
      're-syncing daily reminders does not cancel a pending check-in',
      () async {
        await notifications.scheduleOneOffNotification(
          id: HighRiskCheckInScheduler.notificationId,
          at: _now,
          title: 't',
          body: 'b',
        );
        final reminders = ReminderController(settings, notifications);

        await reminders.loadSettings(); // Dashboard does this on every visit.

        expect(notifications.oneOffs, hasLength(1));
        expect(notifications.scheduledTimes, isNotEmpty);
      },
    );
  });
}

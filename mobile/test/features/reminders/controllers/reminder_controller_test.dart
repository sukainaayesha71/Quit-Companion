import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/domain/reminder_schedule_calculator.dart';
import 'package:quit_companion/features/reminders/models/reminder_settings.dart';

class _SlowReminderService extends FakeReminderNotificationService {
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> setPushNotificationsEnabled(bool enabled) async {
    if (!enabled) return super.setPushNotificationsEnabled(false);
    calls++;
    await completion.future;
    await super.setPushNotificationsEnabled(enabled);
  }

  @override
  Future<void> scheduleDailyReminders(
    List<ReminderTime> times, {
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
    bool remoteDelivery = false,
  }) async {
    calls++;
    await completion.future;
  }
}

void main() {
  for (final fails in [false, true]) {
    test(
      'push setting blocks overlapping changes and releases saving state after ${fails ? "failure" : "success"}',
      () async {
        final service = _SlowReminderService();
        final controller = ReminderController(
          FakeReminderSettingsRepository(),
          service,
        );
        controller.settings = const ReminderSettings(
          enabled: true,
          dailyFrequency: 4,
        );
        final pending = controller.setRemoteDelivery(true);
        expect(controller.isUpdating, isTrue);
        await Future<void>.delayed(Duration.zero);
        await controller.setHabitRemindersEnabled(true);
        expect(service.calls, 1);
        expect(controller.settings.remoteDelivery, isFalse);
        if (fails) {
          service.completion.completeError(StateError('unavailable'));
        } else {
          service.completion.complete();
        }
        await pending;
        expect(controller.isUpdating, isFalse);
        expect(controller.settings.remoteDelivery, !fails);
        expect(controller.errorMessage, fails ? isNotNull : isNull);
      },
    );
  }
  test('push notifications work while daily reminders are off', () async {
    final service = FakeReminderNotificationService();
    final repository = FakeReminderSettingsRepository();
    final controller = ReminderController(repository, service);
    await controller.setRemoteDelivery(true);
    expect(controller.settings.enabled, isFalse);
    expect(controller.settings.remoteDelivery, isTrue);
    expect(service.pushNotificationsEnabled, isTrue);
    expect(service.scheduledTimes, isEmpty);
    expect((await repository.getSettings()).remoteDelivery, isTrue);
  });

  test(
    'turning daily reminders off leaves push notifications enabled',
    () async {
      final service = FakeReminderNotificationService();
      final controller = ReminderController(
        FakeReminderSettingsRepository(),
        service,
      );
      await controller.setRemoteDelivery(true);
      await controller.setEnabled(true);
      // Step 12: push is the default, so the server owns the schedule.
      expect(service.remoteSchedule, hasLength(4));
      expect(service.scheduledTimes, isEmpty);
      await controller.setEnabled(false);
      expect(service.scheduledTimes, isEmpty);
      expect(service.remoteSchedule, isNull);
      expect(service.pushNotificationsEnabled, isTrue);
      expect(controller.settings.remoteDelivery, isTrue);
    },
  );

  test('turning push off preserves daily reminder times', () async {
    final service = FakeReminderNotificationService();
    final controller = ReminderController(
      FakeReminderSettingsRepository(),
      service,
    );
    await controller.setEnabled(true);
    await controller.setRemoteDelivery(true);
    final times = List.of(service.remoteSchedule!);
    await controller.setRemoteDelivery(false);
    // Same times, now delivered by the device instead of the server.
    expect(service.scheduledTimes, times);
    expect(service.remoteSchedule, isNull);
    expect(service.pushNotificationsEnabled, isFalse);
    expect(controller.settings.enabled, isTrue);
    expect(controller.deliveryMode, ReminderDeliveryMode.local);
  });

  test(
    'restoring push-only settings does not schedule daily reminders',
    () async {
      final service = FakeReminderNotificationService();
      final repository = FakeReminderSettingsRepository();
      await repository.saveSettings(
        const ReminderSettings(
          enabled: false,
          dailyFrequency: 4,
          remoteDelivery: true,
        ),
      );
      final controller = ReminderController(repository, service);
      await controller.loadSettings();
      expect(service.pushNotificationsEnabled, isTrue);
      expect(service.scheduledTimes, isEmpty);
    },
  );

  group('ReminderController', () {
    test(
      'loadSettings reads persisted settings and, if enabled, re-syncs the OS schedule',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        await settingsRepo.saveSettings(
          const ReminderSettings(enabled: true, dailyFrequency: 4),
        );
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );

        await controller.loadSettings();

        expect(controller.status, ReminderStatus.loaded);
        expect(controller.settings.enabled, isTrue);
        expect(controller.settings.dailyFrequency, 4);
        expect(notificationService.scheduledTimes, computeReminderTimes(4));
      },
    );

    test(
      'loadSettings does not touch the notification service when reminders are disabled',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );

        await controller.loadSettings();

        expect(controller.settings.enabled, isFalse);
        expect(notificationService.scheduledTimes, isEmpty);
      },
    );

    test(
      'setEnabled(true) requests permission, schedules reminders, and persists the setting',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );
        await controller.loadSettings();

        final result = await controller.setEnabled(true);

        expect(result, isTrue);
        expect(controller.settings.enabled, isTrue);
        // Step 12: delivered by push (server schedule), not locally.
        expect(notificationService.remoteSchedule, isNotEmpty);
        expect(notificationService.scheduledTimes, isEmpty);
        expect(controller.deliveryMode, ReminderDeliveryMode.push);
        expect((await settingsRepo.getSettings()).enabled, isTrue);
      },
    );

    test(
      'setEnabled(true) fails cleanly when the OS denies notification permission',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService()
          ..permissionGranted = false;
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );
        await controller.loadSettings();

        final result = await controller.setEnabled(true);

        expect(result, isFalse);
        expect(controller.settings.enabled, isFalse);
        expect(controller.errorMessage, isNotNull);
        expect(notificationService.scheduledTimes, isEmpty);
      },
    );

    test(
      'setEnabled(false) cancels all reminders and persists the setting',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );
        await controller.loadSettings();
        await controller.setEnabled(true);

        final result = await controller.setEnabled(false);

        expect(result, isTrue);
        expect(controller.settings.enabled, isFalse);
        expect(notificationService.cancelCallCount, greaterThanOrEqualTo(1));
        expect((await settingsRepo.getSettings()).enabled, isFalse);
      },
    );

    test(
      'setDailyFrequency reschedules with the new frequency when currently enabled',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );
        await controller.loadSettings();
        await controller.setEnabled(true);

        await controller.setDailyFrequency(5);

        expect(controller.settings.dailyFrequency, 5);
        expect(notificationService.remoteSchedule, computeReminderTimes(5));
        expect((await settingsRepo.getSettings()).dailyFrequency, 5);
      },
    );

    test(
      'setDailyFrequency does not touch the notification service when disabled',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );
        await controller.loadSettings();

        await controller.setDailyFrequency(5);

        expect(controller.settings.dailyFrequency, 5);
        expect(notificationService.scheduledTimes, isEmpty);
      },
    );

    test(
      'setDailyFrequency silently ignores a value outside 3-5 (UI should never offer one)',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final controller = ReminderController(
          settingsRepo,
          FakeReminderNotificationService(),
        );
        await controller.loadSettings();

        await controller.setDailyFrequency(7);

        expect(controller.settings.dailyFrequency, 4); // unchanged default
      },
    );

    test(
      'additional reminder preferences reschedule and persist with daily check-ins',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );
        await controller.loadSettings();
        await controller.setEnabled(true);

        await controller.setHabitRemindersEnabled(true);
        await controller.setRecoveryMotivationEnabled(true);

        expect(notificationService.remoteHabit, isTrue);
        expect(notificationService.remoteRecovery, isTrue);
        final saved = await settingsRepo.getSettings();
        expect(saved.habitRemindersEnabled, isTrue);
        expect(saved.recoveryMotivationEnabled, isTrue);
      },
    );

    test(
      'resetForAccountDeletion cancels reminders and restores local defaults',
      () async {
        final settingsRepo = FakeReminderSettingsRepository();
        final notificationService = FakeReminderNotificationService();
        final controller = ReminderController(
          settingsRepo,
          notificationService,
        );
        await controller.loadSettings();
        await controller.setEnabled(true);
        await controller.setHabitRemindersEnabled(true);
        await controller.setRecoveryMotivationEnabled(true);

        await controller.resetForAccountDeletion();

        final savedSettings = await settingsRepo.getSettings();
        expect(controller.settings.enabled, isFalse);
        expect(controller.settings.dailyFrequency, 4);
        expect(controller.settings.habitRemindersEnabled, isFalse);
        expect(controller.settings.recoveryMotivationEnabled, isFalse);
        expect(savedSettings.enabled, isFalse);
        expect(savedSettings.dailyFrequency, 4);
        expect(savedSettings.habitRemindersEnabled, isFalse);
        expect(savedSettings.recoveryMotivationEnabled, isFalse);
        expect(notificationService.scheduledTimes, isEmpty);
      },
    );
  });
}

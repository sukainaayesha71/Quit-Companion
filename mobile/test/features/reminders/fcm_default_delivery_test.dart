import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/data/reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/shared_prefs_reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/domain/reminder_schedule_calculator.dart';
import 'package:quit_companion/features/reminders/models/reminder_settings.dart';
import 'package:quit_companion/features/reminders/presentation/screens/reminder_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Step 12: FCM push is the default delivery method, with on-device
/// reminders as the fallback.
void main() {
  late FakeReminderSettingsRepository repo;
  late FakeReminderNotificationService service;
  late ReminderController controller;

  setUp(() {
    repo = FakeReminderSettingsRepository();
    service = FakeReminderNotificationService();
    controller = ReminderController(repo, service);
  });

  group('defaults and storage', () {
    test('push is on by default; daily reminders stay off until enabled', () {
      expect(ReminderSettings.defaults.remoteDelivery, isTrue);
      expect(ReminderSettings.defaults.enabled, isFalse);
    });

    test(
      'a never-saved push choice reads as on; a saved choice is kept',
      () async {
        SharedPreferences.setMockInitialValues({
          'reminder_settings.enabled': true,
          'reminder_settings.daily_frequency': 3,
        });
        expect(
          (await SharedPrefsReminderSettingsRepository().getSettings())
              .remoteDelivery,
          isTrue,
        );

        SharedPreferences.setMockInitialValues({
          'reminder_settings.enabled': true,
          'reminder_settings.daily_frequency': 3,
          'reminder_settings.remote_delivery': false,
        });
        expect(
          (await SharedPrefsReminderSettingsRepository().getSettings())
              .remoteDelivery,
          isFalse,
        );
      },
    );

    test('the confirmed-server-schedule flag round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefsRepo = SharedPrefsReminderSettingsRepository();
      await prefsRepo.saveSettings(
        const ReminderSettings(
          enabled: true,
          dailyFrequency: 5,
          remoteDelivery: true,
          remoteScheduleActive: true,
        ),
      );
      expect((await prefsRepo.getSettings()).remoteScheduleActive, isTrue);
    });
  });

  group('push delivery and fallback', () {
    test(
      'enabling reminders schedules them on the server and cancels local ones',
      () async {
        await controller.loadSettings();
        await controller.setEnabled(true);

        expect(service.remoteSchedule, computeReminderTimes(4));
        expect(service.scheduledTimes, isEmpty);
        expect(controller.deliveryMode, ReminderDeliveryMode.push);
        expect((await repo.getSettings()).remoteScheduleActive, isTrue);
      },
    );

    test(
      'push unavailable (no token / permission) falls back to on-device reminders',
      () async {
        service.remoteFailure = const PushUnavailableException('no FCM token');
        await controller.loadSettings();
        await controller.setEnabled(true);

        expect(service.scheduledTimes, computeReminderTimes(4));
        expect(service.remoteSchedule, isNull);
        expect(controller.deliveryMode, ReminderDeliveryMode.localFallback);
        expect(controller.settings.remoteScheduleActive, isFalse);
        expect(
          controller.settings.remoteDelivery,
          isTrue,
          reason: 'preference kept; retried next time',
        );
      },
    );

    test(
      'backend unreachable on first setup also falls back to on-device reminders',
      () async {
        service.remoteFailure = const RemoteScheduleException('offline');
        await controller.loadSettings();
        await controller.setEnabled(true);

        expect(service.scheduledTimes, hasLength(4));
        expect(controller.deliveryMode, ReminderDeliveryMode.localFallback);
      },
    );

    test(
      'once confirmed, a temporary outage keeps the server schedule (no duplicate local reminders)',
      () async {
        await repo.saveSettings(
          const ReminderSettings(
            enabled: true,
            dailyFrequency: 4,
            remoteDelivery: true,
            remoteScheduleActive: true,
          ),
        );
        service.remoteFailure = const RemoteScheduleException(
          'offline at app start',
        );

        await controller.loadSettings();

        expect(service.scheduledTimes, isEmpty);
        expect(controller.deliveryMode, ReminderDeliveryMode.push);
        expect((await repo.getSettings()).remoteScheduleActive, isTrue);
        expect(service.remoteDisableCalls, 0);
      },
    );

    test(
      'when push stops working after being active, the server schedule is stopped and local takes over',
      () async {
        await repo.saveSettings(
          const ReminderSettings(
            enabled: true,
            dailyFrequency: 3,
            remoteDelivery: true,
            remoteScheduleActive: true,
          ),
        );
        service.remoteFailure = const PushUnavailableException('token revoked');

        await controller.loadSettings();

        expect(service.scheduledTimes, computeReminderTimes(3));
        expect(service.remoteDisableCalls, 1);
        expect((await repo.getSettings()).remoteScheduleActive, isFalse);
        expect(controller.deliveryMode, ReminderDeliveryMode.localFallback);
      },
    );

    test('recovering after a fallback moves delivery back to push', () async {
      service.remoteFailure = const PushUnavailableException('no token yet');
      await controller.loadSettings();
      await controller.setEnabled(true);
      expect(controller.deliveryMode, ReminderDeliveryMode.localFallback);

      service.remoteFailure = null;
      await controller.loadSettings();

      expect(controller.deliveryMode, ReminderDeliveryMode.push);
      expect(service.scheduledTimes, isEmpty);
      expect(service.remoteSchedule, hasLength(4));
    });

    test('turning reminders off stops the server schedule too', () async {
      await controller.loadSettings();
      await controller.setEnabled(true);
      await controller.setEnabled(false);

      expect(service.remoteSchedule, isNull);
      expect(service.scheduledTimes, isEmpty);
      expect(controller.deliveryMode, ReminderDeliveryMode.off);
      expect(controller.settings.remoteScheduleActive, isFalse);
    });
  });

  group('permissions', () {
    test(
      'app start never shows a permission prompt, even with push on by default',
      () async {
        service.permissionGranted = false;
        await controller.loadSettings();

        expect(service.permissionRequests, 0);
        expect(service.pushNotificationsEnabled, isFalse);
      },
    );

    test(
      'app start registers push silently when permission was already granted',
      () async {
        await controller.loadSettings();

        expect(service.permissionRequests, 0);
        expect(service.pushNotificationsEnabled, isTrue);
      },
    );

    test(
      'denied permission when enabling reminders schedules nothing',
      () async {
        service.permissionGranted = false;
        await controller.loadSettings();
        expect(await controller.setEnabled(true), isFalse);

        expect(service.scheduledTimes, isEmpty);
        expect(service.remoteSchedule, isNull);
      },
    );
  });

  group('Reminders screen', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ReminderSettingsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder_enabled_switch')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows push delivery by default', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('reminder_delivery_push')), findsOneWidget);
      expect(find.text('Delivered as push notifications.'), findsOneWidget);
    });

    testWidgets('explains the on-device fallback', (tester) async {
      service.remoteFailure = const PushUnavailableException('no token');
      await pump(tester);
      expect(
        find.byKey(const Key('reminder_delivery_localFallback')),
        findsOneWidget,
      );
    });
  });
}

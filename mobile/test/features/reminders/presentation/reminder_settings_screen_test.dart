import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/presentation/screens/reminder_settings_screen.dart';

void main() {
  testWidgets('push can be enabled while daily reminders stay off', (
    tester,
  ) async {
    final service = FakeReminderNotificationService();
    final controller = ReminderController(
      FakeReminderSettingsRepository(),
      service,
    );
    await tester.pumpWidget(
      MaterialApp(home: ReminderSettingsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    // Step 12: push starts ON by default — switch it off, then on again.
    expect(controller.settings.remoteDelivery, isTrue);
    await tester.tap(find.byKey(const Key('remote_delivery_switch')));
    await tester.pumpAndSettle();
    expect(controller.settings.remoteDelivery, isFalse);
    expect(service.pushNotificationsEnabled, isFalse);
    await tester.tap(find.byKey(const Key('remote_delivery_switch')));
    await tester.pumpAndSettle();
    expect(controller.settings.remoteDelivery, isTrue);
    expect(controller.settings.enabled, isFalse);
    expect(service.pushNotificationsEnabled, isTrue);
    expect(service.scheduledTimes, isEmpty);
    expect(service.remoteSchedule, isNull);
  });

  ReminderController buildController({
    FakeReminderNotificationService? notificationService,
  }) {
    return ReminderController(
      FakeReminderSettingsRepository(),
      notificationService ?? FakeReminderNotificationService(),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    ReminderController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ReminderSettingsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders the toggle, off by default, with no frequency selector shown',
    (tester) async {
      await pumpScreen(tester, buildController());

      final toggle = tester.widget<Switch>(
        find.byKey(const Key('reminder_enabled_switch')),
      );
      expect(toggle.value, isFalse);
      expect(
        find.byKey(const Key('reminder_frequency_selector')),
        findsNothing,
      );
    },
  );

  testWidgets('omits the technical notification footer', (tester) async {
    await pumpScreen(tester, buildController());

    expect(find.textContaining('scheduled on this device'), findsNothing);
    expect(find.textContaining('trusted sender'), findsNothing);
  });

  testWidgets(
    'toggling on requests permission and reveals the frequency selector',
    (tester) async {
      final controller = buildController();
      await pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('reminder_enabled_switch')));
      await tester.pumpAndSettle();

      expect(controller.settings.enabled, isTrue);
      expect(
        find.byKey(const Key('reminder_frequency_selector')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reminder_frequency_4')), findsOneWidget);
      expect(find.byKey(const Key('habit_reminder_switch')), findsOneWidget);
      expect(
        find.byKey(const Key('recovery_motivation_switch')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a denied permission shows an inline error and keeps the toggle off',
    (tester) async {
      final notificationService = FakeReminderNotificationService()
        ..permissionGranted = false;
      final controller = buildController(
        notificationService: notificationService,
      );
      await pumpScreen(tester, controller);

      await tester.tap(find.byKey(const Key('reminder_enabled_switch')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminder_error_text')), findsOneWidget);
      final toggle = tester.widget<Switch>(
        find.byKey(const Key('reminder_enabled_switch')),
      );
      expect(toggle.value, isFalse);
    },
  );

  testWidgets(
    'selecting a different frequency reschedules and updates the selection',
    (tester) async {
      final notificationService = FakeReminderNotificationService();
      final controller = buildController(
        notificationService: notificationService,
      );
      await pumpScreen(tester, controller);
      await tester.tap(find.byKey(const Key('reminder_enabled_switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reminder_frequency_5')));
      await tester.pumpAndSettle();

      expect(controller.settings.dailyFrequency, 5);
      expect(notificationService.remoteSchedule, hasLength(5));
    },
  );

  testWidgets('toggling off hides the frequency selector', (tester) async {
    final controller = buildController();
    await pumpScreen(tester, controller);
    await tester.tap(find.byKey(const Key('reminder_enabled_switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reminder_enabled_switch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder_frequency_selector')), findsNothing);
  });

  testWidgets(
    'additional reminder switches update their independent settings',
    (tester) async {
      final controller = buildController();
      await pumpScreen(tester, controller);
      await tester.tap(find.byKey(const Key('reminder_enabled_switch')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('habit_reminder_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery_motivation_switch')));
      await tester.pumpAndSettle();

      expect(controller.settings.habitRemindersEnabled, isTrue);
      expect(controller.settings.recoveryMotivationEnabled, isTrue);
    },
  );
}

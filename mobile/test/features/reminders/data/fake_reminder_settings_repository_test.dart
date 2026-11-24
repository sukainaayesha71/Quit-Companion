import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/reminders/data/fake_reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/models/reminder_settings.dart';

void main() {
  test(
    'getSettings returns the defaults (disabled, 4/day) before anything is saved',
    () async {
      final repo = FakeReminderSettingsRepository();

      final settings = await repo.getSettings();

      expect(settings.enabled, isFalse);
      expect(settings.dailyFrequency, 4);
    },
  );

  test('saveSettings then getSettings round-trips', () async {
    final repo = FakeReminderSettingsRepository();

    await repo.saveSettings(
      const ReminderSettings(enabled: true, dailyFrequency: 5),
    );

    final settings = await repo.getSettings();
    expect(settings.enabled, isTrue);
    expect(settings.dailyFrequency, 5);
  });

  test(
    'saveSettings throws when failWith is set, simulating a persistence failure',
    () async {
      final repo = FakeReminderSettingsRepository()
        ..failWith = Exception('disk full');

      expect(
        () => repo.saveSettings(
          const ReminderSettings(enabled: true, dailyFrequency: 4),
        ),
        throwsException,
      );
    },
  );
}

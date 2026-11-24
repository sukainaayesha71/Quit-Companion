import 'package:quit_companion/features/reminders/models/reminder_settings.dart';
import 'package:quit_companion/features/reminders/data/reminder_settings_repository.dart';

class FakeReminderSettingsRepository implements ReminderSettingsRepository {
  ReminderSettings _settings = ReminderSettings.defaults;
  Object? failWith;

  @override
  Future<ReminderSettings> getSettings() async {
    if (failWith != null) throw failWith!;
    return _settings;
  }

  @override
  Future<void> saveSettings(ReminderSettings settings) async {
    if (failWith != null) throw failWith!;
    _settings = settings;
  }
}

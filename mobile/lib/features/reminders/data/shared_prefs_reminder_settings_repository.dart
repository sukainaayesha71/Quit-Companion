import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit_companion/features/reminders/models/reminder_settings.dart';
import 'package:quit_companion/features/reminders/data/reminder_settings_repository.dart';

/// Real implementation — `shared_preferences` (already a dependency,
/// used elsewhere for simple device-local key/value state), not
/// Firestore. See ReminderSettingsRepository's doc comment for why.
class SharedPrefsReminderSettingsRepository
    implements ReminderSettingsRepository {
  static const _enabledKey = 'reminder_settings.enabled';
  static const _frequencyKey = 'reminder_settings.daily_frequency';
  static const _habitEnabledKey = 'reminder_settings.habit_enabled';
  static const _recoveryEnabledKey = 'reminder_settings.recovery_enabled';

  @override
  Future<ReminderSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey);
    final frequency = prefs.getInt(_frequencyKey);
    if (enabled == null || frequency == null) return ReminderSettings.defaults;
    return ReminderSettings(
      enabled: enabled,
      dailyFrequency: frequency,
      habitRemindersEnabled: prefs.getBool(_habitEnabledKey) ?? false,
      recoveryMotivationEnabled: prefs.getBool(_recoveryEnabledKey) ?? false,
      // Missing key = never chosen: use the push-by-default (Step 12).
      // A previously saved value (even the old default `false`) is kept.
      remoteDelivery:
          prefs.getBool('reminder_settings.remote_delivery') ??
          ReminderSettings.defaults.remoteDelivery,
      remoteScheduleActive:
          prefs.getBool('reminder_settings.remote_schedule_active') ?? false,
    );
  }

  @override
  Future<void> saveSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setBool(
      'reminder_settings.remote_delivery',
      settings.remoteDelivery,
    );
    await prefs.setBool(
      'reminder_settings.remote_schedule_active',
      settings.remoteScheduleActive,
    );
    await prefs.setInt(_frequencyKey, settings.dailyFrequency);
    await prefs.setBool(_habitEnabledKey, settings.habitRemindersEnabled);
    await prefs.setBool(
      _recoveryEnabledKey,
      settings.recoveryMotivationEnabled,
    );
  }
}

import 'package:quit_companion/features/reminders/models/reminder_settings.dart';

/// ReminderSettings persistence (Module 11 — Notification & Reminder,
/// FR14). Deliberately device-local, not a Firestore
/// nicotineUsers/{userId}/... document like every other setting in this
/// app: a scheduled local notification is inherently tied to the OS
/// notification scheduler on the one device it was scheduled on — a
/// setting saved from device A has no way to affect device B's local
/// notification schedule, so syncing it through Firestore would create a
/// setting that looks shared but isn't actually honored on other
/// devices. If FCM is added later (see the implementation record's "How
/// FCM could be integrated later" section), that's the point where a
/// server-synced settings document would start making sense.
abstract class ReminderSettingsRepository {
  Future<ReminderSettings> getSettings();

  Future<void> saveSettings(ReminderSettings settings);
}

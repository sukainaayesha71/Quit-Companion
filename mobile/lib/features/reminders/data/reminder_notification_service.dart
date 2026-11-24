import 'package:quit_companion/features/reminders/domain/reminder_schedule_calculator.dart';

/// Push can't be used on this device right now: notification permission
/// denied, or no FCM token / token registration failed. Not transient —
/// fall back to on-device reminders.
class PushUnavailableException implements Exception {
  final String message;
  const PushUnavailableException(this.message);
  @override
  String toString() => message;
}

/// The server schedule couldn't be saved (offline, backend down). Usually
/// transient.
class RemoteScheduleException implements Exception {
  final String message;
  const RemoteScheduleException(this.message);
  @override
  String toString() => message;
}

/// Delivery-mechanism seam for FR14 reminders. The app combines on-device
/// schedules with FCM reception and token registration; a trusted sender is
/// still required to deliver remote messages.
abstract class ReminderNotificationService {
  /// Requests OS and FCM notification permission if needed. Returns
  /// whether notification permission is granted after the request.
  Future<bool> requestPermission();

  /// Cancels any previously scheduled reminders, then schedules exactly
  /// [times] as daily-repeating local notifications. Idempotent — safe
  /// to call again with a new [times] list to change the schedule, or
  /// with the same list on every app startup to make sure the OS-level
  /// schedule matches what the user last configured (handles the case
  /// where the app was reinstalled or the OS cleared its scheduled-alarm
  /// state).
  Future<void> scheduleDailyReminders(
    List<ReminderTime> times, {
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
    bool remoteDelivery = false,
  });

  /// Cancels every reminder this service has scheduled.
  Future<void> cancelAllReminders();

  /// Cancels on-device schedules without changing push consent.
  Future<void> cancelLocalReminders();

  /// Independently controls online account/milestone notifications.
  Future<void> setPushNotificationsEnabled(bool enabled);

  /// FR11/UC9 gentle check-ins: whether notifications are currently
  /// allowed. Must NOT show a permission prompt — check-ins are scheduled
  /// in the background after a craving, never as a surprise system dialog.
  Future<bool> hasPermission();

  /// Schedules a single (non-repeating) local notification with [id] at
  /// [at]. Re-using an [id] replaces the earlier one instead of stacking.
  /// Not affected by [cancelLocalReminders], which only owns the daily
  /// reminder ids.
  Future<void> scheduleOneOffNotification({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancelNotification(int id);

  /// Step 12 (FCM default): registers this device for push and saves the
  /// daily schedule on the server so the backend worker delivers it over
  /// FCM. Throws [PushUnavailableException] or [RemoteScheduleException].
  /// Never touches local reminders — the caller cancels those only after
  /// this succeeds, so the user is never left with neither.
  Future<void> scheduleRemoteDailyReminders(
    List<ReminderTime> times, {
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
  });

  /// Stops server-side daily delivery for this account (best effort; event
  /// notifications such as badges are unaffected).
  Future<void> disableRemoteDailyReminders();
}

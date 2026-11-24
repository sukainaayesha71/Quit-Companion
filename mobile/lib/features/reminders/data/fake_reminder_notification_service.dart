import 'package:quit_companion/features/reminders/domain/reminder_schedule_calculator.dart';
import 'package:quit_companion/features/reminders/data/reminder_notification_service.dart';

class ScheduledOneOff {
  final int id;
  final DateTime at;
  final String title;
  final String body;

  const ScheduledOneOff({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });
}

class FakeReminderNotificationService implements ReminderNotificationService {
  bool permissionGranted = true;
  List<ReminderTime> scheduledTimes = [];
  bool habitRemindersEnabled = false;
  bool recoveryMotivationEnabled = false;
  int cancelCallCount = 0;
  bool pushNotificationsEnabled = false;
  int pushUpdateCallCount = 0;
  Object? failWith;

  /// One-off notifications currently scheduled, keyed by id (re-using an
  /// id replaces, like the real plugin). [oneOffScheduleCalls] counts every
  /// schedule call so duplicate-prevention tests can assert on it.
  final Map<int, ScheduledOneOff> oneOffs = {};
  int oneOffScheduleCalls = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;

  /// Step 12 server (FCM) schedule; null = no active server schedule.
  List<ReminderTime>? remoteSchedule;
  bool remoteHabit = false;
  bool remoteRecovery = false;
  int remoteDisableCalls = 0;

  /// Thrown by scheduleRemoteDailyReminders (e.g. PushUnavailableException
  /// or RemoteScheduleException) to exercise the fallback.
  Object? remoteFailure;

  @override
  Future<bool> requestPermission() async {
    if (failWith != null) throw failWith!;
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> hasPermission() async {
    if (failWith != null) throw failWith!;
    permissionChecks++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleOneOffNotification({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (failWith != null) throw failWith!;
    oneOffScheduleCalls++;
    oneOffs[id] = ScheduledOneOff(id: id, at: at, title: title, body: body);
  }

  @override
  Future<void> scheduleRemoteDailyReminders(
    List<ReminderTime> times, {
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
  }) async {
    if (failWith != null) throw failWith!;
    if (!permissionGranted) {
      throw const PushUnavailableException('permission denied');
    }
    if (remoteFailure != null) throw remoteFailure!;
    remoteSchedule = List.of(times);
    remoteHabit = habitRemindersEnabled;
    remoteRecovery = recoveryMotivationEnabled;
    pushNotificationsEnabled = true;
  }

  @override
  Future<void> disableRemoteDailyReminders() async {
    if (failWith != null) throw failWith!;
    remoteDisableCalls++;
    remoteSchedule = null;
  }

  @override
  Future<void> cancelNotification(int id) async {
    if (failWith != null) throw failWith!;
    oneOffs.remove(id);
  }

  @override
  Future<void> scheduleDailyReminders(
    List<ReminderTime> times, {
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
    bool remoteDelivery = false,
  }) async {
    if (failWith != null) throw failWith!;
    scheduledTimes = times;
    this.habitRemindersEnabled = habitRemindersEnabled;
    this.recoveryMotivationEnabled = recoveryMotivationEnabled;
  }

  @override
  Future<void> cancelAllReminders() async {
    await cancelLocalReminders();
    oneOffs.clear();
    await setPushNotificationsEnabled(false);
  }

  @override
  Future<void> setPushNotificationsEnabled(bool enabled) async {
    if (failWith != null) throw failWith!;
    pushUpdateCallCount++;
    pushNotificationsEnabled = enabled;
    // Mirrors the real service: turning push off stops server delivery.
    if (!enabled) remoteSchedule = null;
  }

  @override
  Future<void> cancelLocalReminders() async {
    if (failWith != null) throw failWith!;
    cancelCallCount++;
    scheduledTimes = [];
    habitRemindersEnabled = false;
    recoveryMotivationEnabled = false;
  }
}

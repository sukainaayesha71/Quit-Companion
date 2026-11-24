import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/reminders/data/reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/domain/reminder_schedule_calculator.dart';
import 'package:quit_companion/features/reminders/models/reminder_settings.dart';
import 'package:quit_companion/features/reminders/data/high_risk_checkin_scheduler.dart';

enum ReminderStatus { idle, loading, loaded, error }

/// How daily check-ins are currently being delivered (shown on the
/// Reminders screen).
enum ReminderDeliveryMode {
  /// Daily reminders are off.
  off,

  /// Server schedule + FCM push (Step 12 default).
  push,

  /// On-device reminders because the user turned push off.
  local,

  /// On-device reminders because push couldn't be set up.
  localFallback,
}

/// FR14 (Module 11 — Notification & Reminder): loads/persists
/// ReminderSettings and keeps the delivery schedule in sync with them.
///
/// Step 12 (2026-11-23): FCM push is the default delivery method. When daily
/// reminders are on and push is allowed, the schedule is saved on the server
/// and the backend worker sends it over FCM; the on-device schedule is
/// cancelled only after that succeeds. If push can't be set up, on-device
/// reminders are scheduled instead (fallback). A temporary outage after the
/// server schedule was confirmed keeps relying on it, so the user never gets
/// both a push and a local reminder for the same slot.
///
/// Every mutation updates the delivery schedule first (so a failure doesn't
/// leave a persisted setting that isn't honoured), then persists, then
/// notifies.
class ReminderController extends ChangeNotifier {
  final ReminderSettingsRepository _settingsRepository;
  final ReminderNotificationService _notificationService;

  ReminderController(this._settingsRepository, this._notificationService);

  ReminderStatus status = ReminderStatus.idle;
  String? errorMessage;
  bool isUpdating = false;
  ReminderSettings settings = ReminderSettings.defaults;
  ReminderDeliveryMode deliveryMode = ReminderDeliveryMode.off;

  /// Re-applies the persisted settings on every app start (Dashboard): the
  /// OS-level local schedule can be cleared by a reinstall or aggressive
  /// battery optimisation, and the server schedule may need re-syncing.
  Future<void> loadSettings() async {
    status = ReminderStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _settingsRepository.getSettings();
      await _syncEventPush(loaded);
      settings = await _applyDelivery(loaded);
      await _settingsRepository.saveSettings(settings);
      status = ReminderStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('ReminderController.loadSettings failed: $e');
      errorMessage = 'Could not load your reminder settings.';
      status = ReminderStatus.error;
      notifyListeners();
    }
  }

  /// Event notifications (badge, restart plan, activity feedback) need the
  /// FCM token registered even while daily reminders are off. On app start
  /// this never shows a permission prompt: if permission isn't granted yet,
  /// push simply waits until the user turns reminders/push on.
  Future<void> _syncEventPush(ReminderSettings s) async {
    try {
      if (!s.remoteDelivery) {
        await _notificationService.setPushNotificationsEnabled(false);
      } else if (await _notificationService.hasPermission()) {
        await _notificationService.setPushNotificationsEnabled(true);
      }
    } catch (e) {
      debugPrint('Push registration on load skipped: $e');
    }
  }

  /// Turning reminders on requires notification permission first. If
  /// permission is denied, nothing is scheduled or persisted as enabled.
  Future<bool> setEnabled(bool enabled) async {
    if (isUpdating) return false;
    isUpdating = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (enabled) {
        final granted = await _notificationService.requestPermission();
        if (!granted) {
          errorMessage =
              'Notification permission was not granted. Enable it in your device settings to receive reminders.';
          notifyListeners();
          return false;
        }
      } else {
        // FR11/UC9: check-ins follow this setting, so a pending one goes too.
        await _notificationService.cancelNotification(
          HighRiskCheckInScheduler.notificationId,
        );
      }
      settings = await _applyDelivery(settings.copyWith(enabled: enabled));
      await _settingsRepository.saveSettings(settings);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ReminderController.setEnabled failed: $e');
      errorMessage =
          'Could not update your reminder settings. Please try again.';
      notifyListeners();
      return false;
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> setHabitRemindersEnabled(bool enabled) =>
      _updateSchedule(settings.copyWith(habitRemindersEnabled: enabled));

  Future<void> setRecoveryMotivationEnabled(bool enabled) =>
      _updateSchedule(settings.copyWith(recoveryMotivationEnabled: enabled));

  /// SRDS's literal "3 to 5 daily" range — [frequency] outside that is a
  /// caller bug (the UI only ever offers 3/4/5), so a silent no-op.
  Future<void> setDailyFrequency(int frequency) async {
    if (frequency < 3 || frequency > 5) return;
    await _updateSchedule(settings.copyWith(dailyFrequency: frequency));
  }

  Future<void> setRemoteDelivery(bool enabled) async {
    if (isUpdating) return;
    isUpdating = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (enabled && !await _notificationService.requestPermission()) {
        errorMessage =
            'Allow notifications in your device settings to receive push notifications.';
        return;
      }
      await _notificationService.setPushNotificationsEnabled(enabled);
      var updated = settings.copyWith(remoteDelivery: enabled);
      if (!enabled) updated = updated.copyWith(remoteScheduleActive: false);
      updated = await _applyDelivery(updated);
      await _settingsRepository.saveSettings(updated);
      settings = updated;
    } catch (error) {
      debugPrint('Could not update push notifications: $error');
      errorMessage =
          'Could not update push notifications. Check your connection and try again.';
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> _updateSchedule(ReminderSettings updated) async {
    if (isUpdating) return;
    isUpdating = true;
    errorMessage = null;
    notifyListeners();
    try {
      final applied = await _applyDelivery(updated);
      await _settingsRepository.saveSettings(applied);
      settings = applied;
      notifyListeners();
    } catch (e) {
      debugPrint('ReminderController._updateSchedule failed: $e');
      errorMessage =
          'Could not update your reminder settings. Please try again.';
      notifyListeners();
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  /// The single place that decides push vs. on-device delivery. Returns the
  /// settings with `remoteScheduleActive` updated; sets [deliveryMode].
  Future<ReminderSettings> _applyDelivery(ReminderSettings s) async {
    if (!s.enabled) {
      await _notificationService.cancelLocalReminders();
      deliveryMode = ReminderDeliveryMode.off;
      return _stopRemoteDaily(s);
    }

    final times = computeReminderTimes(s.dailyFrequency);
    if (s.remoteDelivery) {
      try {
        await _notificationService.scheduleRemoteDailyReminders(
          times,
          habitRemindersEnabled: s.habitRemindersEnabled,
          recoveryMotivationEnabled: s.recoveryMotivationEnabled,
        );
        // Only now that the server owns the schedule: no duplicates.
        await _notificationService.cancelLocalReminders();
        deliveryMode = ReminderDeliveryMode.push;
        return s.copyWith(remoteScheduleActive: true);
      } on RemoteScheduleException catch (e) {
        if (s.remoteScheduleActive) {
          // Already confirmed earlier and still active on the server:
          // a temporary outage shouldn't add duplicate local reminders.
          debugPrint('Push schedule re-sync deferred: $e');
          deliveryMode = ReminderDeliveryMode.push;
          return s;
        }
        debugPrint('Push schedule unavailable, using on-device reminders: $e');
      } on PushUnavailableException catch (e) {
        debugPrint('Push unavailable, using on-device reminders: $e');
      } catch (e) {
        debugPrint('Push setup failed, using on-device reminders: $e');
      }
      await _scheduleLocal(s, times);
      deliveryMode = ReminderDeliveryMode.localFallback;
      return _stopRemoteDaily(s);
    }

    await _scheduleLocal(s, times);
    deliveryMode = ReminderDeliveryMode.local;
    return _stopRemoteDaily(s);
  }

  Future<void> _scheduleLocal(ReminderSettings s, List<ReminderTime> times) =>
      _notificationService.scheduleDailyReminders(
        times,
        habitRemindersEnabled: s.habitRemindersEnabled,
        recoveryMotivationEnabled: s.recoveryMotivationEnabled,
      );

  /// Best effort: a server schedule left active would duplicate local
  /// reminders, so try to switch it off whenever we're not using it.
  Future<ReminderSettings> _stopRemoteDaily(ReminderSettings s) async {
    if (!s.remoteScheduleActive) return s;
    try {
      await _notificationService.disableRemoteDailyReminders();
      return s.copyWith(remoteScheduleActive: false);
    } catch (e) {
      debugPrint('Could not stop the server push schedule yet: $e');
      return s;
    }
  }

  Future<void> resetForAccountDeletion() async {
    await _notificationService.cancelAllReminders();
    await _settingsRepository.saveSettings(ReminderSettings.defaults);
    settings = ReminderSettings.defaults;
    deliveryMode = ReminderDeliveryMode.off;
    status = ReminderStatus.loaded;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> suspendForLogout() async {
    try {
      await _notificationService.cancelAllReminders();
    } catch (error) {
      debugPrint('Could not detach reminder delivery during logout: $error');
    }
  }
}

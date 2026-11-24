import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/reminders/data/check_in_state_store.dart';
import 'package:quit_companion/features/reminders/data/reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/reminder_settings_repository.dart';
import 'package:quit_companion/features/reminders/domain/high_risk_checkin_policy.dart';

/// FR11 / UC9 gentle check-in: after a craving is saved, decides (via
/// HighRiskCheckInPolicy) whether to schedule one supportive local
/// notification, and cancels it if a relapse is logged before it fires.
///
/// Reuses the existing reminder stack: the same ReminderNotificationService
/// and channel as the daily check-ins, gated by the same "Daily reminders"
/// setting, and never prompts for permission. Local delivery only — no FCM,
/// matching the project decision that check-ins stay on-device.
class HighRiskCheckInScheduler {
  /// Fixed id: a new check-in replaces any pending one instead of stacking.
  /// Outside the daily-reminder ids (0–4, 100, 101) so the daily re-sync
  /// never cancels it.
  static const notificationId = 200;

  static const title = 'Checking in on you';
  static const body =
      'Some cravings lately have felt strong. How are you doing right now? '
      'Logging how you feel or trying a short calming activity can help.';

  final CravingLogRepository _cravingLogRepository;
  final UserRepository _userRepository;
  final ReminderSettingsRepository _settingsRepository;
  final ReminderNotificationService _notificationService;
  final CheckInStateStore _stateStore;
  final HighRiskCheckInPolicy _policy;
  final DateTime Function() now;

  HighRiskCheckInScheduler({
    required CravingLogRepository cravingLogRepository,
    required UserRepository userRepository,
    required ReminderSettingsRepository settingsRepository,
    required ReminderNotificationService notificationService,
    CheckInStateStore? stateStore,
    HighRiskCheckInPolicy policy = const HighRiskCheckInPolicy(),
    DateTime Function()? now,
  }) : _cravingLogRepository = cravingLogRepository,
       _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _notificationService = notificationService,
       _stateStore = stateStore ?? SharedPrefsCheckInStateStore(),
       _policy = policy,
       now = now ?? DateTime.now;

  /// Never throws: a check-in is a nice-to-have and must not affect saving
  /// a craving. Returns the decision for logging/tests.
  Future<CheckInDecision?> onCravingLogged(
    String userId,
    CravingLog savedLog,
  ) async {
    try {
      final current = now();
      // Cheap early exit before any I/O.
      final quick = _policy.decide(
        savedLog: savedLog,
        recentLogs: const [],
        now: current,
        remindersEnabled: true,
        permissionGranted: true,
      );
      if (quick.skipReason == CheckInSkipReason.notHighRisk) return quick;

      final recentLogs = await _cravingLogRepository.getRecentLogs(
        userId,
        current.subtract(HighRiskCheckInPolicy.patternWindow),
      );
      final user = await _userRepository.getUser(userId);
      final settings = await _settingsRepository.getSettings();
      final permission = await _notificationService.hasPermission();
      final state = await _stateStore.read(userId);

      final decision = _policy.decide(
        savedLog: savedLog,
        recentLogs: recentLogs,
        now: current,
        remindersEnabled: settings.enabled,
        permissionGranted: permission,
        lastRelapseDate: user?.lastRelapseDate,
        lastCheckInScheduledAt: state.lastScheduledAt,
        lastTriggerLogId: state.lastTriggerLogId,
      );
      if (decision.shouldSchedule) {
        await _notificationService.scheduleOneOffNotification(
          id: notificationId,
          at: decision.scheduleAt!,
          title: title,
          body: body,
        );
        await _stateStore.write(
          userId,
          CheckInState(
            lastScheduledAt: current,
            lastTriggerLogId: savedLog.logId,
          ),
        );
      }
      debugPrint('HighRiskCheckInScheduler: $decision');
      return decision;
    } catch (e) {
      debugPrint('HighRiskCheckInScheduler.onCravingLogged failed: $e');
      return null;
    }
  }

  /// A confirmed relapse cancels any pending check-in (UC9: check-ins are
  /// for high-risk patterns *without* a relapse; the restart-plan flow
  /// takes over instead).
  Future<void> onRelapseLogged(String userId) => _cancel('relapse');

  /// Turning daily reminders off also removes a pending check-in.
  Future<void> onRemindersDisabled() => _cancel('reminders disabled');

  Future<void> _cancel(String why) async {
    try {
      await _notificationService.cancelNotification(notificationId);
    } catch (e) {
      debugPrint('HighRiskCheckInScheduler cancel ($why) failed: $e');
    }
  }
}

/// FR14 (SDD §3, = SRDS FR13): "The system shall send 3 to 5 daily
/// Ecological Momentary Assessment (EMA) prompts... to remind users to
/// log craving levels, mood, and context." No entity is ever defined for
/// this in the SDD/SRDS (unlike CravingLog, JournalEntry, etc.) — this is
/// a new, purely local settings model. Not an SDD-named entity, not
/// synced to Firestore (see ReminderSettingsRepository's doc comment for
/// why this is a deliberately device-local setting).
class ReminderSettings {
  /// On-device daily reminder schedules only.
  final bool enabled;

  /// SRDS's literal "3 to 5 daily" range — the only two numbers ever
  /// specified. Validated to stay within [3, 5] wherever this is set;
  /// see ReminderController.setDailyFrequency.
  final int dailyFrequency;
  final bool habitRemindersEnabled;
  final bool recoveryMotivationEnabled;

  /// Push (FCM) preference. Step 12 (2026-11-23, project owner's decision):
  /// push is the DEFAULT delivery method — daily check-ins are scheduled on
  /// the server and sent by the backend worker over FCM, with on-device
  /// reminders as the automatic fallback when push can't be set up.
  /// Legacy storage name retained for migration.
  final bool remoteDelivery;

  /// Device-local state, not a user choice: true once the server has
  /// confirmed an active push schedule for this device. Lets a temporary
  /// outage keep relying on the server schedule instead of adding local
  /// reminders that would duplicate the pushes.
  final bool remoteScheduleActive;

  const ReminderSettings({
    required this.enabled,
    required this.dailyFrequency,
    this.habitRemindersEnabled = false,
    this.recoveryMotivationEnabled = false,
    this.remoteDelivery = false,
    this.remoteScheduleActive = false,
  });

  /// Push on by default (Step 12). Daily reminders themselves stay off
  /// until the user turns them on (which also asks for permission).
  static const ReminderSettings defaults = ReminderSettings(
    enabled: false,
    dailyFrequency: 4,
    remoteDelivery: true,
  );

  ReminderSettings copyWith({
    bool? enabled,
    int? dailyFrequency,
    bool? habitRemindersEnabled,
    bool? recoveryMotivationEnabled,
    bool? remoteDelivery,
    bool? remoteScheduleActive,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      dailyFrequency: dailyFrequency ?? this.dailyFrequency,
      habitRemindersEnabled:
          habitRemindersEnabled ?? this.habitRemindersEnabled,
      recoveryMotivationEnabled:
          recoveryMotivationEnabled ?? this.recoveryMotivationEnabled,
      remoteDelivery: remoteDelivery ?? this.remoteDelivery,
      remoteScheduleActive: remoteScheduleActive ?? this.remoteScheduleActive,
    );
  }
}

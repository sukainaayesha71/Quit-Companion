import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the app last did about a high-risk check-in, per account. Persisted
/// so duplicate prevention survives app restarts. Device-local, like
/// ReminderSettings: a local notification only exists on this device.
class CheckInState {
  final DateTime? lastScheduledAt;
  final String? lastTriggerLogId;

  const CheckInState({this.lastScheduledAt, this.lastTriggerLogId});

  static const empty = CheckInState();
}

abstract class CheckInStateStore {
  Future<CheckInState> read(String userId);
  Future<void> write(String userId, CheckInState state);
}

class SharedPrefsCheckInStateStore implements CheckInStateStore {
  static String _key(String userId) => 'reminders.highRiskCheckIn.$userId';

  @override
  Future<CheckInState> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return CheckInState.empty;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final at = data['lastScheduledAt'] as String?;
      return CheckInState(
        lastScheduledAt: at == null ? null : DateTime.parse(at),
        lastTriggerLogId: data['lastTriggerLogId'] as String?,
      );
    } catch (_) {
      return CheckInState.empty;
    }
  }

  @override
  Future<void> write(String userId, CheckInState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode({
        'lastScheduledAt': state.lastScheduledAt?.toIso8601String(),
        'lastTriggerLogId': state.lastTriggerLogId,
      }),
    );
  }
}

class InMemoryCheckInStateStore implements CheckInStateStore {
  final Map<String, CheckInState> states = {};

  @override
  Future<CheckInState> read(String userId) async =>
      states[userId] ?? CheckInState.empty;

  @override
  Future<void> write(String userId, CheckInState state) async =>
      states[userId] = state;
}

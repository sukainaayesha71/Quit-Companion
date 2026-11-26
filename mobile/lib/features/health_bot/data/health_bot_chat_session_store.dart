import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when the user last started a New Chat, so the Health-Bot shows
/// (and sends as context) only the messages of the current chat. Earlier
/// conversations stay saved in Firestore exactly as before; this stores only
/// a timestamp on the device and never deletes or changes saved history.
abstract class HealthBotChatSessionStore {
  /// When [userId]'s current chat started, or null if they never started a
  /// new one (then the whole saved history is the current chat, as before).
  Future<DateTime?> chatStartedAt(String userId);

  Future<void> saveChatStartedAt(String userId, DateTime startedAt);
}

/// Device storage (SharedPreferences), per account.
class SharedPreferencesHealthBotChatSessionStore
    implements HealthBotChatSessionStore {
  final Future<SharedPreferences> Function() _getPreferences;

  SharedPreferencesHealthBotChatSessionStore({
    Future<SharedPreferences> Function()? getPreferences,
  }) : _getPreferences = getPreferences ?? SharedPreferences.getInstance;

  static String _key(String userId) => 'healthbot.chat_started_at.$userId';

  @override
  Future<DateTime?> chatStartedAt(String userId) async {
    final raw = (await _getPreferences()).getString(_key(userId));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> saveChatStartedAt(String userId, DateTime startedAt) async {
    await (await _getPreferences()).setString(
      _key(userId),
      startedAt.toIso8601String(),
    );
  }
}

/// In-memory store: the default for tests and anywhere without device
/// storage (a New Chat then lasts until the app restarts).
class InMemoryHealthBotChatSessionStore implements HealthBotChatSessionStore {
  final Map<String, DateTime> _startedAt = {};

  @override
  Future<DateTime?> chatStartedAt(String userId) async => _startedAt[userId];

  @override
  Future<void> saveChatStartedAt(String userId, DateTime startedAt) async {
    _startedAt[userId] = startedAt;
  }
}

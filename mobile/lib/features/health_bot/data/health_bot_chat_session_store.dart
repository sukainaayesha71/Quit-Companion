import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, on this device and per account, which Health-Bot chat is open,
/// so the app reopens the same chat (or the fresh one from New Chat).
/// Conversations themselves are saved in Firestore; this stores only small
/// pointers and never deletes or changes saved history.
abstract class HealthBotChatSessionStore {
  /// The chat to show when the Health-Bot opens; null until the user starts
  /// or opens a chat (then the most recent chat is shown).
  Future<String?> activeChatId(String userId);

  Future<void> saveActiveChatId(String userId, String chatId);

  /// Start of a New Chat made with the build before Chat History (which
  /// stored only a start time). Read so that chat still counts as a separate
  /// conversation; no longer written by the app.
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

  static String _activeKey(String userId) => 'healthbot.active_chat.$userId';
  static String _startedKey(String userId) =>
      'healthbot.chat_started_at.$userId';

  @override
  Future<String?> activeChatId(String userId) async =>
      (await _getPreferences()).getString(_activeKey(userId));

  @override
  Future<void> saveActiveChatId(String userId, String chatId) async {
    await (await _getPreferences()).setString(_activeKey(userId), chatId);
  }

  @override
  Future<DateTime?> chatStartedAt(String userId) async {
    final raw = (await _getPreferences()).getString(_startedKey(userId));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  @override
  Future<void> saveChatStartedAt(String userId, DateTime startedAt) async {
    await (await _getPreferences()).setString(
      _startedKey(userId),
      startedAt.toIso8601String(),
    );
  }
}

/// In-memory store: the default for tests and anywhere without device
/// storage (the open chat is then remembered until the app restarts).
class InMemoryHealthBotChatSessionStore implements HealthBotChatSessionStore {
  final Map<String, String> _active = {};
  final Map<String, DateTime> _startedAt = {};

  @override
  Future<String?> activeChatId(String userId) async => _active[userId];

  @override
  Future<void> saveActiveChatId(String userId, String chatId) async {
    _active[userId] = chatId;
  }

  @override
  Future<DateTime?> chatStartedAt(String userId) async => _startedAt[userId];

  @override
  Future<void> saveChatStartedAt(String userId, DateTime startedAt) async {
    _startedAt[userId] = startedAt;
  }
}

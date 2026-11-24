import 'package:shared_preferences/shared_preferences.dart';

/// Stores only previously-used email addresses, for Login/Register
/// suggestion convenience — never passwords, never OTP codes. Capped and
/// deduplicated (case-insensitive), most recent first.
class RecentEmailStore {
  static const _key = 'recent_emails';
  static const _maxEntries = 5;

  Future<List<String>> getRecentEmails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> addRecentEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? <String>[];
    existing.removeWhere((e) => e.toLowerCase() == trimmed.toLowerCase());
    existing.insert(0, trimmed);
    await prefs.setStringList(_key, existing.take(_maxEntries).toList());
  }
}

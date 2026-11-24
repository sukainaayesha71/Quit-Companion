import 'package:quit_companion/features/journal/models/journal_entry.dart';

/// JournalEntry persistence (SDD §6, Module 5 — Relapse Prevention &
/// Reflection, FR12). Covers both plain reflections and relapse-flagged
/// entries — one unified list, matching the approved UI.
abstract class JournalRepository {
  Future<void> saveEntry(JournalEntry entry);
  Future<void> deleteEntry({required String userId, required String entryId});

  /// All entries for [userId], newest first (matches
  /// docs/UI_Design/journal reflection 13.png's list order).
  Future<List<JournalEntry>> getEntries(String userId);
}

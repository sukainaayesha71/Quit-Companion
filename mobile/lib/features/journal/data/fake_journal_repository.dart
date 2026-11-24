import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/journal/data/journal_repository.dart';

class FakeJournalRepository implements JournalRepository {
  final List<JournalEntry> _entries = [];

  @override
  Future<void> saveEntry(JournalEntry entry) async {
    _entries.removeWhere(
      (item) => item.userId == entry.userId && item.entryId == entry.entryId,
    );
    _entries.add(entry);
  }

  @override
  Future<void> deleteEntry({
    required String userId,
    required String entryId,
  }) async {
    _entries.removeWhere(
      (entry) => entry.userId == userId && entry.entryId == entryId,
    );
  }

  @override
  Future<List<JournalEntry>> getEntries(String userId) async {
    final entries = _entries.where((e) => e.userId == userId).toList();
    entries.sort((a, b) => b.entryDate.compareTo(a.entryDate));
    return entries;
  }
}

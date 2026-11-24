import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/journal/data/journal_repository.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';

enum JournalStatus { idle, loading, loaded, error }

/// FR12 (Module 5): "My Journal" list + plain-reflection creation. The
/// relapse-flagged path is RelapseController's, not this one — this
/// controller only ever writes `relapseFlag: false` entries.
class JournalController extends ChangeNotifier {
  final JournalRepository _journalRepository;
  final DateTime Function() now;

  JournalController(this._journalRepository, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  JournalStatus status = JournalStatus.idle;
  String? errorMessage;
  List<JournalEntry> entries = [];
  bool isMutating = false;

  Future<bool> updateEntry({
    required String userId,
    required JournalEntry entry,
    required String entryText,
  }) async {
    if (isMutating || entry.userId != userId) return false;
    final text = entryText.trim();
    if (text.isEmpty && !entry.relapseFlag) {
      errorMessage = 'Write something before saving.';
      notifyListeners();
      return false;
    }
    return _mutate(
      userId,
      () => _journalRepository.saveEntry(
        JournalEntry(
          entryId: entry.entryId,
          userId: entry.userId,
          entryText: text.isEmpty ? null : text,
          entryDate: entry.entryDate,
          relapseFlag: entry.relapseFlag,
          productUsed: entry.productUsed,
          triggerCategory: entry.triggerCategory,
          mood: entry.mood,
        ),
      ),
    );
  }

  Future<bool> deleteEntry({
    required String userId,
    required JournalEntry entry,
  }) async {
    if (isMutating || entry.userId != userId) return false;
    return _mutate(
      userId,
      () => _journalRepository.deleteEntry(
        userId: userId,
        entryId: entry.entryId,
      ),
    );
  }

  Future<bool> _mutate(String userId, Future<void> Function() operation) async {
    isMutating = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
      entries = await _journalRepository.getEntries(userId);
      status = JournalStatus.loaded;
      return true;
    } catch (error) {
      debugPrint('Journal update failed: $error');
      errorMessage =
          'Could not update your journal. Check your connection and try again.';
      return false;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> loadEntries(String userId) async {
    status = JournalStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      entries = await _journalRepository.getEntries(userId);
      status = JournalStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('JournalController.loadEntries failed: $e');
      errorMessage =
          'Could not load your journal. Check your connection and try again.';
      status = JournalStatus.error;
      notifyListeners();
    }
  }

  Future<bool> addEntry({
    required String userId,
    required String entryText,
  }) async {
    final trimmed = entryText.trim();
    if (trimmed.isEmpty) {
      errorMessage = 'Write something before saving.';
      status = JournalStatus.error;
      notifyListeners();
      return false;
    }
    try {
      final entry = JournalEntry(
        entryId: now().microsecondsSinceEpoch.toString(),
        userId: userId,
        entryText: trimmed,
        entryDate: now(),
      );
      await _journalRepository.saveEntry(entry);
      await loadEntries(userId);
      return true;
    } catch (e) {
      debugPrint('JournalController.addEntry failed: $e');
      errorMessage =
          'Could not save your entry. Check your connection and try again.';
      status = JournalStatus.error;
      notifyListeners();
      return false;
    }
  }
}

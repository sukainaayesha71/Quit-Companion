import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';

void main() {
  final fixedNow = DateTime(2026, 8, 15, 10);

  JournalController buildController(FakeJournalRepository repository) {
    return JournalController(repository, now: () => fixedNow);
  }

  test('loadEntries exposes the user\'s entries, newest first', () async {
    final repository = FakeJournalRepository();
    await repository.saveEntry(
      JournalEntry(
        entryId: 'a',
        userId: 'u1',
        entryDate: DateTime(2026, 8, 1),
        entryText: 'first',
      ),
    );
    await repository.saveEntry(
      JournalEntry(
        entryId: 'b',
        userId: 'u1',
        entryDate: DateTime(2026, 8, 10),
        entryText: 'second',
      ),
    );
    final controller = buildController(repository);

    await controller.loadEntries('u1');

    expect(controller.status, JournalStatus.loaded);
    expect(controller.entries.map((e) => e.entryId), ['b', 'a']);
  });

  test(
    'addEntry saves a plain (non-relapse) reflection and refreshes the list',
    () async {
      final repository = FakeJournalRepository();
      final controller = buildController(repository);

      final success = await controller.addEntry(
        userId: 'u1',
        entryText: 'Feeling good today.',
      );

      expect(success, isTrue);
      expect(controller.entries, hasLength(1));
      expect(controller.entries.first.entryText, 'Feeling good today.');
      expect(controller.entries.first.relapseFlag, isFalse);
      expect(controller.entries.first.entryDate, fixedNow);
    },
  );

  test('addEntry rejects blank text without saving', () async {
    final repository = FakeJournalRepository();
    final controller = buildController(repository);

    final success = await controller.addEntry(userId: 'u1', entryText: '   ');

    expect(success, isFalse);
    expect(await repository.getEntries('u1'), isEmpty);
  });
}

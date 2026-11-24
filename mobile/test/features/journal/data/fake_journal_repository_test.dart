import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  test(
    'getEntries returns an empty list when nothing was ever saved',
    () async {
      final repo = FakeJournalRepository();

      expect(await repo.getEntries('user1'), isEmpty);
    },
  );

  test('saveEntry persists a plain reflection retrievable by userId', () async {
    final repo = FakeJournalRepository();
    final entry = JournalEntry(
      entryId: 'a',
      userId: 'user1',
      entryText: 'Today was tough, but I made it through.',
      entryDate: DateTime(2026, 8, 8),
    );

    await repo.saveEntry(entry);

    final entries = await repo.getEntries('user1');
    expect(entries, hasLength(1));
    expect(entries.first.entryText, 'Today was tough, but I made it through.');
    expect(entries.first.relapseFlag, isFalse);
  });

  test(
    'saveEntry persists a relapse-flagged entry with its structured fields',
    () async {
      final repo = FakeJournalRepository();
      final entry = JournalEntry(
        entryId: 'a',
        userId: 'user1',
        entryDate: DateTime(2026, 8, 8),
        relapseFlag: true,
        productUsed: ProductType.cigarettes,
        triggerCategory: TriggerCategory.stress,
        mood: RelapseMood.guilty,
      );

      await repo.saveEntry(entry);

      final saved = (await repo.getEntries('user1')).single;
      expect(saved.relapseFlag, isTrue);
      expect(saved.productUsed, ProductType.cigarettes);
      expect(saved.triggerCategory, TriggerCategory.stress);
      expect(saved.mood, RelapseMood.guilty);
      expect(
        saved.entryText,
        isNull,
      ); // blank Notes stays null, never auto-composed
    },
  );

  test('getEntries only returns entries for the requested userId', () async {
    final repo = FakeJournalRepository();
    await repo.saveEntry(
      JournalEntry(
        entryId: 'a',
        userId: 'user1',
        entryDate: DateTime(2026, 8, 8),
      ),
    );
    await repo.saveEntry(
      JournalEntry(
        entryId: 'b',
        userId: 'user2',
        entryDate: DateTime(2026, 8, 8),
      ),
    );

    final entries = await repo.getEntries('user1');
    expect(entries, hasLength(1));
    expect(entries.first.userId, 'user1');
  });

  test('getEntries returns entries newest first', () async {
    final repo = FakeJournalRepository();
    await repo.saveEntry(
      JournalEntry(
        entryId: 'earlier',
        userId: 'user1',
        entryDate: DateTime(2026, 8, 1),
      ),
    );
    await repo.saveEntry(
      JournalEntry(
        entryId: 'later',
        userId: 'user1',
        entryDate: DateTime(2026, 8, 10),
      ),
    );

    final entries = await repo.getEntries('user1');
    expect(entries.map((e) => e.entryId), ['later', 'earlier']);
  });
}

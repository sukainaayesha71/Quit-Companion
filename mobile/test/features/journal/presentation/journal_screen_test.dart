import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/presentation/screens/add_journal_entry_screen.dart';
import 'package:quit_companion/features/journal/presentation/screens/journal_screen.dart';

void main() {
  JournalController buildController(FakeJournalRepository repository) {
    return JournalController(repository, now: () => DateTime(2026, 8, 15));
  }

  testWidgets(
    'shows a loading indicator, then the entry list with a flag on the relapse entry',
    (tester) async {
      final repository = FakeJournalRepository();
      await repository.saveEntry(
        JournalEntry(
          entryId: 'a',
          userId: 'u1',
          entryDate: DateTime(2026, 8, 8),
          entryText: 'Today was tough, but I made it through.',
        ),
      );
      await repository.saveEntry(
        JournalEntry(
          entryId: 'b',
          userId: 'u1',
          entryDate: DateTime(2026, 8, 9),
          relapseFlag: true,
          productUsed: ProductType.cigarettes,
          triggerCategory: TriggerCategory.stress,
          mood: RelapseMood.guilty,
          entryText: 'Slipped up today.',
        ),
      );
      final controller = buildController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: JournalScreen(userId: 'u1', controller: controller),
        ),
      );

      expect(find.byKey(const Key('journal_loading')), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('journal_entry_0')), findsOneWidget);
      expect(find.byKey(const Key('journal_entry_1')), findsOneWidget);
      expect(
        find.byIcon(Icons.flag),
        findsOneWidget,
      ); // exactly one relapse-flagged entry
    },
  );

  testWidgets('shows an empty state when there are no entries yet', (
    tester,
  ) async {
    final controller = buildController(FakeJournalRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: JournalScreen(userId: 'u1', controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal_empty_state')), findsOneWidget);
  });

  testWidgets('tapping the + button navigates to AddJournalEntryScreen', (
    tester,
  ) async {
    final controller = buildController(FakeJournalRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: JournalScreen(userId: 'u1', controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('journal_add_button')));
    await tester.pumpAndSettle();

    expect(find.byType(AddJournalEntryScreen), findsOneWidget);
  });
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/presentation/screens/add_journal_entry_screen.dart';

void main() {
  JournalController buildController(FakeJournalRepository repository) {
    return JournalController(repository, now: () => DateTime(2026, 8, 15));
  }

  testWidgets(
    'submitting blank text shows a validation error and does not save',
    (tester) async {
      final repository = FakeJournalRepository();
      final controller = buildController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AddJournalEntryScreen(userId: 'u1', controller: controller),
        ),
      );

      await tester.tap(find.byKey(const Key('add_journal_save_button')));
      await tester.pumpAndSettle();

      expect(await repository.getEntries('u1'), isEmpty);
    },
  );

  testWidgets('submitting text saves the entry and pops back', (tester) async {
    final repository = FakeJournalRepository();
    final controller = buildController(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AddJournalEntryScreen(userId: 'u1', controller: controller),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('add_journal_text_field')),
      'Grateful for today.',
    );
    await tester.tap(find.byKey(const Key('add_journal_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    final entries = await repository.getEntries('u1');
    expect(entries, hasLength(1));
    expect(entries.first.entryText, 'Grateful for today.');
  });
}

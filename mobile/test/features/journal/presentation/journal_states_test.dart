import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/journal/presentation/screens/add_journal_entry_screen.dart';
import 'package:quit_companion/features/journal/presentation/screens/journal_screen.dart';

class _FailingOnceJournalRepo extends FakeJournalRepository {
  int calls = 0;

  @override
  Future<List<JournalEntry>> getEntries(String userId) async {
    calls++;
    if (calls == 1) throw Exception('network down');
    return [
      JournalEntry(
        entryId: 'e1',
        userId: userId,
        entryText: 'Walked instead of smoking after lunch.',
        entryDate: DateTime(2026, 11, 22),
      ),
    ];
  }
}

Future<void> _pump(WidgetTester tester, JournalController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: JournalScreen(userId: 'me', controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty journal shows a helpful empty state with a button', (
    tester,
  ) async {
    await _pump(tester, JournalController(FakeJournalRepository()));

    expect(find.byKey(const Key('journal_empty_state')), findsOneWidget);
    expect(find.text('Your journal is empty'), findsOneWidget);

    await tester.tap(find.byKey(const Key('journal_empty_add_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AddJournalEntryScreen), findsOneWidget);
  });

  testWidgets('a load failure shows an error with Try again, which recovers', (
    tester,
  ) async {
    await _pump(tester, JournalController(_FailingOnceJournalRepo()));

    expect(find.byKey(const Key('journal_error_state')), findsOneWidget);
    expect(find.byKey(const Key('journal_error_text')), findsOneWidget);

    await tester.tap(find.byKey(const Key('journal_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('journal_error_state')), findsNothing);
    expect(
      find.text('Walked instead of smoking after lunch.'),
      findsOneWidget,
    );
  });
}

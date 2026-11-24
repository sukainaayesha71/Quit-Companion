import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/journal/presentation/screens/journal_screen.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/community/presentation/screens/community_screen.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';

class _FailingJournal extends FakeJournalRepository {
  @override
  Future<void> deleteEntry({
    required String userId,
    required String entryId,
  }) async => throw StateError('offline');
}

class _DelayedDeletionJournal extends FakeJournalRepository {
  final deletion = Completer<void>();
  @override
  Future<void> deleteEntry({
    required String userId,
    required String entryId,
  }) async {
    await deletion.future;
    await super.deleteEntry(userId: userId, entryId: entryId);
  }
}

void main() {
  testWidgets(
    'journal menu edits in place and requires confirmation before deleting',
    (tester) async {
      final repository = _DelayedDeletionJournal();
      final date = DateTime(2026, 11, 17);
      await repository.saveEntry(
        JournalEntry(
          entryId: 'entry',
          userId: 'u1',
          entryText: 'Original reflection',
          entryDate: date,
        ),
      );
      final controller = JournalController(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: JournalScreen(userId: 'u1', controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('journal_actions_entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Journal Entry'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('add_journal_text_field')),
        'Updated reflection',
      );
      await tester.tap(find.byKey(const Key('add_journal_save_button')));
      await tester.pumpAndSettle();
      final stored = await repository.getEntries('u1');
      expect(stored, hasLength(1));
      expect(stored.single.entryId, 'entry');
      expect(stored.single.entryDate, date);
      expect(find.text('Updated reflection'), findsOneWidget);
      expect(find.text('Journal entry saved successfully.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('journal_actions_entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await repository.getEntries('u1'), hasLength(1));
      await tester.tap(find.byKey(const Key('journal_confirm_delete')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Deleting journal entry…'), findsOneWidget);
      expect(find.text('Journal entry deleted successfully.'), findsNothing);
      repository.deletion.complete();
      await tester.pumpAndSettle();
      expect(await repository.getEntries('u1'), isEmpty);
      expect(find.byKey(const Key('journal_empty_state')), findsOneWidget);
      expect(find.text('Journal entry deleted successfully.'), findsOneWidget);
    },
  );

  test(
    'editing relapse notes preserves its date and relapse metadata',
    () async {
      final repository = FakeJournalRepository();
      final entry = JournalEntry(
        entryId: 'r',
        userId: 'u1',
        entryText: 'Old note',
        entryDate: DateTime(2026),
        relapseFlag: true,
        productUsed: ProductType.cigarettes,
        triggerCategory: TriggerCategory.stress,
        mood: RelapseMood.guilty,
      );
      await repository.saveEntry(entry);
      final controller = JournalController(repository);
      expect(
        await controller.updateEntry(
          userId: 'u1',
          entry: entry,
          entryText: 'New note',
        ),
        isTrue,
      );
      final saved = (await repository.getEntries('u1')).single;
      expect(saved.relapseFlag, isTrue);
      expect(saved.productUsed, ProductType.cigarettes);
      expect(saved.triggerCategory, TriggerCategory.stress);
      expect(saved.mood, RelapseMood.guilty);
      expect(saved.entryDate, entry.entryDate);
      expect(
        await controller.deleteEntry(userId: 'other-user', entry: entry),
        isFalse,
      );
    },
  );

  test(
    'failed journal deletion retains the entry and exposes an error',
    () async {
      final repository = _FailingJournal();
      final entry = JournalEntry(
        entryId: 'j',
        userId: 'u1',
        entryText: 'Keep this',
        entryDate: DateTime(2026),
      );
      await repository.saveEntry(entry);
      final controller = JournalController(repository);
      await controller.loadEntries('u1');
      expect(await controller.deleteEntry(userId: 'u1', entry: entry), isFalse);
      expect(controller.entries, hasLength(1));
      expect(controller.errorMessage, isNotNull);
      expect(controller.isMutating, isFalse);
    },
  );

  testWidgets(
    'community delete is visible only for own posts and honors cancellation',
    (tester) async {
      final repository = FakeCommunityPostRepository();
      for (final id in ['u1', 'u2']) {
        await repository.createPost(
          CommunityPost(
            postId: id,
            userId: id,
            anonymizedUsername: 'Peer',
            content: 'Post by $id',
            category: PostCategory.tip,
            timestamp: DateTime(2026),
          ),
        );
      }
      final controller = CommunityController(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityScreen(userId: 'u1', controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community_delete_u1')), findsOneWidget);
      expect(find.byKey(const Key('community_delete_u2')), findsNothing);
      await tester.tap(find.byKey(const Key('community_delete_u1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.posts, hasLength(2));
      await tester.tap(find.byKey(const Key('community_delete_u1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('community_confirm_delete')));
      await tester.pumpAndSettle();
      expect(repository.posts.single.userId, 'u2');
      expect(find.text('Post by u1'), findsNothing);
      expect(find.text('Post by u2'), findsOneWidget);
      expect(find.text('Post deleted successfully.'), findsOneWidget);
    },
  );
}

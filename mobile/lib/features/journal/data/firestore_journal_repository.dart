import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/data/journal_repository.dart';
import 'package:quit_companion/shared/data/content_deletion_client.dart';

/// Real Firestore implementation (SDD §6, Module 5), mirrors
/// FirestoreCravingLogRepository's per-user-subcollection pattern:
/// nicotineUsers/{userId}/journalEntries/{entryId}. Requires the matching
/// Firestore rules subcollection block (see Module 5 plan Task 8).
class FirestoreJournalRepository implements JournalRepository {
  final FirebaseFirestore _firestore;
  // Existing repository instances survive hot reload without rerunning the
  // constructor, so initialize the deletion client on first use as well.
  ContentDeletionClient? _deletionClient;

  FirestoreJournalRepository({
    FirebaseFirestore? firestore,
    ContentDeletionClient? deletionClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _deletionClient = deletionClient;

  @override
  Future<void> deleteEntry({required String userId, required String entryId}) =>
      (_deletionClient ??= ContentDeletionClient()).delete(
        '/journal/entries/${Uri.encodeComponent(entryId)}',
      );

  CollectionReference<Map<String, dynamic>> _entriesFor(String userId) =>
      _firestore
          .collection('nicotineUsers')
          .doc(userId)
          .collection('journalEntries');

  @override
  Future<void> saveEntry(JournalEntry entry) async {
    await _entriesFor(entry.userId).doc(entry.entryId).set({
      'entryText': entry.entryText,
      'entryDate': entry.entryDate.toIso8601String(),
      'relapseFlag': entry.relapseFlag,
      'productUsed': entry.productUsed?.name,
      'triggerCategory': entry.triggerCategory?.name,
      'mood': entry.mood?.name,
    });
  }

  @override
  Future<List<JournalEntry>> getEntries(String userId) async {
    final snapshot = await _entriesFor(
      userId,
    ).orderBy('entryDate', descending: true).get();
    // One malformed entry must not hide the whole journal: skip and log it.
    final entries = <JournalEntry>[];
    for (final doc in snapshot.docs) {
      try {
        entries.add(_fromDoc(userId, doc.id, doc.data()));
      } catch (e) {
        debugPrint('Skipping malformed journal entry ${doc.id}: $e');
      }
    }
    return entries;
  }

  JournalEntry _fromDoc(
    String userId,
    String entryId,
    Map<String, dynamic> data,
  ) {
    return JournalEntry(
      entryId: entryId,
      userId: userId,
      entryText: data['entryText'] as String?,
      entryDate: DateTime.parse(data['entryDate'] as String),
      relapseFlag: data['relapseFlag'] as bool? ?? false,
      productUsed: _parseEnum(
        ProductType.values,
        data['productUsed'] as String?,
      ),
      triggerCategory: _parseEnum(
        TriggerCategory.values,
        data['triggerCategory'] as String?,
      ),
      mood: _parseEnum(RelapseMood.values, data['mood'] as String?),
    );
  }

  T? _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

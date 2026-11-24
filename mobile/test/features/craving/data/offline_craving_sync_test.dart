import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/craving/data/craving_log_codec.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/offline_craving_log_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/presentation/screens/craving_history_screen.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';

/// Stand-in for Firestore: documents keyed by logId, so a repeated write of
/// the same craving overwrites (like `doc(logId).set()`), never duplicates.
/// [online] simulates connectivity; [ackLost] applies a write but then
/// fails, like a dropped connection before the server's acknowledgement.
class _Server implements CravingLogRepository {
  final Map<String, CravingLog> docs = {};
  bool online = false;
  int historyReads = 0;
  bool ackLost = false;
  int writes = 0;
  Completer<void>? gate;

  void _check() {
    if (!online) throw StateError('offline');
  }

  @override
  Future<void> logCraving(CravingLog log) async {
    _check();
    if (gate != null) await gate!.future;
    writes++;
    docs[log.logId] = log;
    if (ackLost) throw TimeoutException('ack lost');
  }

  @override
  Future<List<CravingLog>> getRecentLogs(String userId, DateTime since) async {
    historyReads++;
    _check();
    return docs.values
        .where((l) => l.userId == userId && !l.timestamp.isBefore(since))
        .toList();
  }

  @override
  Future<void> deleteLog({
    required String userId,
    required String logId,
  }) async {
    _check();
    docs.remove(logId);
  }

  @override
  Future<int> countLoggedSince(String userId, DateTime since) async =>
      (await getRecentLogs(userId, since)).length;

  @override
  Future<int> countCravingsResistedSince(String userId, DateTime since) =>
      countLoggedSince(userId, since);
}

CravingLog _craving(String id, {DateTime? at, String user = 'u1'}) =>
    CravingLog(
      logId: id,
      userId: user,
      cravingIntensity: 7,
      mood: Mood.bored,
      triggerCategory: TriggerCategory.boredom,
      locationContext: 'Home',
      activity: 'Resting',
      notes: 'After dinner',
      timestamp: at ?? DateTime(2026, 11, 20, 21, 15, 42),
      relapseRiskScore: RelapseRiskLevel.medium,
      riskAssessmentPending: true,
      moodAnxious: 6,
      moodSad: 3,
    );

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('UC3 offline craving synchronization', () {
    test(
      'offline: the craving is saved locally, visible, and marked pending',
      () async {
        final server = _Server();
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);

        await repo.logCraving(_craving('a'));
        await _settle();

        expect(server.docs, isEmpty);
        final local = await repo.getRecentLogs('u1', DateTime(2026));
        expect(local.map((l) => l.logId), ['a']);
        expect(await repo.pendingSyncLogIds('u1'), {'a'});
      },
    );

    test(
      'reconnect: pending entries sync with original timestamp and details, then clear',
      () async {
        final server = _Server();
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);
        final original = _craving('a');
        await repo.logCraving(original);
        await _settle();

        final changes = <void>[];
        final sub = repo.watchChanges('u1').listen(changes.add);
        addTearDown(sub.cancel);
        server.online = true;
        await repo.flush('u1');
        await _settle();

        final synced = server.docs['a']!;
        expect(encodeCraving(synced), encodeCraving(original));
        expect(synced.timestamp, DateTime(2026, 11, 20, 21, 15, 42));
        expect(await repo.pendingSyncLogIds('u1'), isEmpty);
        expect(changes, isNotEmpty, reason: 'UI is told the entry synced');
      },
    );

    test(
      'app reopen: a new repository instance syncs the stored outbox on first read',
      () async {
        final server = _Server();
        final first = OfflineCravingLogRepository(server);
        await first.logCraving(_craving('a'));
        await first.logCraving(_craving('b', at: DateTime(2026, 11, 21, 8)));
        first.dispose(); // app closed while still offline

        server.online = true;
        final reopened = OfflineCravingLogRepository(server);
        addTearDown(reopened.dispose);
        final logs = await reopened.getRecentLogs('u1', DateTime(2026));
        await _settle();

        expect(logs.map((l) => l.logId).toSet(), {'a', 'b'});
        expect(server.docs.keys.toSet(), {'a', 'b'});
        expect(await reopened.pendingSyncLogIds('u1'), isEmpty);
      },
    );

    test(
      'no duplicates: repeated flushes and a lost acknowledgement leave one record',
      () async {
        final server = _Server()
          ..online = true
          ..ackLost = true;
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);

        await repo.logCraving(_craving('a'));
        await _settle();
        // Written but not acknowledged: stays queued.
        expect(server.docs.keys, ['a']);
        expect(await repo.pendingSyncLogIds('u1'), {'a'});

        server.ackLost = false;
        await Future.wait([
          repo.flush('u1'),
          repo.flush('u1'),
          repo.flush('u1'),
        ]);
        await repo.flush('u1');
        await _settle();

        expect(server.docs, hasLength(1));
        expect(await repo.pendingSyncLogIds('u1'), isEmpty);
        final all = await repo.getRecentLogs('u1', DateTime(2026));
        expect(all.where((l) => l.logId == 'a'), hasLength(1));
      },
    );

    test(
      'failure: the outbox survives server errors and syncs on a later retry',
      () async {
        final server = _Server();
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);

        await repo.logCraving(_craving('a'));
        await repo.flush('u1');
        await repo.flush('u1');
        expect(await repo.pendingSyncLogIds('u1'), {'a'});

        server.online = true;
        await repo.flush('u1');
        expect(server.docs.keys, ['a']);
        expect(await repo.pendingSyncLogIds('u1'), isEmpty);
      },
    );

    test(
      'an unreadable queued entry is kept but does not block valid entries',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'craving.outbox.u1': jsonEncode({
            'corrupt': {'logId': 'corrupt', 'mood': 'not-a-mood'},
            'good': encodeCraving(_craving('good')),
          }),
        });
        final server = _Server()..online = true;
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);

        await repo.flush('u1');

        expect(server.docs.keys, ['good']);
        expect(await repo.pendingSyncLogIds('u1'), {'corrupt'});
      },
    );

    test(
      'a craving saved while a sync is in progress is sent in the same run',
      () async {
        final server = _Server()
          ..online = true
          ..gate = Completer<void>();
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);

        await repo.logCraving(_craving('a')); // starts a flush, blocked at gate
        await _settle();
        await repo.logCraving(_craving('b', at: DateTime(2026, 11, 21)));
        server.gate!.complete();
        server.gate = null;
        await _settle();

        expect(server.docs.keys.toSet(), {'a', 'b'});
        expect(await repo.pendingSyncLogIds('u1'), isEmpty);
      },
    );

    test('pending entries are scoped to their account', () async {
      final repo = OfflineCravingLogRepository(_Server());
      addTearDown(repo.dispose);
      await repo.logCraving(_craving('a'));
      await repo.logCraving(_craving('b', user: 'u2'));

      expect(await repo.pendingSyncLogIds('u1'), {'a'});
      expect(await repo.pendingSyncLogIds('u2'), {'b'});
    });
  });

  group('UC3 end to end', () {
    test(
      'Log Craving succeeds offline: saved with a pending assessment',
      () async {
        final server = _Server();
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);
        final controller = CravingLogController(
          repo,
          FakeRelapsePredictionClient(fail: true),
        );

        final ok = await controller.submitCraving(
          userId: 'u1',
          intensity: 8,
          mood: Mood.stressed,
          triggerCategory: TriggerCategory.stress,
          locationContext: 'Work',
          activity: 'Working/studying',
        );

        expect(ok, isTrue);
        expect(controller.status, CravingLogStatus.success);
        expect(controller.assessmentPending, isTrue);
        expect(await repo.pendingSyncLogIds('u1'), hasLength(1));
        expect(server.docs, isEmpty);
      },
    );

    testWidgets(
      'Craving History marks entries waiting to sync, and clears the mark once synced',
      (tester) async {
        final server = _Server();
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);
        final users = FakeUserRepository();
        final controller = TrackController(
          repo,
          FakeJournalRepository(),
          users,
        );

        await tester.runAsync(() async {
          await users.saveUser(
            NicotineUser(
              userId: 'u1',
              email: 'a@b.com',
              quitStrategy: QuitStrategy.coldTurkey,
              quitDate: DateTime(2026, 11, 1),
              baselineDailyUsage: 10,
              costPerUnit: 2,
            ),
          );
          await repo.logCraving(_craving('a'));
          await controller.loadTrack('u1');
        });
        await tester.pumpWidget(
          MaterialApp(
            home: CravingHistoryScreen(userId: 'u1', controller: controller),
          ),
        );
        await tester.runAsync(() => controller.loadTrack('u1'));
        await tester.pump();

        expect(find.byKey(const Key('craving_pending_sync_a')), findsOneWidget);
        expect(
          find.text('Saved on this device · waiting to sync'),
          findsOneWidget,
        );

        await tester.runAsync(() async {
          server.online = true;
          await repo.flush('u1');
          await controller.loadTrack('u1');
        });
        await tester.pump();

        expect(find.byKey(const Key('craving_pending_sync_a')), findsNothing);
        expect(controller.cravingHistory.map((l) => l.logId), ['a']);
      },
    );
  });

  group('Step 13 shared remote snapshot', () {
    test('overlapping reads share one history download', () async {
      final server = _Server()..online = true;
      final repo = OfflineCravingLogRepository(server);
      addTearDown(repo.dispose);

      await Future.wait([
        repo.getRecentLogs('u1', DateTime(2026)),
        repo.countLoggedSince('u1', DateTime(2026)),
        repo.countCravingsResistedSince('u1', DateTime(2026)),
      ]);

      expect(server.historyReads, 1);
    });

    test(
      'a sync drops the snapshot so the synced entry stays visible',
      () async {
        final server = _Server()..online = true;
        final repo = OfflineCravingLogRepository(server);
        addTearDown(repo.dispose);
        await repo.getRecentLogs('u1', DateTime(2026)); // snapshot (empty)
        server.online = false;
        await repo.logCraving(_craving('a'));
        await _settle();
        server.online = true;
        await repo.flush('u1'); // moves 'a' outbox -> server

        final logs = await repo.getRecentLogs('u1', DateTime(2026));
        expect(logs.map((l) => l.logId), ['a']);
        expect(await repo.pendingSyncLogIds('u1'), isEmpty);
      },
    );

    test('a failed download is not reused, and the snapshot expires', () async {
      var clock = DateTime(2026, 11, 23, 12);
      final server = _Server();
      final repo = OfflineCravingLogRepository(server, now: () => clock);
      addTearDown(repo.dispose);

      await repo.getRecentLogs('u1', DateTime(2026)); // offline: fails
      server.online = true;
      await repo.getRecentLogs('u1', DateTime(2026)); // retried
      final afterRetry = server.historyReads;
      await repo.getRecentLogs('u1', DateTime(2026)); // within TTL: reused
      expect(server.historyReads, afterRetry);

      clock = clock.add(OfflineCravingLogRepository.remoteSnapshotTtl);
      await repo.getRecentLogs('u1', DateTime(2026)); // expired: refetched
      expect(server.historyReads, afterRetry + 1);
    });
  });
}

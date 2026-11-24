import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quit_companion/features/craving/data/craving_log_codec.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';

/// Encrypted, per-account outbox. A successful submission means it is
/// durably stored locally; only acknowledged writes leave the queue.
///
/// UC3 offline craving synchronization:
/// - every craving is written to the outbox + local cache first, then sent;
/// - sync runs after each save, every 15 s while the app is in use, and
///   whenever logs are read (the Dashboard reads them on every app open);
/// - Firestore documents use the craving's own id, so a retried write
///   overwrites rather than duplicates, and an entry leaves the outbox only
///   if it is unchanged since it was sent;
/// - the original timestamp and every field travel in the encoded entry.
class OfflineCravingLogRepository
    implements
        CravingLogRepository,
        LiveCravingLogRepository,
        SyncStatusCravingLogRepository {
  final CravingLogRepository remote;
  final FlutterSecureStorage storage;
  final _changes = StreamController<String>.broadcast();
  final _users = <String>{};
  final _flushing = <String>{};

  /// A flush was requested while one was already running for this user:
  /// run another pass afterwards so the new entry isn't left waiting for
  /// the next 15-second retry.
  final _flushAgain = <String>{};
  final _queues = <String, Future<void>>{};
  late final Timer _retry = Timer.periodic(const Duration(seconds: 15), (_) {
    for (final user in _users) {
      unawaited(flush(user));
    }
  });

  OfflineCravingLogRepository(
    this.remote, {
    this.storage = const FlutterSecureStorage(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Step 13: one remote history download shared by overlapping callers.
  /// A Dashboard load asks for craving data three ways (resisted count,
  /// recent logs, today's count) and the Rewards load asks again; each used
  /// to download the whole history separately. The shared snapshot lives
  /// for [remoteSnapshotTtl] and is dropped as soon as a sync moves entries
  /// from the outbox to the server, so a synced entry can never briefly
  /// disappear. Unsynced local entries are always overlaid on top.
  static const remoteSnapshotTtl = Duration(seconds: 5);
  final _remoteSnapshots =
      <String, ({DateTime at, Future<List<CravingLog>> logs})>{};

  Future<List<CravingLog>> _remoteHistory(String user) {
    final cached = _remoteSnapshots[user];
    if (cached != null && _now().difference(cached.at) < remoteSnapshotTtl) {
      return cached.logs;
    }
    final logs = remote
        .getRecentLogs(user, DateTime(1970))
        .timeout(const Duration(seconds: 2));
    final entry = (at: _now(), logs: logs);
    _remoteSnapshots[user] = entry;
    // A failed download must not be reused: drop it so the next call retries.
    logs.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_remoteSnapshots[user], entry)) {
          _remoteSnapshots.remove(user);
        }
      },
    );
    return logs;
  }

  Future<Map<String, dynamic>> _read(String key) async {
    final value = await storage.read(key: key);
    return value == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> _serialize(String user, Future<void> Function() operation) {
    final next = (_queues[user] ?? Future.value())
        .catchError((Object _) {})
        .then((_) => operation());
    _queues[user] = next;
    return next;
  }

  @override
  Future<void> logCraving(CravingLog log) async {
    _users.add(log.userId);
    _retry; // Start retries only when this repository is used.
    await _serialize(log.userId, () async {
      final queue = await _read('craving.outbox.${log.userId}');
      queue[log.logId] = encodeCraving(log);
      await storage.write(
        key: 'craving.outbox.${log.userId}',
        value: jsonEncode(queue),
      );
      final cache = await _read('craving.cache.${log.userId}');
      cache[log.logId] = encodeCraving(log);
      await storage.write(
        key: 'craving.cache.${log.userId}',
        value: jsonEncode(cache),
      );
    });
    _changes.add(log.userId);
    unawaited(flush(log.userId));
  }

  Future<void> flush(String user) async {
    if (!_flushing.add(user)) {
      _flushAgain.add(user);
      return;
    }
    var synced = false;
    try {
      do {
        _flushAgain.remove(user);
        synced = await _flushOnce(user) || synced;
      } while (_flushAgain.contains(user));
    } catch (_) {
      // Network/remote failure: keep the outbox intact and retry later
      // (next save, next read, or the 15-second timer).
    } finally {
      _flushing.remove(user);
      _flushAgain.remove(user);
      if (synced) _remoteSnapshots.remove(user);
      // Lets the Dashboard/history refresh "waiting to sync" markers.
      if (synced && !_changes.isClosed) _changes.add(user);
    }
  }

  /// One pass over a snapshot of the outbox. Returns whether anything was
  /// confirmed. A remote failure stops the pass (the remaining entries
  /// would fail the same way); an entry that can't be decoded is skipped
  /// — kept, never deleted — so it can't block the others.
  Future<bool> _flushOnce(String user) async {
    var synced = false;
    final snapshot = await _read('craving.outbox.$user');
    for (final entry in snapshot.entries) {
      final Map<String, dynamic> data;
      CravingLog? log;
      try {
        data = Map<String, dynamic>.from(entry.value as Map);
        if (data['_deleted'] != true) log = decodeCraving(data);
      } catch (error) {
        debugPrint('Skipping unreadable offline craving ${entry.key}: $error');
        continue;
      }
      if (log == null) {
        await remote
            .deleteLog(userId: user, logId: entry.key)
            .timeout(const Duration(seconds: 5));
      } else {
        await remote.logCraving(log).timeout(const Duration(seconds: 5));
      }
      await _serialize(user, () async {
        final current = await _read('craving.outbox.$user');
        if (jsonEncode(current[entry.key]) == jsonEncode(entry.value)) {
          current.remove(entry.key);
          await storage.write(
            key: 'craving.outbox.$user',
            value: jsonEncode(current),
          );
        }
      });
      synced = true;
    }
    return synced;
  }

  @override
  Future<Set<String>> pendingSyncLogIds(String userId) async {
    final outbox = await _read('craving.outbox.$userId');
    return {
      for (final entry in outbox.entries)
        if (entry.value is Map && (entry.value as Map)['_deleted'] != true)
          entry.key,
    };
  }

  @override
  Future<List<CravingLog>> getRecentLogs(String user, DateTime since) async {
    _users.add(user);
    _retry;
    unawaited(flush(user));
    Map<String, dynamic> cached = await _read('craving.cache.$user');
    try {
      final logs = await _remoteHistory(user);
      cached = {for (final log in logs) log.logId: encodeCraving(log)};
      await storage.write(
        key: 'craving.cache.$user',
        value: jsonEncode(cached),
      );
    } catch (_) {
      /* Use the last account-scoped cache while offline. */
    }
    final pending = await _read('craving.outbox.$user');
    cached.addAll(pending);
    return cached.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) => v['_deleted'] != true)
        .map(decodeCraving)
        .where((log) => !log.timestamp.isBefore(since))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<int> countLoggedSince(String userId, DateTime since) async =>
      (await getRecentLogs(userId, since)).length;
  @override
  Future<int> countCravingsResistedSince(String userId, DateTime since) =>
      countLoggedSince(userId, since);

  @override
  Future<void> deleteLog({
    required String userId,
    required String logId,
  }) async {
    await _serialize(userId, () async {
      final queue = await _read('craving.outbox.$userId');
      queue[logId] = {'_deleted': true};
      await storage.write(
        key: 'craving.outbox.$userId',
        value: jsonEncode(queue),
      );
      final cache = await _read('craving.cache.$userId');
      cache.remove(logId);
      await storage.write(
        key: 'craving.cache.$userId',
        value: jsonEncode(cache),
      );
    });
    _changes.add(userId);
    unawaited(flush(userId));
  }

  @override
  Stream<void> watchChanges(String userId) => Stream<void>.multi((controller) {
    final local = _changes.stream
        .where((user) => user == userId)
        .listen((_) => controller.add(null));
    final source = remote;
    final subscription = source is LiveCravingLogRepository
        ? (source as LiveCravingLogRepository)
              .watchChanges(userId)
              .listen((_) => controller.add(null), onError: controller.addError)
        : null;
    controller.onCancel = () async {
      await local.cancel();
      await subscription?.cancel();
    };
  });

  void dispose() {
    _retry.cancel();
    unawaited(_changes.close());
  }

  Future<void> clearUser(String userId) async {
    _users.remove(userId);
    _remoteSnapshots.remove(userId);
    await _serialize(userId, () async {
      await storage.delete(key: 'craving.outbox.$userId');
      await storage.delete(key: 'craving.cache.$userId');
    });
  }
}

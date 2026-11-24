import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/reminders/data/fcm_token_repository.dart';
import 'package:quit_companion/features/reminders/data/fcm_token_sync.dart';

void main() {
  test(
    'disabling uses the cached token without waiting for token retrieval',
    () async {
      final repository = _FakeTokenRepository();
      final cache = _FakeTokenCache()..tokens['u1'] = 'cached-token';
      var tokenRequests = 0;
      final sync = FcmTokenSync(
        repository: repository,
        cache: cache,
        currentUserId: () => 'u1',
        getToken: () {
          tokenRequests++;
          return Completer<String?>().future;
        },
        tokenRefreshes: const Stream<String>.empty(),
      );
      await sync.disable();
      expect(tokenRequests, 0);
      expect(repository.deleted, [('u1', 'cached-token')]);
      expect(cache.tokens, isEmpty);
    },
  );

  test(
    'failed token removal can be retried without losing the cache',
    () async {
      final repository = _FakeTokenRepository()..failDelete = true;
      final cache = _FakeTokenCache()..tokens['u1'] = 'cached-token';
      final sync = FcmTokenSync(
        repository: repository,
        cache: cache,
        currentUserId: () => 'u1',
        getToken: () async => null,
        tokenRefreshes: const Stream<String>.empty(),
      );
      await expectLater(sync.disable(), throwsStateError);
      expect(cache.tokens['u1'], 'cached-token');
      repository.failDelete = false;
      await sync.disable();
      expect(cache.tokens, isEmpty);
      expect(repository.deleted, [('u1', 'cached-token')]);
    },
  );
  group('FcmTokenSync', () {
    late _FakeTokenRepository repository;
    late _FakeTokenCache cache;
    late StreamController<String> refreshes;
    late String? userId;
    late String? currentToken;
    late FcmTokenSync sync;

    setUp(() {
      repository = _FakeTokenRepository();
      cache = _FakeTokenCache();
      refreshes = StreamController<String>.broadcast();
      userId = 'user-123';
      currentToken = 'token-1';
      sync = FcmTokenSync(
        repository: repository,
        cache: cache,
        currentUserId: () => userId,
        getToken: () async => currentToken,
        tokenRefreshes: refreshes.stream,
      );
    });

    tearDown(() async {
      await sync.disable();
      await refreshes.close();
    });

    test(
      'registers current and refreshed tokens for the signed-in user',
      () async {
        await sync.enable();

        expect(repository.saved, [('user-123', 'token-1')]);

        currentToken = 'token-2';
        refreshes.add('token-2');
        await Future<void>.delayed(Duration.zero);

        expect(repository.deleted, [('user-123', 'token-1')]);
        expect(repository.saved.last, ('user-123', 'token-2'));
      },
    );

    test('replaces a previously cached token after app restart', () async {
      cache.tokens['user-123'] = 'old-token';
      currentToken = 'new-token';

      await sync.enable();

      expect(repository.deleted, [('user-123', 'old-token')]);
      expect(repository.saved, [('user-123', 'new-token')]);
      expect(cache.tokens['user-123'], 'new-token');
    });

    test(
      'registers only enabled notification categories for the account',
      () async {
        await sync.enable(
          habitRemindersEnabled: true,
          recoveryMotivationEnabled: false,
        );

        expect(repository.notificationTypes, [
          'daily_checkin',
          'habit_reminder',
        ]);
      },
    );

    test('does not save a token when there is no signed-in user', () async {
      userId = null;

      await sync.enable();

      expect(repository.saved, isEmpty);
    });

    test(
      'deletes the registered token when disabled and stops refresh writes',
      () async {
        await sync.enable();

        await sync.disable();
        refreshes.add('token-after-disable');
        await Future<void>.delayed(Duration.zero);

        expect(repository.deleted, [('user-123', 'token-1')]);
        expect(repository.saved, [('user-123', 'token-1')]);
      },
    );
  });

  test('Firestore token document IDs do not expose the token', () {
    const token = 'token/with+symbols';
    final id = FirestoreFcmTokenRepository.documentIdForToken(token);

    expect(id, isNot(contains('/')));
    expect(id, isNot(contains(token)));
    expect(id, sha256.convert(utf8.encode(token)).toString());
  });
}

class _FakeTokenCache implements FcmTokenCache {
  final Map<String, String> tokens = {};

  @override
  Future<String?> read(String userId) async => tokens[userId];

  @override
  Future<void> write(String userId, String token) async {
    tokens[userId] = token;
  }

  @override
  Future<void> delete(String userId) async {
    tokens.remove(userId);
  }
}

class _FakeTokenRepository implements FcmTokenRepository {
  bool failDelete = false;
  final List<(String, String)> saved = [];
  final List<(String, String)> deleted = [];
  List<String> notificationTypes = [];

  @override
  Future<void> saveToken(
    String userId,
    String token, {
    List<String> notificationTypes = const ['daily_checkin'],
  }) async {
    saved.add((userId, token));
    this.notificationTypes = notificationTypes;
  }

  @override
  Future<void> deleteToken(String userId, String token) async {
    if (failDelete) throw StateError('offline');
    deleted.add((userId, token));
  }
}

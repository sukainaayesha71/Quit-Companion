import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit_companion/features/reminders/data/fcm_token_repository.dart';

abstract class FcmTokenCache {
  Future<String?> read(String userId);

  Future<void> write(String userId, String token);

  Future<void> delete(String userId);
}

class SharedPreferencesFcmTokenCache implements FcmTokenCache {
  static const _keyPrefix = 'reminders.fcmToken.';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<String?> read(String userId) async =>
      (await _preferences).getString('$_keyPrefix$userId');

  @override
  Future<void> write(String userId, String token) async {
    await (await _preferences).setString('$_keyPrefix$userId', token);
  }

  @override
  Future<void> delete(String userId) async {
    await (await _preferences).remove('$_keyPrefix$userId');
  }
}

class FcmTokenSync {
  final FcmTokenRepository _repository;
  final FcmTokenCache _cache;
  final String? Function() _currentUserId;
  final Future<String?> Function() _getToken;
  final Stream<String> _tokenRefreshes;

  StreamSubscription<String>? _refreshSubscription;
  String? _lastUserId;
  String? _lastToken;
  bool _enabled = false;
  bool _habitRemindersEnabled = false;
  bool _recoveryMotivationEnabled = false;

  FcmTokenSync({
    required FcmTokenRepository repository,
    required FcmTokenCache cache,
    required String? Function() currentUserId,
    required Future<String?> Function() getToken,
    required Stream<String> tokenRefreshes,
  }) : _repository = repository,
       _cache = cache,
       _currentUserId = currentUserId,
       _getToken = getToken,
       _tokenRefreshes = tokenRefreshes;

  Future<void> enable({
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
    bool requireRegistration = false,
  }) async {
    _enabled = true;
    _habitRemindersEnabled = habitRemindersEnabled;
    _recoveryMotivationEnabled = recoveryMotivationEnabled;
    _refreshSubscription ??= _tokenRefreshes.listen(
      (token) => unawaited(_register(token)),
      onError: (Object error) => debugPrint('FCM token refresh failed: $error'),
    );
    try {
      final token = await _getToken().timeout(const Duration(seconds: 5));
      if (token != null) await _register(token);
      if (requireRegistration &&
          (token == null ||
              token.isEmpty ||
              _lastToken != token ||
              _lastUserId != _currentUserId())) {
        throw StateError('Push registration could not be completed.');
      }
    } catch (error) {
      debugPrint('Could not read the FCM token: $error');
      if (requireRegistration) {
        _enabled = false;
        await _refreshSubscription?.cancel();
        _refreshSubscription = null;
        rethrow;
      }
    }
  }

  Future<void> disable() async {
    _enabled = false;
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;

    final userId = _currentUserId();
    if (userId == null) return;
    final cachedToken = _lastUserId == userId
        ? _lastToken
        : await _cache.read(userId);
    // Fetching a new token may wait on Google Play services indefinitely.
    // The cached registration is sufficient to remove this device's token.
    final currentToken = cachedToken == null ? await _readToken() : null;
    final tokens = {?cachedToken, ?currentToken};
    var removedAll = true;
    for (final token in tokens) {
      if (token.isEmpty) continue;
      try {
        await _repository
            .deleteToken(userId, token)
            .timeout(const Duration(seconds: 5));
      } catch (error) {
        removedAll = false;
        debugPrint('Could not remove the FCM token: $error');
      }
    }
    if (removedAll) {
      await _cache.delete(userId);
      if (_lastUserId == userId) {
        _lastUserId = null;
        _lastToken = null;
      }
    } else {
      throw StateError(
        'Could not finish disabling push delivery. Please try again.',
      );
    }
  }

  Future<String?> _readToken() async {
    try {
      return await _getToken().timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Could not read the FCM token for removal: $error');
      return null;
    }
  }

  Future<void> _register(String token) async {
    final userId = _currentUserId();
    if (!_enabled || userId == null || token.isEmpty) return;
    try {
      final previousToken = _lastUserId == userId
          ? _lastToken
          : await _cache.read(userId);
      if (previousToken != null && previousToken != token) {
        await _repository
            .deleteToken(userId, previousToken)
            .timeout(const Duration(seconds: 5));
      }
      await _repository
          .saveToken(
            userId,
            token,
            notificationTypes: [
              'daily_checkin',
              if (_habitRemindersEnabled) 'habit_reminder',
              if (_recoveryMotivationEnabled) 'recovery_motivation',
            ],
          )
          .timeout(const Duration(seconds: 5));
      await _cache.write(userId, token);
      _lastUserId = userId;
      _lastToken = token;
    } catch (error) {
      debugPrint('Could not register the FCM token: $error');
    }
  }
}

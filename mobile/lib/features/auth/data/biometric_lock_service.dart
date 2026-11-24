import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricSignInCredentials {
  final String email;
  final String password;

  const BiometricSignInCredentials({
    required this.email,
    required this.password,
  });
}

abstract interface class BiometricCredentialStorage {
  Future<bool> hasCredentials();
  Future<BiometricSignInCredentials?> readCredentials();
  Future<void> saveCredentials(BiometricSignInCredentials credentials);
  Future<void> clear();
}

class FlutterSecureBiometricCredentialStorage
    implements BiometricCredentialStorage {
  static const _credentialsKey = 'auth.biometric_login.credentials';

  final FlutterSecureStorage _storage;

  FlutterSecureBiometricCredentialStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<bool> hasCredentials() => _storage.containsKey(key: _credentialsKey);

  @override
  Future<BiometricSignInCredentials?> readCredentials() async {
    final value = await _storage.read(key: _credentialsKey);
    if (value == null) return null;
    try {
      final credentials = jsonDecode(value) as Map<String, dynamic>;
      final email = credentials['email'] as String?;
      final password = credentials['password'] as String?;
      if (email == null || password == null) {
        throw const FormatException('Missing saved credential fields.');
      }
      return BiometricSignInCredentials(email: email, password: password);
    } on FormatException catch (error) {
      throw BiometricLockException(
        'Saved fingerprint sign-in is unavailable. Sign in with your password and enable it again. ($error)',
      );
    } on TypeError {
      throw const BiometricLockException(
        'Saved fingerprint sign-in is unavailable. Sign in with your password and enable it again.',
      );
    }
  }

  @override
  Future<void> saveCredentials(BiometricSignInCredentials credentials) async {
    await _storage.write(
      key: _credentialsKey,
      value: jsonEncode({
        'email': credentials.email,
        'password': credentials.password,
      }),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _credentialsKey);
}

abstract interface class BiometricLockService {
  Future<bool> isEnabledFor(String userId);
  Future<bool> canAuthenticate();
  Future<bool> authenticate(String reason);
  Future<bool> hasSavedSignIn();
  Future<bool> supportsPasswordSignIn(String userId);
  Future<bool> enableFor(String userId, {required String password});
  Future<BiometricSignInCredentials?> authenticateForSignIn();
  Future<void> refreshCredentialsAfterLogin({
    required String userId,
    required String email,
    required String password,
  });
  Future<void> disable();
}

typedef PasswordSignInSupportChecker = Future<bool> Function(String userId);
typedef PasswordCredentialVerifier =
    Future<String> Function(String userId, String password);

class SharedPreferencesBiometricLockService implements BiometricLockService {
  static const _enabledUserIdKey = 'auth.biometric_lock.user_id';
  static const _savedSignInUserIdKey = 'auth.biometric_login.user_id';

  final LocalAuthentication _localAuthentication;
  final Future<SharedPreferences> Function() _getPreferences;
  final BiometricCredentialStorage _credentialStorage;
  final fb.FirebaseAuth? _firebaseAuth;
  late final PasswordSignInSupportChecker _passwordSignInSupportChecker;
  late final PasswordCredentialVerifier _passwordCredentialVerifier;
  final Future<bool> Function()? _canAuthenticateOverride;
  final Future<bool> Function(String reason)? _authenticateOverride;

  SharedPreferencesBiometricLockService({
    LocalAuthentication? localAuthentication,
    Future<SharedPreferences> Function()? getPreferences,
    BiometricCredentialStorage? credentialStorage,
    fb.FirebaseAuth? firebaseAuth,
    PasswordSignInSupportChecker? passwordSignInSupportChecker,
    PasswordCredentialVerifier? passwordCredentialVerifier,
    Future<bool> Function()? canAuthenticate,
    Future<bool> Function(String reason)? authenticate,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _getPreferences = getPreferences ?? SharedPreferences.getInstance,
       _credentialStorage =
           credentialStorage ?? FlutterSecureBiometricCredentialStorage(),
       _firebaseAuth = firebaseAuth,
       _canAuthenticateOverride = canAuthenticate,
       _authenticateOverride = authenticate {
    _passwordSignInSupportChecker =
        passwordSignInSupportChecker ?? _supportsFirebasePasswordSignIn;
    _passwordCredentialVerifier =
        passwordCredentialVerifier ?? _verifyFirebasePassword;
  }

  @override
  Future<bool> isEnabledFor(String userId) async {
    final preferences = await _getPreferences();
    return preferences.getString(_enabledUserIdKey) == userId &&
        await _credentialStorage.hasCredentials();
  }

  @override
  Future<bool> hasSavedSignIn() async {
    final preferences = await _getPreferences();
    return preferences.getString(_savedSignInUserIdKey) != null &&
        await _credentialStorage.hasCredentials();
  }

  @override
  Future<bool> canAuthenticate() async {
    if (_canAuthenticateOverride != null) {
      return _canAuthenticateOverride();
    }
    if (!await _localAuthentication.canCheckBiometrics) return false;
    return (await _localAuthentication.getAvailableBiometrics()).isNotEmpty;
  }

  @override
  Future<bool> authenticate(String reason) {
    if (_authenticateOverride != null) return _authenticateOverride(reason);
    return _localAuthentication.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }

  @override
  Future<bool> supportsPasswordSignIn(String userId) =>
      _passwordSignInSupportChecker(userId);

  @override
  Future<bool> enableFor(String userId, {required String password}) async {
    if (!await supportsPasswordSignIn(userId)) {
      throw const BiometricLockException(
        'Fingerprint sign-in is currently available for email and password accounts only.',
      );
    }
    final email = await _passwordCredentialVerifier(userId, password);
    final authenticated = await authenticate(
      'Verify your fingerprint to enable sign-in.',
    );
    if (!authenticated) return false;

    await _credentialStorage.saveCredentials(
      BiometricSignInCredentials(email: email, password: password),
    );
    try {
      final preferences = await _getPreferences();
      final sessionLockSaved = await preferences.setString(
        _enabledUserIdKey,
        userId,
      );
      final signInSaved = await preferences.setString(
        _savedSignInUserIdKey,
        userId,
      );
      if (!sessionLockSaved || !signInSaved) {
        throw const BiometricLockException(
          'Could not save fingerprint sign-in settings.',
        );
      }
    } catch (_) {
      final preferences = await _getPreferences();
      await preferences.remove(_enabledUserIdKey);
      await preferences.remove(_savedSignInUserIdKey);
      await _credentialStorage.clear();
      rethrow;
    }
    return true;
  }

  @override
  Future<BiometricSignInCredentials?> authenticateForSignIn() async {
    if (!await hasSavedSignIn()) return null;
    if (!await canAuthenticate()) {
      throw const BiometricLockException(
        'Enroll a fingerprint on this device to use fingerprint sign-in.',
      );
    }
    final authenticated = await authenticate(
      'Sign in to Quit Companion with your fingerprint.',
    );
    if (!authenticated) return null;
    final credentials = await _credentialStorage.readCredentials();
    if (credentials == null) {
      throw const BiometricLockException(
        'Saved fingerprint sign-in is unavailable. Sign in with your password and enable it again.',
      );
    }
    return credentials;
  }

  @override
  Future<void> refreshCredentialsAfterLogin({
    required String userId,
    required String email,
    required String password,
  }) async {
    final preferences = await _getPreferences();
    if (preferences.getString(_savedSignInUserIdKey) != userId) return;
    await _credentialStorage.saveCredentials(
      BiometricSignInCredentials(email: email, password: password),
    );
  }

  @override
  Future<void> disable() async {
    final preferences = await _getPreferences();
    await preferences.remove(_enabledUserIdKey);
    await preferences.remove(_savedSignInUserIdKey);
    await _credentialStorage.clear();
  }

  Future<bool> _supportsFirebasePasswordSignIn(String userId) async {
    final user = (_firebaseAuth ?? fb.FirebaseAuth.instance).currentUser;
    return user != null &&
        user.uid == userId &&
        user.providerData.any((provider) => provider.providerId == 'password');
  }

  Future<String> _verifyFirebasePassword(String userId, String password) async {
    final user = (_firebaseAuth ?? fb.FirebaseAuth.instance).currentUser;
    final email = user?.email;
    if (user == null || user.uid != userId || email == null) {
      throw const BiometricLockException(
        'Your signed-in account could not be verified. Sign in again and retry.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(email: email, password: password),
      );
      return email;
    } on fb.FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'wrong-password' || 'invalid-credential' =>
          'The password was not accepted. Please try again.',
        'network-request-failed' =>
          'Could not verify your password. Check your connection and try again.',
        'too-many-requests' =>
          'Too many attempts. Please wait before trying again.',
        _ => 'Could not verify your password. Please try again.',
      };
      throw BiometricLockException(message);
    }
  }
}

class UnavailableBiometricLockService implements BiometricLockService {
  const UnavailableBiometricLockService();

  @override
  Future<bool> isEnabledFor(String userId) async => false;

  @override
  Future<bool> canAuthenticate() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> hasSavedSignIn() async => false;

  @override
  Future<bool> supportsPasswordSignIn(String userId) async => false;

  @override
  Future<bool> enableFor(String userId, {required String password}) async {
    throw const BiometricLockException(
      'Biometric unlock is unavailable on this device.',
    );
  }

  @override
  Future<BiometricSignInCredentials?> authenticateForSignIn() async => null;

  @override
  Future<void> refreshCredentialsAfterLogin({
    required String userId,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> disable() async {}
}

class BiometricLockException implements Exception {
  final String message;

  const BiometricLockException(this.message);

  @override
  String toString() => message;
}

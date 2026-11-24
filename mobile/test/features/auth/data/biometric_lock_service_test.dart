import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'enabling biometric sign-in verifies the password and saves credentials',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryBiometricCredentialStorage();
      final calls = <String>[];
      final service = _service(
        storage: storage,
        authenticate: (reason) async {
          calls.add('biometric:$reason');
          return true;
        },
        verifyPassword: (userId, password) async {
          calls.add('password:$userId:$password');
          return 'user@example.com';
        },
      );

      final enabled = await service.enableFor('user-1', password: 'secret123');

      expect(enabled, isTrue);
      expect(calls, [
        'password:user-1:secret123',
        'biometric:Verify your fingerprint to enable sign-in.',
      ]);
      expect(await service.isEnabledFor('user-1'), isTrue);
      expect(await service.isEnabledFor('user-2'), isFalse);
      expect(await service.hasSavedSignIn(), isTrue);
      final saved = await storage.readCredentials();
      expect(saved?.email, 'user@example.com');
      expect(saved?.password, 'secret123');
    },
  );

  test(
    'unsupported accounts cannot enable biometric password sign-in',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryBiometricCredentialStorage();
      var verifierCalled = false;
      final service = _service(
        storage: storage,
        supportsPasswordSignIn: (_) async => false,
        verifyPassword: (_, _) async {
          verifierCalled = true;
          return 'user@example.com';
        },
      );

      await expectLater(
        service.enableFor('user-1', password: 'secret123'),
        throwsA(isA<BiometricLockException>()),
      );

      expect(verifierCalled, isFalse);
      expect(await storage.hasCredentials(), isFalse);
    },
  );

  test('canceling biometric setup does not save credentials', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = _MemoryBiometricCredentialStorage();
    final service = _service(
      storage: storage,
      authenticate: (_) async => false,
    );

    final enabled = await service.enableFor('user-1', password: 'secret123');

    expect(enabled, isFalse);
    expect(await service.isEnabledFor('user-1'), isFalse);
    expect(await storage.hasCredentials(), isFalse);
  });

  test(
    'sign-in requires biometric success before returning saved credentials',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryBiometricCredentialStorage();
      final service = _service(storage: storage);
      await service.enableFor('user-1', password: 'secret123');

      final credentials = await service.authenticateForSignIn();

      expect(credentials?.email, 'user@example.com');
      expect(credentials?.password, 'secret123');
    },
  );

  test('disabling biometric sign-in clears the stored password', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = _MemoryBiometricCredentialStorage();
    final service = _service(storage: storage);
    await service.enableFor('user-1', password: 'secret123');

    await service.disable();

    expect(await service.hasSavedSignIn(), isFalse);
    expect(await service.isEnabledFor('user-1'), isFalse);
    expect(await storage.hasCredentials(), isFalse);
  });

  test(
    'legacy session-unlock preference does not silently opt into saved sign-in',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth.biometric_lock.user_id': 'user-1',
      });
      final storage = _MemoryBiometricCredentialStorage();
      final service = _service(storage: storage);

      await service.refreshCredentialsAfterLogin(
        userId: 'user-1',
        email: 'user@example.com',
        password: 'secret123',
      );

      expect(await service.hasSavedSignIn(), isFalse);
      expect(await storage.hasCredentials(), isFalse);
    },
  );

  test(
    'a successful manual login refreshes an explicitly saved password',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = _MemoryBiometricCredentialStorage();
      final service = _service(storage: storage);
      await service.enableFor('user-1', password: 'oldSecret123');

      await service.refreshCredentialsAfterLogin(
        userId: 'user-1',
        email: 'user@example.com',
        password: 'newSecret456',
      );

      final saved = await storage.readCredentials();
      expect(saved?.password, 'newSecret456');
    },
  );
}

SharedPreferencesBiometricLockService _service({
  required BiometricCredentialStorage storage,
  Future<bool> Function(String reason)? authenticate,
  Future<bool> Function(String userId)? supportsPasswordSignIn,
  Future<String> Function(String userId, String password)? verifyPassword,
}) {
  return SharedPreferencesBiometricLockService(
    credentialStorage: storage,
    canAuthenticate: () async => true,
    authenticate: authenticate ?? (_) async => true,
    passwordSignInSupportChecker: supportsPasswordSignIn ?? (_) async => true,
    passwordCredentialVerifier:
        verifyPassword ?? (_, _) async => 'user@example.com',
  );
}

class _MemoryBiometricCredentialStorage implements BiometricCredentialStorage {
  BiometricSignInCredentials? credentials;

  @override
  Future<bool> hasCredentials() async => credentials != null;

  @override
  Future<BiometricSignInCredentials?> readCredentials() async => credentials;

  @override
  Future<void> saveCredentials(BiometricSignInCredentials value) async {
    credentials = value;
  }

  @override
  Future<void> clear() async {
    credentials = null;
  }
}

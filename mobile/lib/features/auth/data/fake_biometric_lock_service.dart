import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';

class FakeBiometricLockService implements BiometricLockService {
  bool available;
  bool authenticationResult;
  String? enabledUserId;
  String? savedEmail;
  String? savedPassword;
  bool passwordSignInSupported;
  String? errorMessage;
  final List<String> authenticationReasons = [];

  FakeBiometricLockService({
    this.available = false,
    this.authenticationResult = true,
    this.enabledUserId,
    this.savedEmail,
    this.savedPassword,
    this.passwordSignInSupported = true,
    this.errorMessage,
  }) {
    if (enabledUserId != null) {
      savedEmail ??= 'returning@example.com';
      savedPassword ??= 'password123';
    }
  }

  @override
  Future<bool> isEnabledFor(String userId) async => enabledUserId == userId;

  @override
  Future<bool> canAuthenticate() async => available;

  @override
  Future<bool> hasSavedSignIn() async =>
      savedEmail != null && savedPassword != null;

  @override
  Future<bool> supportsPasswordSignIn(String userId) async =>
      passwordSignInSupported;

  @override
  Future<bool> authenticate(String reason) async {
    authenticationReasons.add(reason);
    if (errorMessage != null) {
      throw BiometricLockException(errorMessage!);
    }
    return authenticationResult;
  }

  @override
  Future<bool> enableFor(String userId, {required String password}) async {
    final authenticated = await authenticate(
      'Verify your fingerprint to enable sign-in.',
    );
    if (!authenticated) return false;
    enabledUserId = userId;
    savedEmail ??= 'returning@example.com';
    savedPassword = password;
    return true;
  }

  @override
  Future<BiometricSignInCredentials?> authenticateForSignIn() async {
    final authenticated = await authenticate(
      'Sign in to Quit Companion with your fingerprint.',
    );
    if (!authenticated || savedEmail == null || savedPassword == null) {
      return null;
    }
    return BiometricSignInCredentials(
      email: savedEmail!,
      password: savedPassword!,
    );
  }

  @override
  Future<void> refreshCredentialsAfterLogin({
    required String userId,
    required String email,
    required String password,
  }) async {
    if (enabledUserId != userId) return;
    savedEmail = email;
    savedPassword = password;
  }

  @override
  Future<void> disable() async {
    enabledUserId = null;
    savedEmail = null;
    savedPassword = null;
  }
}

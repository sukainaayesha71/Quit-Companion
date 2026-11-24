class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Result of a successful Google sign-in: the Firebase uid, the account's
/// email (mirroring what registerWithEmailPassword/loginWithEmailPassword's
/// callers already get from the email field), and the account's display
/// name if Google provided one.
class GoogleAuthResult {
  final String userId;
  final String email;
  final String? name;
  GoogleAuthResult({required this.userId, required this.email, this.name});
}

abstract class AuthRepository {
  /// Creates an account and sends its verification email without establishing
  /// an authenticated session.
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  });
  Future<String> loginWithEmailPassword({
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> logout();
  String? get currentUserId => null;
  String? get currentEmail => null;
  String? get currentDisplayName => null;

  /// Runs the interactive Google account-picker + Firebase credential
  /// exchange. Returns null if the user canceled the picker (not an
  /// error); throws [AuthException] for any real failure.
  Future<GoogleAuthResult?> signInWithGoogle();
}

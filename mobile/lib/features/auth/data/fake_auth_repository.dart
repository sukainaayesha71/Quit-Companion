import 'package:quit_companion/features/auth/data/auth_repository.dart';

/// In-memory AuthRepository for tests and for running the app before a
/// real Firebase project exists. Registration stores credentials without
/// signing in, matching the email-verification flow.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    String? currentUserId,
    String? currentEmail,
    String? currentDisplayName,
  }) : _currentUserId = currentUserId,
       _currentEmail = currentEmail,
       _currentDisplayName = currentDisplayName;

  final Map<String, String> _users = {};
  final Map<String, String> _displayNames = {};
  String? _currentUserId;
  String? _currentEmail;
  String? _currentDisplayName;
  String? passwordResetEmailSentTo;
  AuthException? passwordResetError;

  /// Test hooks for signInWithGoogle() — set at most one:
  /// - [googleSignInResult]: simulates a successful picker + Firebase exchange.
  /// - [googleSignInCanceled]: simulates the user backing out of the picker.
  /// - [googleSignInError]: simulates a real failure (config/network/etc).
  GoogleAuthResult? googleSignInResult;
  bool googleSignInCanceled = false;
  AuthException? googleSignInError;

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (_users.containsKey(email)) {
      throw AuthException('An account with this email already exists.');
    }
    _users[email] = password;
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) _displayNames[email] = name;
    return email;
  }

  @override
  Future<String> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (_users[email] != password) {
      throw AuthException('Invalid email or password.');
    }
    _currentUserId = email;
    _currentEmail = email;
    _currentDisplayName = _displayNames[email];
    return email;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (passwordResetError != null) throw passwordResetError!;
    if (!_users.containsKey(email)) {
      throw AuthException('No account was found for this email address.');
    }
    passwordResetEmailSentTo = email;
  }

  @override
  Future<void> logout() async {
    _currentUserId = null;
    _currentEmail = null;
    _currentDisplayName = null;
  }

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentEmail => _currentEmail;

  @override
  String? get currentDisplayName => _currentDisplayName;

  @override
  Future<GoogleAuthResult?> signInWithGoogle() async {
    if (googleSignInError != null) throw googleSignInError!;
    if (googleSignInCanceled) return null;
    final result = googleSignInResult;
    if (result == null) {
      throw AuthException(
        'FakeAuthRepository.signInWithGoogle() was called without configuring a result.',
      );
    }
    _currentUserId = result.userId;
    _currentEmail = result.email;
    _currentDisplayName = result.name;
    return result;
  }
}

import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/auth/data/auth_repository.dart';

enum AuthStatus { idle, loading, success, error }

/// FR1: registration/login validation and state, backed by an AuthRepository.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : userId = _authRepository.currentUserId;

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;
  String? userId;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _lowercasePattern = RegExp(r'[a-z]');
  static final _numericPattern = RegExp(r'[0-9]');

  String? validateEmail(String email) {
    if (email.trim().isEmpty) {
      return 'Email is required.';
    }
    if (!_emailPattern.hasMatch(email.trim())) {
      return 'Enter a valid email address, like name@example.com.';
    }
    return null;
  }

  /// Validates the Firebase registration password policy.
  String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (!_lowercasePattern.hasMatch(password)) {
      return 'Add at least one lowercase letter.';
    }
    if (!_numericPattern.hasMatch(password)) {
      return 'Add at least one number.';
    }
    return null;
  }

  String? validateLoginPassword(String password) {
    if (password.isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  /// Clears a stale status/errorMessage left over from a previous attempt.
  /// Needed when navigating between Register and Login, since both screens
  /// share this single AuthController instance and would otherwise render
  /// the other screen's leftover error on first build.
  void clearError() {
    status = AuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final validationError = validateEmail(email) ?? validatePassword(password);
    if (validationError != null) {
      errorMessage = validationError;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.registerWithEmailPassword(
        email: email.trim(),
        password: password,
        displayName: displayName,
      );
      userId = null;
      status = AuthStatus.success;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Runs Google sign-in (account picker + Firebase credential exchange).
  /// Returns the (userId, email, name) tuple on success — same shape
  /// callers already use from the email/password flow, plus Google's
  /// account display name if it provided one — or null if the user
  /// canceled the picker (reset to idle, not an error) or sign-in failed
  /// (errorMessage/status set, same as register()/login()).
  Future<({String userId, String email, String? name})?>
  signInWithGoogle() async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _authRepository.signInWithGoogle();
      if (result == null) {
        // User backed out of the account picker — not a failure.
        status = AuthStatus.idle;
        notifyListeners();
        return null;
      }
      userId = result.userId;
      status = AuthStatus.success;
      notifyListeners();
      return (userId: result.userId, email: result.email, name: result.name);
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.error;
      notifyListeners();
      return null;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final validationError =
        validateEmail(email) ?? validateLoginPassword(password);
    if (validationError != null) {
      errorMessage = validationError;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      userId = await _authRepository.loginWithEmailPassword(
        email: email.trim(),
        password: password,
      );
      status = AuthStatus.success;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPasswordReset({required String email}) async {
    final validationError = validateEmail(email);
    if (validationError != null) {
      errorMessage = validationError;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.sendPasswordResetEmail(email: email.trim());
      status = AuthStatus.success;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Could not send a password reset email. Please try again.';
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    userId = null;
    status = AuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
}

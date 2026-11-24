import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart' as google;
import 'package:quit_companion/features/auth/data/auth_repository.dart';

const _googleSignInTimeout = Duration(seconds: 30);

/// User-facing message for a failed email/password login.
///
/// The quit-companion Firebase project has email enumeration protection on,
/// so a wrong password, an unknown email, and an account that only uses
/// Google sign-in all come back as `invalid-credential`. Firebase's raw text
/// for that ("The supplied auth credential is incorrect, malformed or has
/// expired.") reads like a technical fault, so it is replaced with what the
/// user can actually do.
@visibleForTesting
String loginErrorMessage(fb.FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' ||
  'invalid-login-credentials' ||
  'wrong-password' ||
  'user-not-found' =>
    'Incorrect email or password. If you created this account with Google, '
        'use Continue with Google. Forgot your password? Tap '
        '"Forgot Password?" to reset it.',
  'user-disabled' => 'This account has been disabled.',
  'invalid-email' => 'Enter a valid email address, like name@example.com.',
  'too-many-requests' =>
    'Too many attempts. Wait a few minutes and try again, or reset your password.',
  'network-request-failed' =>
    'Could not reach the service. Check your connection and try again.',
  'operation-not-allowed' =>
    'Email and password sign-in is not available right now.',
  _ => e.message ?? 'Login failed.',
};

/// User-facing message for a failed email/password registration.
@visibleForTesting
String registrationErrorMessage(fb.FirebaseAuthException e) =>
    switch (e.code) {
      'email-already-in-use' =>
        'An account already exists for this email. Log in instead, or use '
            'Continue with Google if you signed up with Google.',
      // Mirrors the project's enforced password policy (and validatePassword).
      'weak-password' || 'password-does-not-meet-requirements' =>
        'Use at least 8 characters, with a lowercase letter and a number.',
      'invalid-email' => 'Enter a valid email address, like name@example.com.',
      'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
      'network-request-failed' =>
        'Could not reach the service. Check your connection and try again.',
      'operation-not-allowed' =>
        'Email and password sign-up is not available right now.',
      _ => e.message ?? 'Registration failed.',
    };

/// Real Firebase Auth implementation of AuthRepository (FR1). Requires a
/// configured Firebase project (flutterfire configure) before use — not
/// wired into main.dart until that exists.
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final google.GoogleSignIn _googleSignIn;
  bool _googleSignInInitialized = false;

  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    google.GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? google.GoogleSignIn.instance;

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      final userId = user.uid;
      try {
        final name = displayName?.trim();
        if (name != null && name.isNotEmpty) {
          await user.updateDisplayName(name);
        }
        try {
          await user.sendEmailVerification();
        } catch (e) {
          // Keep registration available during transient email delivery
          // failures, while leaving a diagnostic for developers.
          debugPrint('sendEmailVerification failed for $userId: $e');
        }
      } finally {
        await _firebaseAuth.signOut();
      }
      return userId;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(registrationErrorMessage(e));
    }
  }

  @override
  Future<String> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser == null || refreshedUser.email == null) {
        throw AuthException(
          'Could not verify your email status. Please try logging in again.',
        );
      }
      if (!refreshedUser.emailVerified) {
        await _firebaseAuth.signOut();
        throw AuthException(
          'Verify your email address before logging in. Check your inbox for the verification link.',
        );
      }
      return refreshedUser.uid;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(loginErrorMessage(e));
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'invalid-email' => 'Enter a valid email address.',
        'user-not-found' => 'No account was found for this email address.',
        'operation-not-allowed' => 'Password reset is not available right now.',
        'too-many-requests' => 'Too many attempts. Please wait and try again.',
        'network-request-failed' =>
          'Could not reach the service. Check your connection and try again.',
        _ => 'Could not send a password reset email. Please try again.',
      };
      throw AuthException(message);
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    // Also clear the Google account picker's session — signing out of
    // Firebase alone leaves _googleSignIn silently remembering the last
    // account, so "Continue with Google" on a shared device would
    // re-authenticate the same previous account with no picker shown.
    // Only meaningful (and only safe to call, per the package's own
    // initialize()-before-any-other-method contract) once a Google
    // sign-in has actually happened this session — an email/password-only
    // user never triggers signInWithGoogle()'s initialize() call at all.
    if (_googleSignInInitialized) {
      await _googleSignIn.signOut();
    }
  }

  @override
  String? get currentUserId {
    final user = _firebaseAuth.currentUser;
    if (user == null || (user.email != null && !user.emailVerified)) {
      return null;
    }
    return user.uid;
  }

  @override
  String? get currentEmail => _firebaseAuth.currentUser?.email;

  @override
  String? get currentDisplayName => _firebaseAuth.currentUser?.displayName;

  @override
  Future<GoogleAuthResult?> signInWithGoogle() async {
    try {
      if (!_googleSignInInitialized) {
        // No clientId/serverClientId passed: google-services.json contains
        // a web OAuth client (provisioned once Google was enabled as a
        // Firebase Auth sign-in provider), which the Android plugin reads
        // automatically — see google_sign_in_android's README.
        await _googleSignIn.initialize();
        _googleSignInInitialized = true;
      }

      final account = await _googleSignIn.authenticate().timeout(
        _googleSignInTimeout,
      );
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw AuthException('Google did not return an identity token.');
      }

      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;
      if (user == null) {
        throw AuthException('Google sign-in did not return a Firebase user.');
      }
      // Prefer Firebase's own resolved displayName (decoded from the Google
      // ID token during signInWithCredential) over the google_sign_in
      // plugin's own account object — the latter has been observed coming
      // back null for some real accounts/Android sign-in flows even though
      // the account genuinely has a name, which was silently producing
      // NicotineUser.name == null (and the Dashboard's generic "Hi there"
      // greeting) for otherwise-successful Google registrations. Mirrors
      // the same user.X ?? account.X fallback already used for email above.
      return GoogleAuthResult(
        userId: user.uid,
        email: user.email ?? account.email,
        name: user.displayName ?? account.displayName,
      );
    } on google.GoogleSignInException catch (e) {
      if (e.code == google.GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw AuthException(
        e.description ?? 'Google sign-in failed (${e.code}).',
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Google sign-in failed.');
    } on TimeoutException {
      throw AuthException(
        'Google sign-in timed out. Please check your connection and try again.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      // Anything else (e.g. a raw PlatformException from a native-side
      // config problem) must still resolve to an AuthException — letting
      // it propagate unhandled here means AuthController's catch clause
      // never runs, leaving status stuck at AuthStatus.loading forever.
      throw AuthException('Google sign-in failed. Please try again.');
    }
  }
}

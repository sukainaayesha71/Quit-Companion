import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';

/// Real Firebase Phone Authentication implementation. Wraps
/// FirebaseAuth.verifyPhoneNumber's callback-based API in awaitable
/// Futures. Requires the Phone sign-in provider to be enabled in the
/// Firebase Console and SHA-1/SHA-256 registered for the Android app.
class FirebasePhoneAuthRepository implements PhoneAuthRepository {
  final fb.FirebaseAuth _firebaseAuth;

  FirebasePhoneAuthRepository({fb.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  @override
  Future<OtpSendResult> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    final completer = Completer<OtpSendResult>();
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (fb.PhoneAuthCredential credential) async {
        // Android auto-retrieval / instant validation: sign in directly.
        // The OTP screen may never be needed for this path, but sendOtp's
        // caller still needs its pending Future resolved either way.
        debugPrint('[PhoneAuth] verificationCompleted (auto)');
        try {
          await _firebaseAuth.signInWithCredential(credential);
          debugPrint('[PhoneAuth] auto sign-in succeeded');
        } catch (e) {
          debugPrint('[PhoneAuth] auto sign-in failed');
          // Manual code entry on the OTP screen remains the fallback path.
        }
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        debugPrint('[PhoneAuth] verificationFailed: code=${e.code}');
        if (!completer.isCompleted) {
          completer.completeError(
            PhoneAuthException(switch (e.code) {
              'billing-not-enabled' =>
                'SMS sign-in requires billing to be enabled in Firebase. For development, configure a Firebase test phone number.',
              'operation-not-allowed' =>
                'Phone sign-in is not enabled for this Firebase project.',
              'invalid-app-credential' =>
                'Phone verification configuration is invalid. Check the Android SHA-256 fingerprint and Firebase app settings.',
              'too-many-requests' =>
                'Too many verification attempts. Please wait before trying again.',
              _ => e.message ?? 'Could not send verification code.',
            }),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('[PhoneAuth] verification code sent');
        if (!completer.isCompleted) {
          completer.complete(
            OtpSendResult(verificationId, resendToken: resendToken),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Android's auto-read window closed; not itself a failure — the
        // user can still enter the code manually on the OTP screen.
        debugPrint('[PhoneAuth] automatic code retrieval timed out');
      },
    );
    return completer.future;
  }

  @override
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      debugPrint(
        '[PhoneAuth] signInWithCredential succeeded: uid=${userCredential.user?.uid}',
      );
      return userCredential.user!.uid;
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('[PhoneAuth] signInWithCredential failed: code=${e.code}');
      throw PhoneAuthException(e.message ?? 'Verification failed.');
    }
  }

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;
}

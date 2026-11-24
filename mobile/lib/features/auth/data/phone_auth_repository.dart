class PhoneAuthException implements Exception {
  final String message;
  PhoneAuthException(this.message);

  @override
  String toString() => message;
}

/// Result of a successful `sendOtp` call. `resendToken` (Android-only,
/// nullable) lets a resend request force a fresh SMS via Firebase's
/// `forceResendingToken` rather than reusing a stale verification session.
class OtpSendResult {
  final String verificationId;
  final int? resendToken;
  const OtpSendResult(this.verificationId, {this.resendToken});
}

/// FR1: Firebase Phone Authentication (phone number -> OTP -> verified
/// sign-in), added as a second auth method alongside email/password.
/// Mirrors AuthRepository's shape but phone verification is inherently
/// two-step, hence sendOtp/verifyOtp instead of a single call.
abstract class PhoneAuthRepository {
  Future<OtpSendResult> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
  });
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  });
  String? get currentUserId;
}

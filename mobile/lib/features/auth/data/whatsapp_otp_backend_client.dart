class WhatsAppOtpException implements Exception {
  final String message;
  WhatsAppOtpException(this.message);

  @override
  String toString() => message;
}

/// Talks to the FastAPI backend (backend/) that generates/stores OTPs and
/// delivers them via the WhatsApp Business Platform. Used only for
/// real (non-test) phone numbers — see RoutingPhoneAuthRepository.
abstract class WhatsAppOtpBackendClient {
  Future<void> sendOtp(String phoneNumber);

  /// Returns a Firebase custom token (minted server-side via the Firebase
  /// Admin SDK after OTP verification) for signInWithCustomToken.
  Future<String> verifyOtp({required String phoneNumber, required String otp});
}

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';
import 'package:quit_companion/features/auth/data/whatsapp_otp_backend_client.dart';

/// Real-phone-number PhoneAuthRepository backed by the FastAPI OTP backend
/// + WhatsApp Business Platform, instead of Firebase Phone Auth SMS
/// (Firebase's real-SMS path returns BILLING_NOT_ENABLED on this project).
///
/// verifyOtp's `verificationId` is the phone number itself — the backend
/// tracks pending OTPs by phone number, not a Firebase-issued session id —
/// so sendOtp returns it as the OtpSendResult.verificationId, letting
/// PhoneAuthController/OtpVerificationScreen work completely unchanged.
///
/// After the backend confirms the OTP, it mints a real Firebase custom
/// token (via the Admin SDK); signInWithCustomToken() establishes a
/// genuine Firebase Auth session from that token — never a fabricated uid.
class WhatsAppPhoneAuthRepository implements PhoneAuthRepository {
  final WhatsAppOtpBackendClient _client;
  final Future<String> Function(String customToken) _signInWithCustomToken;

  WhatsAppPhoneAuthRepository({
    required WhatsAppOtpBackendClient client,
    Future<String> Function(String customToken)? signInWithCustomToken,
  }) : _client = client,
       _signInWithCustomToken = signInWithCustomToken ?? _defaultSignIn;

  static Future<String> _defaultSignIn(String customToken) async {
    final credential = await fb.FirebaseAuth.instance.signInWithCustomToken(
      customToken,
    );
    return credential.user!.uid;
  }

  String? _currentUserId;

  @override
  Future<OtpSendResult> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    try {
      await _client.sendOtp(phoneNumber);
    } on WhatsAppOtpException catch (e) {
      throw PhoneAuthException(e.message);
    }
    return OtpSendResult(phoneNumber);
  }

  @override
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final String customToken;
    try {
      customToken = await _client.verifyOtp(
        phoneNumber: verificationId,
        otp: smsCode,
      );
    } on WhatsAppOtpException catch (e) {
      throw PhoneAuthException(e.message);
    }
    try {
      _currentUserId = await _signInWithCustomToken(customToken);
    } on fb.FirebaseAuthException catch (e) {
      throw PhoneAuthException(
        e.message ?? 'Could not complete sign-in. Please try again.',
      );
    }
    return _currentUserId!;
  }

  @override
  String? get currentUserId => _currentUserId;
}

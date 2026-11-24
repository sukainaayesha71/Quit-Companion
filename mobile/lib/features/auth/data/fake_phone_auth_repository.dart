import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';

/// In-memory PhoneAuthRepository for tests — never sends real SMS. The
/// correct code defaults to '123456'; construct with [failSend] to
/// simulate an invalid-phone-number failure at sendOtp time. [delay]
/// (default none) lets a test observe an in-flight loading state before
/// the fake resolves.
class FakePhoneAuthRepository implements PhoneAuthRepository {
  final String fixedOtp;
  final bool failSend;
  final Duration delay;

  FakePhoneAuthRepository({
    this.fixedOtp = '123456',
    this.failSend = false,
    this.delay = Duration.zero,
  });

  int sendCount = 0;
  String? lastPhoneNumber;
  String? _currentUserId;

  @override
  Future<OtpSendResult> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    if (delay > Duration.zero) await Future.delayed(delay);
    sendCount++;
    if (failSend) {
      throw PhoneAuthException('The phone number entered is invalid.');
    }
    lastPhoneNumber = phoneNumber;
    return OtpSendResult(
      'fake-verification-id-$sendCount',
      resendToken: sendCount,
    );
  }

  @override
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (delay > Duration.zero) await Future.delayed(delay);
    if (smsCode != fixedOtp) {
      throw PhoneAuthException('Invalid or expired verification code.');
    }
    _currentUserId = lastPhoneNumber ?? 'unknown';
    return _currentUserId!;
  }

  @override
  String? get currentUserId => _currentUserId;
}

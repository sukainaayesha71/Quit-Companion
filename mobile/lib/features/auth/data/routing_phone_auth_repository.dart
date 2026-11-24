import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';

/// Routes phone auth by number: the configured Firebase test number(s)
/// still go through the real Firebase Phone Auth SMS test flow
/// (+923357606070 / 123456, unaffected by BILLING_NOT_ENABLED since
/// Firebase test numbers bypass real SMS delivery); every other number
/// goes through the WhatsApp OTP backend. PhoneAuthController and
/// OtpVerificationScreen are unaware of this — they only ever see the
/// PhoneAuthRepository interface.
class RoutingPhoneAuthRepository implements PhoneAuthRepository {
  final PhoneAuthRepository _testNumberRepository;
  final PhoneAuthRepository _realNumberRepository;
  final Set<String> _testPhoneNumbers;

  RoutingPhoneAuthRepository({
    required PhoneAuthRepository testNumberRepository,
    required PhoneAuthRepository realNumberRepository,
    Set<String> testPhoneNumbers = const {'+923357606070'},
  }) : _testNumberRepository = testNumberRepository,
       _realNumberRepository = realNumberRepository,
       _testPhoneNumbers = testPhoneNumbers;

  PhoneAuthRepository? _activeRepository;

  PhoneAuthRepository _repositoryFor(String phoneNumber) =>
      _testPhoneNumbers.contains(phoneNumber)
      ? _testNumberRepository
      : _realNumberRepository;

  @override
  Future<OtpSendResult> sendOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) {
    final repository = _repositoryFor(phoneNumber);
    _activeRepository = repository;
    return repository.sendOtp(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
    );
  }

  @override
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final repository = _activeRepository;
    if (repository == null) {
      throw PhoneAuthException(
        'Verification session expired. Please request a new code.',
      );
    }
    return repository.verifyOtp(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  @override
  String? get currentUserId =>
      _activeRepository?.currentUserId ??
      _testNumberRepository.currentUserId ??
      _realNumberRepository.currentUserId;
}

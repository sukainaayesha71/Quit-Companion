import 'package:quit_companion/features/auth/data/whatsapp_otp_backend_client.dart';

/// In-memory WhatsAppOtpBackendClient for tests — never makes a network
/// call. The correct code defaults to '123456'; construct with
/// [failSend]/[failVerify] to simulate backend failures.
class FakeWhatsAppOtpBackendClient implements WhatsAppOtpBackendClient {
  final String fixedOtp;
  final bool failSend;
  final bool failVerify;

  FakeWhatsAppOtpBackendClient({
    this.fixedOtp = '123456',
    this.failSend = false,
    this.failVerify = false,
  });

  int sendCount = 0;
  String? lastPhoneNumber;

  @override
  Future<void> sendOtp(String phoneNumber) async {
    sendCount++;
    if (failSend) {
      throw WhatsAppOtpException(
        'Could not send verification code. Please try again.',
      );
    }
    lastPhoneNumber = phoneNumber;
  }

  @override
  Future<String> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    if (failVerify) {
      throw WhatsAppOtpException('Invalid or expired verification code.');
    }
    if (otp != fixedOtp) {
      throw WhatsAppOtpException('Invalid or expired verification code.');
    }
    return 'fake-custom-token-for-$phoneNumber';
  }
}

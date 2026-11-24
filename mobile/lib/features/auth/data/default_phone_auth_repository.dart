import 'package:quit_companion/core/config/otp_backend_config.dart';
import 'package:quit_companion/core/config/phone_auth_config.dart';
import 'package:quit_companion/features/auth/data/firebase_phone_auth_repository.dart';
import 'package:quit_companion/features/auth/data/http_whatsapp_otp_backend_client.dart';
import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';
import 'package:quit_companion/features/auth/data/whatsapp_phone_auth_repository.dart';

/// WhatsApp OTP is the default and requires a configured Meta backend.
/// Firebase SMS remains available through PHONE_AUTH_PROVIDER=firebase.
PhoneAuthRepository createDefaultPhoneAuthRepository() {
  const provider = PhoneAuthConfig.provider;
  if (provider == 'whatsapp') {
    return WhatsAppPhoneAuthRepository(
      client: HttpWhatsAppOtpBackendClient(baseUrl: OtpBackendConfig.baseUrl),
    );
  }
  if (provider != 'firebase') {
    throw ArgumentError('PHONE_AUTH_PROVIDER must be firebase or whatsapp.');
  }
  return FirebasePhoneAuthRepository();
}

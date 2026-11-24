import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/data/fake_whatsapp_otp_backend_client.dart';
import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';
import 'package:quit_companion/features/auth/data/whatsapp_phone_auth_repository.dart';

void main() {
  group('WhatsAppPhoneAuthRepository', () {
    test(
      'sendOtp forwards to the backend client and returns the phone number as verificationId',
      () async {
        final client = FakeWhatsAppOtpBackendClient();
        final repository = WhatsAppPhoneAuthRepository(client: client);

        final result = await repository.sendOtp(phoneNumber: '+923001234567');

        expect(result.verificationId, '+923001234567');
        expect(client.sendCount, 1);
        expect(client.lastPhoneNumber, '+923001234567');
      },
    );

    test('sendOtp surfaces a backend failure as PhoneAuthException', () async {
      final client = FakeWhatsAppOtpBackendClient(failSend: true);
      final repository = WhatsAppPhoneAuthRepository(client: client);

      expect(
        () => repository.sendOtp(phoneNumber: '+923001234567'),
        throwsA(isA<PhoneAuthException>()),
      );
    });

    test(
      'verifyOtp exchanges the correct code for a Firebase custom token and signs in',
      () async {
        final client = FakeWhatsAppOtpBackendClient();
        String? tokenReceived;
        final repository = WhatsAppPhoneAuthRepository(
          client: client,
          signInWithCustomToken: (token) async {
            tokenReceived = token;
            return 'firebase-uid-123';
          },
        );
        await repository.sendOtp(phoneNumber: '+923001234567');

        final uid = await repository.verifyOtp(
          verificationId: '+923001234567',
          smsCode: '123456',
        );

        expect(uid, 'firebase-uid-123');
        expect(repository.currentUserId, 'firebase-uid-123');
        expect(tokenReceived, 'fake-custom-token-for-+923001234567');
      },
    );

    test(
      'verifyOtp with an incorrect code throws PhoneAuthException without signing in',
      () async {
        final client = FakeWhatsAppOtpBackendClient();
        var signInCalled = false;
        final repository = WhatsAppPhoneAuthRepository(
          client: client,
          signInWithCustomToken: (token) async {
            signInCalled = true;
            return 'firebase-uid-123';
          },
        );
        await repository.sendOtp(phoneNumber: '+923001234567');

        expect(
          () => repository.verifyOtp(
            verificationId: '+923001234567',
            smsCode: '000000',
          ),
          throwsA(isA<PhoneAuthException>()),
        );
        expect(signInCalled, isFalse);
        expect(repository.currentUserId, isNull);
      },
    );

    test(
      'verifyOtp surfaces a sign-in failure as PhoneAuthException',
      () async {
        final client = FakeWhatsAppOtpBackendClient();
        final repository = WhatsAppPhoneAuthRepository(
          client: client,
          signInWithCustomToken: (token) async =>
              throw Exception('sign-in failed'),
        );
        await repository.sendOtp(phoneNumber: '+923001234567');

        expect(
          () => repository.verifyOtp(
            verificationId: '+923001234567',
            smsCode: '123456',
          ),
          throwsException,
        );
      },
    );
  });
}

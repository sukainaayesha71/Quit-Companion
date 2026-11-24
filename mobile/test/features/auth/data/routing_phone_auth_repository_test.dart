import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/data/fake_phone_auth_repository.dart';
import 'package:quit_companion/features/auth/data/fake_whatsapp_otp_backend_client.dart';
import 'package:quit_companion/features/auth/data/phone_auth_repository.dart';
import 'package:quit_companion/features/auth/data/routing_phone_auth_repository.dart';
import 'package:quit_companion/features/auth/data/whatsapp_phone_auth_repository.dart';

void main() {
  group('RoutingPhoneAuthRepository', () {
    late FakePhoneAuthRepository testRepo;
    late FakeWhatsAppOtpBackendClient whatsappClient;
    late WhatsAppPhoneAuthRepository realRepo;
    late RoutingPhoneAuthRepository routing;

    setUp(() {
      testRepo = FakePhoneAuthRepository();
      whatsappClient = FakeWhatsAppOtpBackendClient();
      realRepo = WhatsAppPhoneAuthRepository(
        client: whatsappClient,
        signInWithCustomToken: (token) async => 'firebase-uid-for-$token',
      );
      routing = RoutingPhoneAuthRepository(
        testNumberRepository: testRepo,
        realNumberRepository: realRepo,
        testPhoneNumbers: const {'+923357606070'},
      );
    });

    test(
      'the configured Firebase test number is routed to the test repository, never WhatsApp',
      () async {
        await routing.sendOtp(phoneNumber: '+923357606070');

        expect(testRepo.sendCount, 1);
        expect(testRepo.lastPhoneNumber, '+923357606070');
        expect(whatsappClient.sendCount, 0);
      },
    );

    test(
      'a real (non-test) number is routed to the WhatsApp repository, never the Firebase test path',
      () async {
        await routing.sendOtp(phoneNumber: '+923001234567');

        expect(whatsappClient.sendCount, 1);
        expect(whatsappClient.lastPhoneNumber, '+923001234567');
        expect(testRepo.sendCount, 0);
      },
    );

    test(
      'verifyOtp for the test number completes via Firebase test-number verification (123456)',
      () async {
        await routing.sendOtp(phoneNumber: '+923357606070');

        final uid = await routing.verifyOtp(
          verificationId: '+923357606070',
          smsCode: '123456',
        );

        expect(uid, '+923357606070');
        expect(routing.currentUserId, '+923357606070');
      },
    );

    test(
      'verifyOtp for a real number completes via the WhatsApp/Firebase-custom-token path',
      () async {
        await routing.sendOtp(phoneNumber: '+923001234567');

        final uid = await routing.verifyOtp(
          verificationId: '+923001234567',
          smsCode: '123456',
        );

        expect(uid, 'firebase-uid-for-fake-custom-token-for-+923001234567');
        expect(routing.currentUserId, uid);
      },
    );

    test(
      'verifyOtp before any sendOtp throws a session-expired PhoneAuthException',
      () async {
        expect(
          () => routing.verifyOtp(
            verificationId: '+923001234567',
            smsCode: '123456',
          ),
          throwsA(isA<PhoneAuthException>()),
        );
      },
    );
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quit_companion/features/auth/data/http_whatsapp_otp_backend_client.dart';
import 'package:quit_companion/features/auth/data/whatsapp_otp_backend_client.dart';

void main() {
  group('HttpWhatsAppOtpBackendClient', () {
    test(
      'sendOtp posts the normalized phone number and succeeds on 200',
      () async {
        http.Request? captured;
        final mockClient = MockClient((request) async {
          captured = request;
          return http.Response('{"message":"Verification code sent."}', 200);
        });
        final client = HttpWhatsAppOtpBackendClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
        );

        await client.sendOtp('+923001234567');

        expect(
          captured!.url.toString(),
          'http://backend.test/auth/phone/send-otp',
        );
        expect(jsonDecode(captured!.body), {'phone_number': '+923001234567'});
      },
    );

    test(
      'sendOtp throws WhatsAppOtpException with the server detail on failure',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"detail":"Please wait 12s before requesting another code."}',
            429,
          );
        });
        final client = HttpWhatsAppOtpBackendClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
        );

        expect(
          () => client.sendOtp('+923001234567'),
          throwsA(
            isA<WhatsAppOtpException>().having(
              (e) => e.message,
              'message',
              contains('wait 12s'),
            ),
          ),
        );
      },
    );

    test('verifyOtp returns the firebase_token on success', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"firebase_token":"abc.def.ghi"}', 200);
      });
      final client = HttpWhatsAppOtpBackendClient(
        baseUrl: 'http://backend.test',
        httpClient: mockClient,
      );

      final token = await client.verifyOtp(
        phoneNumber: '+923001234567',
        otp: '123456',
      );

      expect(token, 'abc.def.ghi');
    });

    test(
      'verifyOtp throws WhatsAppOtpException on a non-200 response',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"detail":"Invalid or expired verification code."}',
            400,
          );
        });
        final client = HttpWhatsAppOtpBackendClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
        );

        expect(
          () => client.verifyOtp(phoneNumber: '+923001234567', otp: '000000'),
          throwsA(isA<WhatsAppOtpException>()),
        );
      },
    );

    test(
      'a network failure surfaces as WhatsAppOtpException, not a raw exception',
      () async {
        final mockClient = MockClient((request) async {
          throw Exception('socket closed');
        });
        final client = HttpWhatsAppOtpBackendClient(
          baseUrl: 'http://backend.test',
          httpClient: mockClient,
        );

        expect(
          () => client.sendOtp('+923001234567'),
          throwsA(isA<WhatsAppOtpException>()),
        );
      },
    );
  });
}

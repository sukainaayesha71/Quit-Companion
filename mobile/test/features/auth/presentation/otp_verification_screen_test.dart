import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/controllers/phone_auth_controller.dart';
import 'package:quit_companion/features/auth/data/fake_phone_auth_repository.dart';
import 'package:quit_companion/features/auth/presentation/screens/otp_verification_screen.dart';

void main() {
  Future<void> enterCode(WidgetTester tester, String code) async {
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(find.byKey(Key('otp_digit_field_$i')), code[i]);
    }
  }

  testWidgets('entering the correct code and verifying calls onVerified', (
    tester,
  ) async {
    final controller = PhoneAuthController(
      FakePhoneAuthRepository(),
      cooldownDuration: const Duration(milliseconds: 20),
      tickInterval: const Duration(milliseconds: 10),
    );
    await controller.sendOtp(phoneNumber: '+14155552671');
    String? verifiedUserId;

    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationScreen(
          phoneNumber: '+14155552671',
          phoneAuthController: controller,
          onVerified: (userId) => verifiedUserId = userId,
        ),
      ),
    );

    await enterCode(tester, '123456');
    await tester.tap(find.byKey(const Key('otp_verify_button')));
    await tester.pumpAndSettle();

    expect(verifiedUserId, '+14155552671');
    expect(find.byKey(const Key('otp_error_text')), findsNothing);
  });

  testWidgets('an incorrect code shows an error and does not call onVerified', (
    tester,
  ) async {
    final controller = PhoneAuthController(
      FakePhoneAuthRepository(),
      cooldownDuration: const Duration(milliseconds: 20),
      tickInterval: const Duration(milliseconds: 10),
    );
    await controller.sendOtp(phoneNumber: '+14155552671');
    var verified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationScreen(
          phoneNumber: '+14155552671',
          phoneAuthController: controller,
          onVerified: (_) => verified = true,
        ),
      ),
    );

    await enterCode(tester, '000000');
    await tester.tap(find.byKey(const Key('otp_verify_button')));
    await tester.pumpAndSettle();

    expect(verified, isFalse);
    expect(find.byKey(const Key('otp_error_text')), findsOneWidget);
  });

  testWidgets(
    'resend button is disabled during the cooldown and enables after it elapses',
    (tester) async {
      final controller = PhoneAuthController(
        FakePhoneAuthRepository(),
        cooldownDuration: const Duration(milliseconds: 30),
        tickInterval: const Duration(milliseconds: 10),
      );
      await controller.sendOtp(phoneNumber: '+14155552671');

      await tester.pumpWidget(
        MaterialApp(
          home: OtpVerificationScreen(
            phoneNumber: '+14155552671',
            phoneAuthController: controller,
            onVerified: (_) {},
          ),
        ),
      );
      await tester.pump();

      final resendButton = tester.widget<TextButton>(
        find.byKey(const Key('otp_resend_button')),
      );
      expect(resendButton.onPressed, isNull);

      await tester.pump(const Duration(milliseconds: 60));

      final resendButtonAfter = tester.widget<TextButton>(
        find.byKey(const Key('otp_resend_button')),
      );
      expect(resendButtonAfter.onPressed, isNotNull);
    },
  );

  testWidgets(
    'shows a disabled, spinning verify button while status is verifying',
    (tester) async {
      final controller = PhoneAuthController(
        FakePhoneAuthRepository(),
        cooldownDuration: const Duration(milliseconds: 20),
        tickInterval: const Duration(milliseconds: 10),
      );
      await controller.sendOtp(phoneNumber: '+14155552671');

      await tester.pumpWidget(
        MaterialApp(
          home: OtpVerificationScreen(
            phoneNumber: '+14155552671',
            phoneAuthController: controller,
            onVerified: (_) {},
          ),
        ),
      );

      // Drive the controller straight into the verifying state — proves the
      // UI reacts correctly to that status without racing a real async gap.
      controller.status = PhoneAuthStatus.verifying;
      controller.notifyListeners();
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('otp_verify_button')),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let the cooldown timer started by sendOtp run its course rather than
      // leaving it pending at teardown.
      await tester.pump(const Duration(milliseconds: 30));
    },
  );

  testWidgets(
    'does not overflow on a short physical screen with an error message shown',
    (tester) async {
      final controller = PhoneAuthController(
        FakePhoneAuthRepository(),
        cooldownDuration: const Duration(milliseconds: 20),
        tickInterval: const Duration(milliseconds: 10),
      );
      await controller.sendOtp(phoneNumber: '+14155552671');

      // Reproduces the reported "BOTTOM OVERFLOWED BY 16 PIXELS" on a
      // physical device: a short viewport (well under a typical phone's
      // logical height) with the error text visible, which is the tallest
      // the column ever gets.
      tester.view.physicalSize = const Size(360, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OtpVerificationScreen(
            phoneNumber: '+14155552671',
            phoneAuthController: controller,
            onVerified: (_) {},
          ),
        ),
      );

      // Drive the controller straight into the error state — proves the
      // layout survives the tallest content case without a real async gap.
      controller.errorMessage = 'Invalid or expired code.';
      controller.status = PhoneAuthStatus.error;
      controller.notifyListeners();
      await tester.pump();

      expect(find.byKey(const Key('otp_error_text')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Let the cooldown timer started by sendOtp run its course rather than
      // leaving it pending at teardown.
      await tester.pump(const Duration(milliseconds: 30));
    },
  );
}

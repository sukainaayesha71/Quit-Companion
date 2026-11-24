import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/controllers/phone_auth_controller.dart';
import 'package:quit_companion/features/auth/data/fake_phone_auth_repository.dart';
import 'package:quit_companion/features/auth/presentation/screens/phone_sign_in_screen.dart';

void main() {
  testWidgets(
    'entering a valid number and tapping Send OTP calls onOtpSent with the normalized number',
    (tester) async {
      final controller = PhoneAuthController(
        FakePhoneAuthRepository(),
        cooldownDuration: const Duration(milliseconds: 20),
        tickInterval: const Duration(milliseconds: 10),
      );
      String? sentPhoneNumber;

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneSignInScreen(
            controller: controller,
            onOtpSent: (phoneNumber) => sentPhoneNumber = phoneNumber,
            onBack: () {},
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('phone_sign_in_number_field')),
        '+14155552671',
      );
      await tester.tap(find.byKey(const Key('phone_sign_in_send_otp_button')));
      await tester.pumpAndSettle();

      expect(sentPhoneNumber, '+14155552671');
      expect(controller.status, PhoneAuthStatus.otpSent);
    },
  );

  testWidgets(
    'an invalid number shows an inline error and does not call onOtpSent',
    (tester) async {
      final controller = PhoneAuthController(
        FakePhoneAuthRepository(),
        cooldownDuration: const Duration(milliseconds: 20),
        tickInterval: const Duration(milliseconds: 10),
      );
      var otpSent = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PhoneSignInScreen(
            controller: controller,
            onOtpSent: (_) => otpSent = true,
            onBack: () {},
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('phone_sign_in_number_field')),
        '123',
      );
      await tester.tap(find.byKey(const Key('phone_sign_in_send_otp_button')));
      await tester.pumpAndSettle();

      expect(otpSent, isFalse);
      expect(find.byKey(const Key('phone_sign_in_error_text')), findsOneWidget);
    },
  );

  testWidgets('tapping Back calls onBack', (tester) async {
    final controller = PhoneAuthController(FakePhoneAuthRepository());
    var backTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PhoneSignInScreen(
          controller: controller,
          onOtpSent: (_) {},
          onBack: () => backTapped = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('phone_sign_in_back_button')));
    await tester.pumpAndSettle();

    expect(backTapped, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/controllers/phone_auth_controller.dart';
import 'package:quit_companion/features/auth/data/fake_phone_auth_repository.dart';

void main() {
  PhoneAuthController buildController({bool failSend = false}) {
    return PhoneAuthController(
      FakePhoneAuthRepository(failSend: failSend),
      cooldownDuration: const Duration(milliseconds: 40),
      tickInterval: const Duration(milliseconds: 10),
    );
  }

  test(
    'sendOtp rejects an empty phone number without touching the repository',
    () async {
      final repo = FakePhoneAuthRepository();
      final controller = PhoneAuthController(repo);

      final success = await controller.sendOtp(phoneNumber: '');

      expect(success, isFalse);
      expect(controller.status, PhoneAuthStatus.error);
      expect(controller.errorMessage, contains('required'));
      expect(repo.sendCount, 0);
    },
  );

  test('sendOtp rejects a malformed phone number', () async {
    final controller = buildController();

    final success = await controller.sendOtp(phoneNumber: '0123');

    expect(success, isFalse);
    expect(controller.status, PhoneAuthStatus.error);
    expect(controller.errorMessage, contains('valid phone number'));
  });

  test('validatePhoneNumber accepts a valid Pakistani E.164 mobile number', () {
    final controller = buildController();

    expect(controller.validatePhoneNumber('+923357606070'), isNull);
  });

  test(
    'sendOtp accepts a valid Pakistani number and passes it unchanged to the repository',
    () async {
      final repo = FakePhoneAuthRepository();
      final controller = PhoneAuthController(
        repo,
        cooldownDuration: const Duration(milliseconds: 40),
        tickInterval: const Duration(milliseconds: 10),
      );

      final success = await controller.sendOtp(phoneNumber: '+923357606070');

      expect(success, isTrue);
      expect(controller.status, PhoneAuthStatus.otpSent);
      expect(repo.lastPhoneNumber, '+923357606070');
    },
  );

  test('validatePhoneNumber rejects a genuinely too-short number', () {
    final controller = buildController();

    final error = controller.validatePhoneNumber('+9233');

    expect(error, isNotNull);
    expect(error, contains('valid phone number'));
  });

  test(
    'normalizePhoneNumber strips stray formatting characters without changing the digits',
    () {
      final controller = buildController();

      expect(
        controller.normalizePhoneNumber('+92 335 760 6070'),
        '+923357606070',
      );
      expect(
        controller.normalizePhoneNumber('+92-335-760-6070'),
        '+923357606070',
      );
      expect(
        controller.normalizePhoneNumber(' +923357606070 '),
        '+923357606070',
      );
    },
  );

  test(
    'sendOtp normalizes a number with stray formatting before validating and sending',
    () async {
      final repo = FakePhoneAuthRepository();
      final controller = PhoneAuthController(
        repo,
        cooldownDuration: const Duration(milliseconds: 40),
        tickInterval: const Duration(milliseconds: 10),
      );

      final success = await controller.sendOtp(phoneNumber: '+92-335-760-6070');

      expect(success, isTrue);
      expect(repo.lastPhoneNumber, '+923357606070');
    },
  );

  test(
    'sendOtp succeeds for a valid E.164 number and starts the cooldown',
    () async {
      final controller = buildController();

      final success = await controller.sendOtp(phoneNumber: '+14155552671');

      expect(success, isTrue);
      expect(controller.status, PhoneAuthStatus.otpSent);
      expect(controller.canResend, isFalse);
      expect(controller.resendCooldownSeconds, greaterThan(0));
    },
  );

  test(
    'sendOtp surfaces a repository failure (e.g. invalid phone number) as an error',
    () async {
      final controller = buildController(failSend: true);

      final success = await controller.sendOtp(phoneNumber: '+14155552671');

      expect(success, isFalse);
      expect(controller.status, PhoneAuthStatus.error);
      expect(controller.errorMessage, isNotNull);
    },
  );

  test('verifyOtp rejects a code that is not 6 digits', () async {
    final controller = buildController();
    await controller.sendOtp(phoneNumber: '+14155552671');

    final success = await controller.verifyOtp('123');

    expect(success, isFalse);
    expect(controller.status, PhoneAuthStatus.error);
    expect(controller.errorMessage, contains('6-digit'));
  });

  test('verifyOtp fails with an incorrect code', () async {
    final controller = buildController();
    await controller.sendOtp(phoneNumber: '+14155552671');

    final success = await controller.verifyOtp('000000');

    expect(success, isFalse);
    expect(controller.status, PhoneAuthStatus.error);
    expect(controller.errorMessage, contains('Invalid or expired'));
  });

  test(
    'verifyOtp fails if no OTP was ever sent (expired/missing session)',
    () async {
      final controller = buildController();

      final success = await controller.verifyOtp('123456');

      expect(success, isFalse);
      expect(controller.status, PhoneAuthStatus.error);
      expect(controller.errorMessage, contains('expired'));
    },
  );

  test('verifyOtp succeeds with the correct code', () async {
    final controller = buildController();
    await controller.sendOtp(phoneNumber: '+14155552671');

    final success = await controller.verifyOtp('123456');

    expect(success, isTrue);
    expect(controller.status, PhoneAuthStatus.success);
    expect(controller.userId, '+14155552671');
  });

  test('resendOtp is blocked while the cooldown is active', () async {
    final controller = buildController();
    await controller.sendOtp(phoneNumber: '+14155552671');

    expect(controller.canResend, isFalse);
    final resent = await controller.resendOtp();
    expect(resent, isFalse);
  });

  test('resendOtp succeeds once the cooldown elapses', () async {
    final repo = FakePhoneAuthRepository();
    final controller = PhoneAuthController(
      repo,
      cooldownDuration: const Duration(milliseconds: 20),
      tickInterval: const Duration(milliseconds: 5),
    );
    await controller.sendOtp(phoneNumber: '+14155552671');
    expect(repo.sendCount, 1);

    await Future.delayed(const Duration(milliseconds: 60));

    expect(controller.canResend, isTrue);
    final resent = await controller.resendOtp();
    expect(resent, isTrue);
    expect(repo.sendCount, 2);
  });

  test('sendOtp sets sendingOtp status while in flight', () async {
    final controller = buildController();

    final future = controller.sendOtp(phoneNumber: '+14155552671');
    expect(controller.status, PhoneAuthStatus.sendingOtp);
    await future;
    expect(controller.status, PhoneAuthStatus.otpSent);
  });

  test(
    'reset clears status, error, and the pending verification session',
    () async {
      final controller = buildController();
      await controller.sendOtp(phoneNumber: '+14155552671');
      await controller.verifyOtp('000000');
      expect(controller.status, PhoneAuthStatus.error);

      controller.reset();

      expect(controller.status, PhoneAuthStatus.idle);
      expect(controller.errorMessage, isNull);
      // The verification session was cleared too, so a stale code now fails cleanly.
      final success = await controller.verifyOtp('123456');
      expect(success, isFalse);
      expect(controller.errorMessage, contains('expired'));
    },
  );
}

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/data/firebase_auth_repository.dart';

const _rawInvalidCredential =
    'The supplied auth credential is incorrect, malformed or has expired.';

fb.FirebaseAuthException _error(String code, [String? message]) =>
    fb.FirebaseAuthException(code: code, message: message);

void main() {
  group('loginErrorMessage', () {
    test(
      'invalid-credential (wrong password, unknown email or Google-only '
      'account under email enumeration protection) gets an actionable message',
      () {
        final message = loginErrorMessage(
          _error('invalid-credential', _rawInvalidCredential),
        );
        expect(message, isNot(contains('malformed')));
        expect(message, contains('Incorrect email or password'));
        expect(message, contains('Continue with Google'));
        expect(message, contains('Forgot Password?'));
      },
    );

    test('legacy wrong-password / user-not-found codes read the same way', () {
      final expected = loginErrorMessage(_error('invalid-credential'));
      expect(loginErrorMessage(_error('wrong-password')), expected);
      expect(loginErrorMessage(_error('user-not-found')), expected);
      expect(loginErrorMessage(_error('invalid-login-credentials')), expected);
    });

    test('other known codes get specific messages', () {
      expect(
        loginErrorMessage(_error('too-many-requests')),
        contains('Too many attempts'),
      );
      expect(
        loginErrorMessage(_error('network-request-failed')),
        contains('Check your connection'),
      );
      expect(
        loginErrorMessage(_error('user-disabled')),
        contains('disabled'),
      );
      expect(
        loginErrorMessage(_error('invalid-email')),
        contains('valid email'),
      );
    });

    test('unknown codes keep Firebase\'s own message, with a fallback', () {
      expect(
        loginErrorMessage(_error('internal-error', 'Something specific.')),
        'Something specific.',
      );
      expect(loginErrorMessage(_error('internal-error')), 'Login failed.');
    });
  });

  group('registrationErrorMessage', () {
    test('email-already-in-use points to login or Google sign-in', () {
      final message = registrationErrorMessage(_error('email-already-in-use'));
      expect(message, contains('already exists'));
      expect(message, contains('Log in instead'));
      expect(message, contains('Continue with Google'));
    });

    test('password policy rejections state the enforced policy', () {
      const policy =
          'Use at least 8 characters, with a lowercase letter and a number.';
      expect(registrationErrorMessage(_error('weak-password')), policy);
      expect(
        registrationErrorMessage(
          _error('password-does-not-meet-requirements'),
        ),
        policy,
      );
    });

    test('unknown codes keep Firebase\'s own message, with a fallback', () {
      expect(
        registrationErrorMessage(_error('internal-error', 'Specific.')),
        'Specific.',
      );
      expect(
        registrationErrorMessage(_error('internal-error')),
        'Registration failed.',
      );
    });
  });
}

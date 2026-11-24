import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/data/auth_repository.dart';
import 'package:quit_companion/features/auth/data/fake_auth_repository.dart';

void main() {
  test('register fails validation for a malformed email', () async {
    final controller = AuthController(FakeAuthRepository());

    final success = await controller.register(
      email: 'not-an-email',
      password: 'password123',
    );

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  test('register fails validation for a short password', () async {
    final controller = AuthController(FakeAuthRepository());

    final success = await controller.register(
      email: 'a@b.com',
      password: 'short',
    );

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
  });

  test('register succeeds with valid credentials', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository);

    final success = await controller.register(
      email: 'a@b.com',
      password: 'password123',
    );

    expect(success, isTrue);
    expect(controller.status, AuthStatus.success);
    expect(controller.userId, isNull);
    expect(repository.currentUserId, isNull);
  });

  test(
    'register surfaces a duplicate-account error from the repository',
    () async {
      final repo = FakeAuthRepository();
      await repo.registerWithEmailPassword(
        email: 'a@b.com',
        password: 'password123',
      );
      final controller = AuthController(repo);

      final success = await controller.register(
        email: 'a@b.com',
        password: 'password123',
      );

      expect(success, isFalse);
      expect(controller.status, AuthStatus.error);
      expect(controller.errorMessage, contains('already exists'));
    },
  );

  test('login succeeds with matching credentials', () async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmailPassword(
      email: 'a@b.com',
      password: 'password123',
    );
    final controller = AuthController(repo);

    final success = await controller.login(
      email: 'a@b.com',
      password: 'password123',
    );

    expect(success, isTrue);
    expect(controller.userId, 'a@b.com');
  });

  test(
    'password reset validates email and sends through the repository',
    () async {
      final repository = FakeAuthRepository();
      await repository.registerWithEmailPassword(
        email: 'a@b.com',
        password: 'password123',
      );
      final controller = AuthController(repository);

      expect(
        await controller.requestPasswordReset(email: 'bad-email'),
        isFalse,
      );
      expect(controller.status, AuthStatus.error);
      expect(controller.errorMessage, contains('valid email'));

      expect(await controller.requestPasswordReset(email: ' a@b.com '), isTrue);
      expect(repository.passwordResetEmailSentTo, 'a@b.com');
      expect(controller.status, AuthStatus.success);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'password reset exposes repository errors and clears them after a successful retry',
    () async {
      final repository = FakeAuthRepository()
        ..passwordResetError = AuthException('Reset service unavailable.');
      final controller = AuthController(repository);

      expect(await controller.requestPasswordReset(email: 'a@b.com'), isFalse);
      expect(controller.status, AuthStatus.error);
      expect(controller.errorMessage, 'Reset service unavailable.');

      repository.passwordResetError = null;
      await repository.registerWithEmailPassword(
        email: 'a@b.com',
        password: 'password123',
      );
      expect(await controller.requestPasswordReset(email: 'a@b.com'), isTrue);
      expect(controller.errorMessage, isNull);
    },
  );

  test('initializes signed-in identity from the repository safe getters', () {
    final repository = FakeAuthRepository(
      currentUserId: 'seeded-uid',
      currentEmail: 'current@b.com',
      currentDisplayName: 'Current User',
    );

    final controller = AuthController(repository);

    expect(controller.userId, 'seeded-uid');
    expect(repository.currentEmail, 'current@b.com');
    expect(repository.currentDisplayName, 'Current User');
  });

  test('login fails with wrong password', () async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmailPassword(
      email: 'a@b.com',
      password: 'password123',
    );
    final controller = AuthController(repo);

    final success = await controller.login(
      email: 'a@b.com',
      password: 'wrong-password',
    );

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
  });

  test('login fails validation for an empty password', () async {
    final controller = AuthController(FakeAuthRepository());

    final success = await controller.login(email: 'a@b.com', password: '');

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  test(
    'login accepts an existing password that does not meet registration rules',
    () async {
      final repository = FakeAuthRepository();
      await repository.registerWithEmailPassword(
        email: 'a@b.com',
        password: 'short',
      );
      final controller = AuthController(repository);

      final success = await controller.login(
        email: 'a@b.com',
        password: 'short',
      );

      expect(success, isTrue);
      expect(controller.status, AuthStatus.success);
    },
  );

  test('login fails validation for a malformed email', () async {
    final controller = AuthController(FakeAuthRepository());

    final success = await controller.login(
      email: 'not-an-email',
      password: 'password123',
    );

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  test(
    'signInWithGoogle succeeds and returns the Google account\'s userId/email',
    () async {
      final repo = FakeAuthRepository()
        ..googleSignInResult = GoogleAuthResult(
          userId: 'google-uid',
          email: 'user@gmail.com',
        );
      final controller = AuthController(repo);

      final result = await controller.signInWithGoogle();

      expect(result, isNotNull);
      expect(result!.userId, 'google-uid');
      expect(result.email, 'user@gmail.com');
      expect(controller.status, AuthStatus.success);
      expect(controller.userId, 'google-uid');
    },
  );

  test(
    'signInWithGoogle returns null and resets to idle when the user cancels the picker',
    () async {
      final repo = FakeAuthRepository()..googleSignInCanceled = true;
      final controller = AuthController(repo);

      final result = await controller.signInWithGoogle();

      expect(result, isNull);
      expect(controller.status, AuthStatus.idle);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'signInWithGoogle surfaces a real failure as an error, not a silent no-op',
    () async {
      final repo = FakeAuthRepository()
        ..googleSignInError = AuthException('Google sign-in failed.');
      final controller = AuthController(repo);

      final result = await controller.signInWithGoogle();

      expect(result, isNull);
      expect(controller.status, AuthStatus.error);
      expect(controller.errorMessage, 'Google sign-in failed.');
    },
  );

  test('clearError resets a stale error status back to idle', () async {
    final controller = AuthController(FakeAuthRepository());
    await controller.register(email: 'not-an-email', password: 'password123');
    expect(controller.status, AuthStatus.error);
    expect(controller.errorMessage, isNotNull);

    controller.clearError();

    expect(controller.status, AuthStatus.idle);
    expect(controller.errorMessage, isNull);
  });

  test('logout clears the current user id', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository);
    await controller.register(email: 'a@b.com', password: 'password1');
    expect(controller.userId, isNull);

    await controller.login(email: 'a@b.com', password: 'password1');
    expect(controller.userId, isNotNull);

    await controller.logout();

    expect(controller.userId, isNull);
    expect(repository.currentUserId, isNull);
  });
}

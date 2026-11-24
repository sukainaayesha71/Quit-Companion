import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/data/auth_repository.dart';
import 'package:quit_companion/features/auth/data/fake_auth_repository.dart';
import 'package:quit_companion/features/auth/data/fake_biometric_lock_service.dart';
import 'package:quit_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'a successful Google sign-in calls onLoggedIn with the Google account\'s userId/email',
    (tester) async {
      final repo = FakeAuthRepository()
        ..googleSignInResult = GoogleAuthResult(
          userId: 'google-uid-123',
          email: 'googleuser@gmail.com',
        );
      final controller = AuthController(repo);
      String? loggedInUserId;
      String? loggedInEmail;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: LoginScreen(
              onLoggedIn: (userId, email) {
                loggedInUserId = userId;
                loggedInEmail = email;
              },
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('login_google_button')));
      await tester.tap(find.byKey(const Key('login_google_button')));
      await tester.pumpAndSettle();

      expect(loggedInUserId, 'google-uid-123');
      expect(loggedInEmail, 'googleuser@gmail.com');
    },
  );

  testWidgets(
    'canceling the Google account picker does not log in and shows no error',
    (tester) async {
      final repo = FakeAuthRepository()..googleSignInCanceled = true;
      final controller = AuthController(repo);
      var called = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: LoginScreen(onLoggedIn: (_, _) => called = true),
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('login_google_button')));
      await tester.tap(find.byKey(const Key('login_google_button')));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.byKey(const Key('login_error_text')), findsNothing);
    },
  );

  testWidgets(
    'a Google sign-in failure shows an error message and does not log in',
    (tester) async {
      final repo = FakeAuthRepository()
        ..googleSignInError = AuthException('Google sign-in failed.');
      final controller = AuthController(repo);
      var called = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: LoginScreen(onLoggedIn: (_, _) => called = true),
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('login_google_button')));
      await tester.tap(find.byKey(const Key('login_google_button')));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.byKey(const Key('login_error_text')), findsOneWidget);
      expect(find.text('Google sign-in failed.'), findsOneWidget);
    },
  );

  testWidgets(
    'fingerprint sign-in authenticates saved email/password credentials',
    (tester) async {
      final repository = FakeAuthRepository();
      await repository.registerWithEmailPassword(
        email: 'returning@example.com',
        password: 'password123',
      );
      final controller = AuthController(repository);
      final biometricService = FakeBiometricLockService(
        available: true,
        enabledUserId: 'returning@example.com',
        savedEmail: 'returning@example.com',
        savedPassword: 'password123',
      );
      String? loggedInUserId;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: LoginScreen(
              biometricLockService: biometricService,
              onLoggedIn: (userId, _) => loggedInUserId = userId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('login_biometric_button')),
      );
      await tester.tap(find.byKey(const Key('login_biometric_button')));
      await tester.pumpAndSettle();

      expect(loggedInUserId, 'returning@example.com');
      expect(
        biometricService.authenticationReasons,
        contains('Sign in to Quit Companion with your fingerprint.'),
      );
    },
  );

  testWidgets(
    'fingerprint sign-in button explains setup when no credential is saved',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());
      final biometricService = FakeBiometricLockService();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: LoginScreen(
              biometricLockService: biometricService,
              onLoggedIn: (_, _) {},
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('login_biometric_button')),
      );
      await tester.tap(find.byKey(const Key('login_biometric_button')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('enable fingerprint sign-in in Profile'),
        findsOneWidget,
      );
    },
  );

  testWidgets('fingerprint login is a circular icon beside the security row', (
    tester,
  ) async {
    final controller = AuthController(FakeAuthRepository());
    final biometricService = FakeBiometricLockService(
      available: true,
      enabledUserId: 'returning@example.com',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: LoginScreen(
            biometricLockService: biometricService,
            onLoggedIn: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fingerprintButton = tester.widget<IconButton>(
      find.byKey(const Key('login_biometric_button')),
    );
    expect(fingerprintButton.tooltip, 'Sign in with fingerprint');
    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    expect(
      find.byKey(const Key('login_remove_biometric_button')),
      findsNothing,
    );
    expect(
      tester.getCenter(find.byKey(const Key('login_biometric_button'))).dy,
      closeTo(
        tester.getCenter(find.text('Secured by Firebase Authentication')).dy,
        12,
      ),
    );
  });

  testWidgets('submitting valid credentials calls onLoggedIn with the userId', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmailPassword(
      email: 'a@b.com',
      password: 'password123',
    );
    final controller = AuthController(repo);
    String? loggedInUserId;
    String? loggedInEmail;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: LoginScreen(
            onLoggedIn: (userId, email) {
              loggedInUserId = userId;
              loggedInEmail = email;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'a@b.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(loggedInUserId, 'a@b.com');
    expect(loggedInEmail, 'a@b.com');
  });

  testWidgets('shows specific inline errors for missing email and password', (
    tester,
  ) async {
    final controller = AuthController(FakeAuthRepository());

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(home: LoginScreen(onLoggedIn: (_, _) {})),
      ),
    );

    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.byKey(const Key('login_error_text')), findsNothing);
    expect(controller.status, AuthStatus.idle);
  });

  testWidgets('forgot password validates and submits the entered email', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await repository.registerWithEmailPassword(
      email: 'a@b.com',
      password: 'password123',
    );
    final controller = AuthController(repository);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(home: LoginScreen(onLoggedIn: (_, _) {})),
      ),
    );
    await tester.tap(find.byKey(const Key('login_forgot_password_link')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('forgot_password_email_field')),
      'bad-email',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot_password_error_text')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('forgot_password_email_field')),
      'a@b.com',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit_button')));
    await tester.pumpAndSettle();

    expect(repository.passwordResetEmailSentTo, 'a@b.com');
    expect(
      find.textContaining('password reset link has been sent'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows only Email and Password fields, matching the Login screenshot',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(home: LoginScreen(onLoggedIn: (_, _) {})),
        ),
      );

      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/images/google_g_logo.png')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('login_forgot_password_link')),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping the phone sign-in link invokes onPhoneSignInTap', (
    tester,
  ) async {
    final controller = AuthController(FakeAuthRepository());
    var tapped = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: LoginScreen(
            onLoggedIn: (_, _) {},
            onPhoneSignInTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('login_phone_sign_in_link')),
    );
    await tester.tap(find.byKey(const Key('login_phone_sign_in_link')));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets(
    'the phone sign-in link is absent when onPhoneSignInTap is not provided',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(home: LoginScreen(onLoggedIn: (_, _) {})),
        ),
      );

      expect(find.byKey(const Key('login_phone_sign_in_link')), findsNothing);
    },
  );

  testWidgets(
    'previously used emails appear as suggestions on the email field',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'recent_emails': ['returning@user.com'],
      });
      final controller = AuthController(FakeAuthRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(home: LoginScreen(onLoggedIn: (_, _) {})),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_email_field')));
      await tester.pumpAndSettle();

      expect(find.text('returning@user.com'), findsOneWidget);
    },
  );
}

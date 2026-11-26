import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/data/auth_repository.dart';
import 'package:quit_companion/features/auth/data/fake_auth_repository.dart';
import 'package:quit_companion/features/auth/presentation/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('email registration requires verification before continuing', (
    tester,
  ) async {
    final controller = AuthController(FakeAuthRepository());
    String? registeredUserId;
    var loginTapped = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: RegisterScreen(
            onRegistered: (userId, email, name) {
              registeredUserId = userId;
            },
            onLoginTap: () => loginTapped = true,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'a@b.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'password123',
    );
    await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(registeredUserId, isNull);
    expect(
      find.byKey(const Key('register_verification_notice')),
      findsOneWidget,
    );
    expect(
      find.textContaining('We sent a verification link to a@b.com'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('register_submit_button')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('register_login_link')));
    await tester.tap(find.byKey(const Key('register_login_link')));
    expect(loginTapped, isTrue);
  });

  testWidgets(
    'offers email/password and Google sign-up only, with no phone option',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(home: RegisterScreen(onRegistered: (_, _, _) {})),
        ),
      );

      expect(find.byKey(const Key('register_google_button')), findsOneWidget);
      expect(
        find.byKey(const Key('register_phone_sign_in_link')),
        findsNothing,
      );
      expect(find.textContaining('Phone'), findsNothing);
    },
  );

  testWidgets(
    'shows an inline email format error before attempting registration',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(home: RegisterScreen(onRegistered: (_, _, _) {})),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'not-an-email',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'password123',
      );
      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid email address, like name@example.com.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('register_error_text')), findsNothing);
      expect(controller.status, AuthStatus.idle);
    },
  );

  testWidgets('shows actionable inline password requirements', (tester) async {
    final controller = AuthController(FakeAuthRepository());

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(home: RegisterScreen(onRegistered: (_, _, _) {})),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'PASSWORD123',
    );
    await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Add at least one lowercase letter.'), findsOneWidget);
    expect(find.byKey(const Key('register_error_text')), findsNothing);
    expect(controller.status, AuthStatus.idle);
  });

  testWidgets(
    'shows Full Name, Email and Password as a single unified form, without a phone number',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(home: RegisterScreen(onRegistered: (_, _, _) {})),
        ),
      );

      expect(find.byKey(const Key('register_name_field')), findsOneWidget);
      expect(find.byKey(const Key('register_email_field')), findsOneWidget);
      expect(find.byKey(const Key('register_password_field')), findsOneWidget);
      expect(find.byKey(const Key('register_phone_field')), findsNothing);
    },
  );

  testWidgets('shows the password requirements hint near the password field', (
    tester,
  ) async {
    final controller = AuthController(FakeAuthRepository());

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(home: RegisterScreen(onRegistered: (_, _, _) {})),
      ),
    );

    expect(find.byKey(const Key('register_password_hint')), findsOneWidget);
    expect(
      find.text(
        'Must be at least 8 characters, with a lowercase letter and a number.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'the Terms & Privacy Policy checkbox does not block Create Account',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());
      String? registeredUserId;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: RegisterScreen(
              onRegistered: (userId, _, _) => registeredUserId = userId,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('register_terms_checkbox')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'a@b.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'password123',
      );
      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(registeredUserId, isNull);
      expect(
        find.byKey(const Key('register_verification_notice')),
        findsOneWidget,
      );
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
          child: MaterialApp(home: RegisterScreen(onRegistered: (_, _, _) {})),
        ),
      );
      // Recent emails load asynchronously in initState.
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('register_email_field')));
      await tester.tap(find.byKey(const Key('register_email_field')));
      await tester.pumpAndSettle();

      expect(find.text('returning@user.com'), findsOneWidget);
    },
  );

  testWidgets(
    'renders the register screen 3 reference layout: hero header, Create Your Account heading, and Google button',
    (tester) async {
      final controller = AuthController(FakeAuthRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(home: RegisterScreen(onRegistered: (_, _, _) {})),
        ),
      );

      expect(find.text('Create Your\nAccount'), findsOneWidget);
      expect(find.text("Let's start your recovery journey."), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/images/register_hero.png')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('register_google_button')), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/images/google_g_logo.png')),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  testWidgets(
    'a successful Google sign-in calls onRegistered with the Google account\'s userId/email',
    (tester) async {
      final fakeAuthRepository = FakeAuthRepository()
        ..googleSignInResult = GoogleAuthResult(
          userId: 'google-uid-123',
          email: 'googleuser@gmail.com',
        );
      final controller = AuthController(fakeAuthRepository);
      String? registeredUserId;
      String? registeredEmail;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: RegisterScreen(
              onRegistered: (userId, email, name) {
                registeredUserId = userId;
                registeredEmail = email;
              },
            ),
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('register_google_button')),
      );
      await tester.tap(find.byKey(const Key('register_google_button')));
      await tester.pumpAndSettle();

      expect(registeredUserId, 'google-uid-123');
      expect(registeredEmail, 'googleuser@gmail.com');
    },
  );

  testWidgets(
    'a Google sign-in with a display name passes it through to onRegistered',
    (tester) async {
      final fakeAuthRepository = FakeAuthRepository()
        ..googleSignInResult = GoogleAuthResult(
          userId: 'google-uid-456',
          email: 'g@gmail.com',
          name: 'Sukaina Ayesha',
        );
      final controller = AuthController(fakeAuthRepository);
      String? registeredName;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: RegisterScreen(
              onRegistered: (_, _, name) => registeredName = name,
            ),
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('register_google_button')),
      );
      await tester.tap(find.byKey(const Key('register_google_button')));
      await tester.pumpAndSettle();

      expect(registeredName, 'Sukaina Ayesha');
    },
  );

  testWidgets(
    'canceling the Google account picker does not register a user and shows no error',
    (tester) async {
      final fakeAuthRepository = FakeAuthRepository()
        ..googleSignInCanceled = true;
      final controller = AuthController(fakeAuthRepository);
      var registeredCount = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: RegisterScreen(onRegistered: (_, _, _) => registeredCount++),
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('register_google_button')),
      );
      await tester.tap(find.byKey(const Key('register_google_button')));
      await tester.pumpAndSettle();

      expect(registeredCount, 0);
      expect(find.byKey(const Key('register_error_text')), findsNothing);
      expect(controller.status, AuthStatus.idle);
    },
  );

  testWidgets(
    'a Google sign-in failure shows an error message and does not register a user',
    (tester) async {
      final fakeAuthRepository = FakeAuthRepository()
        ..googleSignInError = AuthException('Google sign-in failed.');
      final controller = AuthController(fakeAuthRepository);
      var registeredCount = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: RegisterScreen(onRegistered: (_, _, _) => registeredCount++),
          ),
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('register_google_button')),
      );
      await tester.tap(find.byKey(const Key('register_google_button')));
      await tester.pumpAndSettle();

      expect(registeredCount, 0);
      expect(find.byKey(const Key('register_error_text')), findsOneWidget);
      expect(find.text('Google sign-in failed.'), findsOneWidget);
    },
  );

  testWidgets('registration preserves the full name for the later login flow', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository);
    var onRegisteredCalled = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: RegisterScreen(
            onRegistered: (_, _, _) => onRegisteredCalled = true,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register_name_field')),
      'Sukaina Ayesha',
    );
    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'sukaina@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'password123',
    );
    await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(onRegisteredCalled, isFalse);
    expect(
      await controller.login(
        email: 'sukaina@example.com',
        password: 'password123',
      ),
      isTrue,
    );
    expect(repository.currentDisplayName, 'Sukaina Ayesha');
  });

  testWidgets(
    'a blank Full Name field remains unset while waiting for verification',
    (tester) async {
      final repository = FakeAuthRepository();
      final controller = AuthController(repository);
      var onRegisteredCalled = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: MaterialApp(
            home: RegisterScreen(
              onRegistered: (_, _, name) {
                onRegisteredCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'noname@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'password123',
      );
      await tester.ensureVisible(
        find.byKey(const Key('register_submit_button')),
      );
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(onRegisteredCalled, isFalse);
      expect(
        find.byKey(const Key('register_verification_notice')),
        findsOneWidget,
      );
      expect(
        await controller.login(
          email: 'noname@example.com',
          password: 'password123',
        ),
        isTrue,
      );
      expect(repository.currentDisplayName, isNull);
    },
  );

  testWidgets('email/password registration shows verification instructions', (
    tester,
  ) async {
    final controller = AuthController(FakeAuthRepository());
    String? registeredUserId;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: RegisterScreen(
            onRegistered: (userId, _, _) => registeredUserId = userId,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'still-works@b.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'password123',
    );
    await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(registeredUserId, isNull);
    expect(
      find.byKey(const Key('register_verification_notice')),
      findsOneWidget,
    );
  });
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/profile/presentation/screens/about_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/help_support_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/privacy_security_screen.dart';
import 'package:quit_companion/features/auth/data/fake_account_deletion_repository.dart';
import 'package:quit_companion/features/auth/data/fake_biometric_lock_service.dart';

void main() {
  testWidgets('PrivacySecurityScreen renders its title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacySecurityScreen()));
    expect(find.text('Privacy & Security'), findsWidgets);
  });

  testWidgets('biometric sign-in requires an available enrolled biometric', (
    tester,
  ) async {
    final biometricService = FakeBiometricLockService(available: true);
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySecurityScreen(
          userId: 'u1',
          biometricLockService: biometricService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(find.byKey(const Key('biometric_password_field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('biometric_password_field')),
      'password123',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('confirm_biometric_password_button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(
      find.byKey(const Key('confirm_biometric_password_button')),
    );
    await tester.tap(
      find.byKey(const Key('confirm_biometric_password_button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('biometric_password_field')), findsNothing);

    expect(biometricService.enabledUserId, 'u1');
    expect(biometricService.authenticationReasons, hasLength(1));
    expect(biometricService.savedPassword, 'password123');
  });

  testWidgets(
    'biometric sign-in is unavailable for accounts without email/password auth',
    (tester) async {
      final biometricService = FakeBiometricLockService(
        available: true,
        passwordSignInSupported: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacySecurityScreen(
            userId: 'u1',
            biometricLockService: biometricService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Fingerprint sign-in is currently available for email and password accounts only.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('biometric_password_field')), findsNothing);
      expect(biometricService.enabledUserId, isNull);
    },
  );

  testWidgets('disabling fingerprint sign-in removes the saved credentials', (
    tester,
  ) async {
    final biometricService = FakeBiometricLockService(
      available: true,
      enabledUserId: 'u1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySecurityScreen(
          userId: 'u1',
          biometricLockService: biometricService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(biometricService.enabledUserId, isNull);
    expect(biometricService.savedPassword, isNull);
    expect(find.text('Remove saved fingerprint sign-in'), findsNothing);
  });

  testWidgets(
    'account deletion requires typing DELETE and erases the account',
    (tester) async {
      final deletionRepository = FakeAccountDeletionRepository();
      final biometricService = FakeBiometricLockService(enabledUserId: 'u1');
      var accountDeleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacySecurityScreen(
            userId: 'u1',
            biometricLockService: biometricService,
            accountDeletionRepository: deletionRepository,
            onAccountDeleted: () async {
              accountDeleted = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('delete_account_button')),
      );
      await tester.tap(find.byKey(const Key('delete_account_button')));
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<TextButton>(
        find.byKey(const Key('confirm_delete_account_button')),
      );
      expect(confirmButton.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('delete_account_confirmation_field')),
        'DELETE',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_delete_account_button')));
      await tester.pumpAndSettle();

      expect(deletionRepository.deleteCount, 1);
      expect(biometricService.enabledUserId, isNull);
      expect(accountDeleted, isTrue);
    },
  );

  testWidgets('account deletion failure stays visible and does not sign out', (
    tester,
  ) async {
    final deletionRepository = FakeAccountDeletionRepository()
      ..errorMessage = 'Deletion failed.';
    var accountDeleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySecurityScreen(
          userId: 'u1',
          biometricLockService: FakeBiometricLockService(),
          accountDeletionRepository: deletionRepository,
          onAccountDeleted: () async {
            accountDeleted = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('delete_account_button')));
    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete_account_confirmation_field')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm_delete_account_button')));
    await tester.pumpAndSettle();

    expect(find.text('Deletion failed.'), findsOneWidget);
    expect(accountDeleted, isFalse);
  });

  testWidgets('HelpSupportScreen renders its title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
    expect(find.text('Help & Support'), findsWidgets);
  });

  testWidgets('AboutScreen renders the app name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    expect(find.text('Quit Companion'), findsWidgets);
  });
}

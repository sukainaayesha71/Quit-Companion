import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/auth/data/fake_auth_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/app/quit_companion_app.dart';

void main() {
  testWidgets(
    'a failed Register attempt does not leak a stale error onto the Login screen',
    (tester) async {
      final authRepository = FakeAuthRepository();
      await authRepository.registerWithEmailPassword(
        email: 'existing@example.com',
        password: 'password123',
      );
      await tester.pumpWidget(
        QuitCompanionApp(
          authRepository: authRepository,
          userRepository: FakeUserRepository(),
          cravingLogRepository: FakeCravingLogRepository(),
          journalRepository: FakeJournalRepository(),
        ),
      );

      await tester.tap(find.byKey(const Key('welcome_register_button')));
      await tester.pumpAndSettle();

      // Fail Register with a duplicate account after passing inline validation.
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'existing@example.com',
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

      expect(find.byKey(const Key('register_error_text')), findsOneWidget);

      // Navigate to Login via the new link.
      await tester.ensureVisible(find.byKey(const Key('register_login_link')));
      await tester.tap(find.byKey(const Key('register_login_link')));
      await tester.pumpAndSettle();

      // The stale Register error must not appear on the untouched Login form.
      expect(find.byKey(const Key('login_error_text')), findsNothing);
    },
  );

  testWidgets(
    'a failed Login attempt does not leak a stale error back onto the Register screen',
    (tester) async {
      await tester.pumpWidget(
        QuitCompanionApp(
          authRepository: FakeAuthRepository(),
          userRepository: FakeUserRepository(),
          cravingLogRepository: FakeCravingLogRepository(),
          journalRepository: FakeJournalRepository(),
        ),
      );

      await tester.tap(find.byKey(const Key('welcome_register_button')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('register_login_link')));
      await tester.tap(find.byKey(const Key('register_login_link')));
      await tester.pumpAndSettle();

      // Fail Login with a too-short password.
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'a@b.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'short',
      );
      await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_text')), findsOneWidget);

      // Navigate back to Register via the new link.
      await tester.ensureVisible(find.byKey(const Key('login_register_link')));
      await tester.tap(find.byKey(const Key('login_register_link')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register_error_text')), findsNothing);
    },
  );
}

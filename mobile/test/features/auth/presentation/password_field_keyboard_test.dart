import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/data/fake_auth_repository.dart';
import 'package:quit_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:quit_companion/features/auth/presentation/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The keyboard must never change a password: with autocorrect/suggestions
/// on (Flutter's defaults), Android keyboards can alter a visible password
/// at sign-up, and every later login then fails with `invalid-credential`.
TextField _innerTextField(WidgetTester tester, String key) =>
    tester.widget<TextField>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      ),
    );

void _expectPasswordSafe(TextField field) {
  expect(field.autocorrect, isFalse);
  expect(field.enableSuggestions, isFalse);
  expect(field.keyboardType, TextInputType.visiblePassword);
  expect(field.obscureText, isTrue);
}

Widget _host(Widget screen) => ChangeNotifierProvider<AuthController>.value(
  value: AuthController(FakeAuthRepository()),
  child: MaterialApp(home: screen),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('login password field: no autocorrect, no suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(_host(LoginScreen(onLoggedIn: (_, _) {})));
    await tester.pumpAndSettle();

    _expectPasswordSafe(_innerTextField(tester, 'login_password_field'));
  });

  testWidgets(
    'register password field: no autocorrect, no suggestions; other fields unchanged',
    (tester) async {
      await tester.pumpWidget(
        _host(RegisterScreen(onRegistered: (_, _, _) {}, onLoginTap: () {})),
      );
      await tester.pumpAndSettle();

      _expectPasswordSafe(_innerTextField(tester, 'register_password_field'));

      // Only the password field changed behaviour.
      final name = _innerTextField(tester, 'register_name_field');
      expect(name.autocorrect, isTrue);
      expect(name.enableSuggestions, isTrue);
    },
  );
}

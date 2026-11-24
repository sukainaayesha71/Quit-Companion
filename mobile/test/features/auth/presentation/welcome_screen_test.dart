import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/auth/presentation/screens/welcome_screen.dart';

/// Welcome screen per docs/UI_Design "welcome screen 1" (2026-11-23):
/// "Quit Companion" with the design's tagline directly underneath, as one
/// centred block above the Register/Log In buttons (white Log In fill), on
/// small and large phones and with large system text.
void main() {
  const sizes = [Size(320, 640), Size(360, 800), Size(412, 915)];
  const textScales = [1.0, 1.5, 2.0];

  Future<(int, int)> pump(
    WidgetTester tester,
    Size size,
    double textScale,
  ) async {
    var registerTaps = 0;
    var loginTaps = 0;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: WelcomeScreen(
            onRegisterTap: () => registerTaps++,
            onLoginTap: () => loginTaps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (registerTaps, loginTaps);
  }

  testWidgets('shows the title and the design tagline (two lines)', (
    tester,
  ) async {
    await pump(tester, const Size(360, 800), 1.0);
    expect(find.text('Quit Companion'), findsOneWidget);
    expect(
      find.text('Your journey to a nicotine-free\nlife starts here.'),
      findsOneWidget,
    );
    expect(find.textContaining('Habit Tracking, Personalized'), findsNothing);
  });

  testWidgets('tagline is dark like the title; Log In is a white pill', (
    tester,
  ) async {
    await pump(tester, const Size(360, 800), 1.0);
    final tagline = tester.widget<Text>(
      find.byKey(const Key('welcome_tagline')),
    );
    expect(tagline.style?.color, AppColors.textPrimary);
    final login = tester.widget<OutlinedButton>(
      find.byKey(const Key('welcome_login_button')),
    );
    expect(
      login.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.surface,
    );
    expect(login.style?.elevation?.resolve(<WidgetState>{}), greaterThan(0));
    final register = tester.widget<ElevatedButton>(
      find.byKey(const Key('welcome_register_button')),
    );
    expect(register.style?.elevation?.resolve(<WidgetState>{}), greaterThan(0));
  });

  for (final size in sizes) {
    for (final scale in textScales) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} text $scale: tagline sits '
        'directly under the title, centred, above visible buttons',
        (tester) async {
          await pump(tester, size, scale);
          final title = tester.getRect(find.byKey(const Key('welcome_title')));
          final tagline = tester.getRect(
            find.byKey(const Key('welcome_tagline')),
          );
          final register = tester.getRect(
            find.byKey(const Key('welcome_register_button')),
          );
          final login = tester.getRect(
            find.byKey(const Key('welcome_login_button')),
          );

          // Order and grouping: tagline right below the title.
          expect(tagline.top, greaterThanOrEqualTo(title.bottom - 0.5));
          expect(tagline.top - title.bottom, lessThan(24));
          // Same centre line.
          expect((tagline.center.dx - title.center.dx).abs(), lessThan(1));
          expect((title.center.dx - size.width / 2).abs(), lessThan(1));
          // Never overlapping the buttons, and inside the screen.
          expect(tagline.bottom, lessThanOrEqualTo(register.top));
          expect(tagline.left, greaterThanOrEqualTo(0));
          expect(tagline.right, lessThanOrEqualTo(size.width));
          expect(login.bottom, lessThanOrEqualTo(size.height));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('Register and Log In still work', (tester) async {
    var registerTaps = 0;
    var loginTaps = 0;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onRegisterTap: () => registerTaps++,
          onLoginTap: () => loginTaps++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('welcome_register_button')));
    await tester.tap(find.byKey(const Key('welcome_login_button')));
    expect(registerTaps, 1);
    expect(loginTaps, 1);
  });
}

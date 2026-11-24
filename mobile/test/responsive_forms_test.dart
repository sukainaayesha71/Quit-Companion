import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/auth/controllers/auth_controller.dart';
import 'package:quit_companion/features/auth/controllers/phone_auth_controller.dart';
import 'package:quit_companion/features/auth/data/fake_auth_repository.dart';
import 'package:quit_companion/features/auth/data/fake_phone_auth_repository.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:quit_companion/features/auth/presentation/screens/register_screen.dart';
import 'package:quit_companion/features/auth/presentation/screens/phone_sign_in_screen.dart';
import 'package:quit_companion/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/gender_selection_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_selection_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_quantity_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/goal_selection_screen.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/consent_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/breathing_bubble_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/bubble_pop_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/craving_countdown_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/memory_match_game_screen.dart';
import 'package:quit_companion/features/games/presentation/screens/word_search_game_screen.dart';

void main() {
  for (final scale in [1.0, 1.5]) {
    for (final scenario in [
      'login',
      'register',
      'phone',
      'otp',
      'gender',
      'product',
      'quantity',
      'goal',
      'consent',
      'breathing',
      'bubbles',
      'countdown',
      'memory',
      'words',
      'keyboard_login',
      'keyboard_register',
      'keyboard_phone',
      'keyboard_otp',
      'keyboard_quantity',
    ]) {
      final keyboard = scenario.startsWith('keyboard_');
      final name = scenario.replaceFirst('keyboard_', '');
      testWidgets('portrait form/game $scenario at text $scale', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.setSurfaceSize(null);
        });
        final originalErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          originalErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalErrorHandler);
        final phone = PhoneAuthController(FakePhoneAuthRepository());
        final onboarding = OnboardingController(
          FakeUserRepository(),
          QuitDateCalculator(),
        );
        onboarding.startOnboarding(userId: 'test', email: 'test@example.com');
        final screen = switch (name) {
          'login' => LoginScreen(onLoggedIn: (_, _) {}),
          'register' => RegisterScreen(onRegistered: (_, _, _) {}),
          'phone' => PhoneSignInScreen(
            controller: phone,
            onOtpSent: (_) {},
            onBack: () {},
          ),
          'otp' => OtpVerificationScreen(
            phoneNumber: '+923001234567',
            phoneAuthController: phone,
            onVerified: (_) {},
          ),
          'gender' => GenderSelectionScreen(onBack: () {}, onContinue: (_) {}),
          'product' => ProductSelectionScreen(
            onBack: () {},
            onContinue: (_) {},
          ),
          'quantity' => ProductQuantityScreen(
            productType: ProductType.cigarettes,
            onBack: () {},
            onContinue: (_, _) {},
          ),
          'goal' => GoalSelectionScreen(onBack: () {}, onComplete: () {}),
          'consent' => ConsentScreen(onContinue: () {}),
          'breathing' => const BreathingBubbleGameScreen(),
          'bubbles' => const BubblePopGameScreen(),
          'countdown' => const CravingCountdownGameScreen(),
          'memory' => const MemoryMatchGameScreen(),
          _ => const WordSearchGameScreen(),
        };
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthController(FakeAuthRepository()),
              ),
              ChangeNotifierProvider.value(value: onboarding),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: screen,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  viewInsets: EdgeInsets.only(bottom: keyboard ? 260 : 0),
                ),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        if (name == 'goal') {
          final gradual = find.byKey(const Key('goal_option_gradual'));
          await tester.ensureVisible(gradual);
          await tester.tap(gradual);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        final scrolls = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (scrolls.evaluate().isNotEmpty) {
          for (var i = 0; i < 5; i++) {
            await tester.drag(scrolls.first, const Offset(0, -300));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        phone.dispose();
        onboarding.dispose();
      });
    }
  }
}

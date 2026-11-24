import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/consent_screen.dart';

void main() {
  testWidgets(
    'continue button is disabled until the checkbox is checked, then calls onContinue',
    (tester) async {
      final controller = OnboardingController(
        FakeUserRepository(),
        QuitDateCalculator(),
      )..startOnboarding(userId: 'u1', email: 'a@b.com');
      var continued = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingController>.value(
          value: controller,
          child: MaterialApp(
            home: ConsentScreen(onContinue: () => continued = true),
          ),
        ),
      );

      final continueButtonFinder = find.byKey(
        const Key('consent_continue_button'),
      );
      expect(
        tester.widget<ElevatedButton>(continueButtonFinder).onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('consent_checkbox')));
      await tester.pump();

      expect(
        tester.widget<ElevatedButton>(continueButtonFinder).onPressed,
        isNotNull,
      );

      await tester.tap(continueButtonFinder);
      await tester.pump();

      expect(continued, isTrue);
      expect(controller.workingUser!.hasConsented, isTrue);
    },
  );
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/onboarding_complete_screen.dart';

void main() {
  testWidgets(
    'recaps product, daily usage, and quit day; heading reads Tell us about your habit',
    (tester) async {
      final fixedToday = DateTime(2026, 8, 30);
      final controller =
          OnboardingController(
              FakeUserRepository(),
              QuitDateCalculator(now: () => fixedToday),
            )
            ..startOnboarding(userId: 'u1', email: 'a@b.com')
            ..recordConsent(true)
            ..recordProfile(
              productType: ProductType.cigarettes,
              baselineDailyUsage: 10,
            );
      await controller.submitQuitStrategy(
        quitStrategy: QuitStrategy.coldTurkey,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingController>.value(
          value: controller,
          child: MaterialApp(home: OnboardingCompleteScreen(onContinue: () {})),
        ),
      );

      expect(find.text('Tell us about your habit'), findsOneWidget);
      expect(find.textContaining('Cigarettes'), findsOneWidget);
      expect(find.textContaining('10 cigarettes'), findsOneWidget);
      expect(
        find.byKey(const Key('onboarding_complete_summary')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('onboarding_complete_continue_button')),
      );
    },
  );

  testWidgets(
    'vape with ml unitLabelOverride recaps ml, not the default puffs label',
    (tester) async {
      final fixedToday = DateTime(2026, 8, 30);
      final controller =
          OnboardingController(
              FakeUserRepository(),
              QuitDateCalculator(now: () => fixedToday),
            )
            ..startOnboarding(userId: 'u1', email: 'a@b.com')
            ..recordConsent(true)
            ..recordProfile(
              productType: ProductType.vape,
              baselineDailyUsage: 5,
            );
      await controller.submitQuitStrategy(
        quitStrategy: QuitStrategy.coldTurkey,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingController>.value(
          value: controller,
          child: MaterialApp(
            home: OnboardingCompleteScreen(
              onContinue: () {},
              unitLabelOverride: 'ml',
            ),
          ),
        ),
      );

      expect(find.textContaining('ml'), findsOneWidget);
      expect(find.textContaining('puffs'), findsNothing);
    },
  );
}

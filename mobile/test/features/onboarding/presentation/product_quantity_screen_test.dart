import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_quantity_screen.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';

void main() {
  testWidgets(
    'cigarettes: shows question, defaults to 10, increments/decrements',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          home: ProductQuantityScreen(
            productType: ProductType.cigarettes,
            onBack: () {},
            onContinue: (v, u) => result = v,
          ),
        ),
      );

      expect(
        find.text('How many cigarettes do you use in a day?'),
        findsOneWidget,
      );
      expect(find.text('10'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quantity_increment_button')));
      await tester.pump();
      expect(find.text('11'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quantity_continue_button')));
      await tester.pump();
      expect(result, 11);
    },
  );

  testWidgets('cigarettes: decrement never goes below 1', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductQuantityScreen(
          productType: ProductType.cigarettes,
          onBack: () {},
          onContinue: (_, _) {},
        ),
      ),
    );

    for (var i = 0; i < 15; i++) {
      await tester.tap(find.byKey(const Key('quantity_decrement_button')));
      await tester.pump();
    }

    expect(find.text('1'), findsOneWidget);
    final counterText = tester.widget<Text>(
      find.byKey(const Key('quantity_value_text')),
    );
    expect(counterText.data, isNot('0'));
  });

  testWidgets(
    'vape: shows the Puffs/ml toggle and switching modes changes the max',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ProductQuantityScreen(
            productType: ProductType.vape,
            onBack: () {},
            onContinue: (_, _) {},
          ),
        ),
      );

      expect(find.text('Puffs'), findsOneWidget);
      expect(find.text('ml of E-liquid'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quantity_unit_mode_1')));
      await tester.pump();

      // Switching to ml mode clamps the value into the ml range (max 10).
      final slider = tester.widget<Slider>(
        find.byKey(const Key('quantity_slider')),
      );
      expect(slider.max, 10);
    },
  );

  testWidgets('hookah: shows sessions-per-week question and unit label', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductQuantityScreen(
          productType: ProductType.hookah,
          onBack: () {},
          onContinue: (_, _) {},
        ),
      ),
    );

    expect(
      find.text('How many sessions do you have in a week?'),
      findsOneWidget,
    );
    expect(find.text('sessions per week'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets(
    'optional motivation and quit history are recorded in the onboarding profile',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = OnboardingController(
        FakeUserRepository(),
        QuitDateCalculator(),
      )..startOnboarding(userId: 'u1', email: 'a@b.com');

      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingController>.value(
          value: controller,
          child: MaterialApp(
            home: ProductQuantityScreen(
              productType: ProductType.cigarettes,
              onBack: () {},
              onContinue: (_, _) {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('onboarding_primary_motivation_field')),
        'My health',
      );
      await tester.enterText(
        find.byKey(const Key('onboarding_personal_challenges_field')),
        'Stress',
      );
      await tester.enterText(
        find.byKey(const Key('onboarding_past_quit_attempts_field')),
        'Tried last year',
      );
      await tester.tap(find.byKey(const Key('quantity_continue_button')));
      await tester.pump();

      expect(controller.workingUser!.primaryMotivation, 'My health');
      expect(controller.workingUser!.personalChallenges, 'Stress');
      expect(controller.workingUser!.pastQuitAttempts, 'Tried last year');
    },
  );
}

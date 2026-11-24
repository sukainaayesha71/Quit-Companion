import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_scaffold.dart';

void main() {
  testWidgets(
    'renders heading, content, and button; back link triggers onBack; button triggers onButtonPressed',
    (tester) async {
      var backTapped = false;
      var buttonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScaffold(
            headerAsset:
                'assets/images/onboarding/product_selection_header.png',
            headerAspectRatio: 630 / 367,
            step: 1,
            totalSteps: 4,
            onBack: () => backTapped = true,
            heading: 'What do you use?',
            content: const Text('body content'),
            buttonLabel: 'Continue',
            buttonKey: const Key('test_continue_button'),
            onButtonPressed: () => buttonTapped = true,
          ),
        ),
      );

      expect(find.text('What do you use?'), findsOneWidget);
      expect(find.text('body content'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_back_link')));
      expect(backTapped, isTrue);

      await tester.tap(find.byKey(const Key('test_continue_button')));
      expect(buttonTapped, isTrue);
    },
  );

  testWidgets('disables the button when onButtonPressed is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScaffold(
          headerAsset: 'assets/images/onboarding/product_selection_header.png',
          headerAspectRatio: 630 / 367,
          step: 1,
          totalSteps: 4,
          onBack: () {},
          heading: 'What do you use?',
          content: const SizedBox.shrink(),
          buttonLabel: 'Continue',
          buttonKey: const Key('test_continue_button'),
          onButtonPressed: null,
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('test_continue_button')),
    );
    expect(button.onPressed, isNull);
  });
}

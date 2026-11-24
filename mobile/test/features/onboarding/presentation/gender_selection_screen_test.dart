import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/gender_selection_screen.dart';

void main() {
  testWidgets('selecting a gender enables Continue and reports the choice', (
    tester,
  ) async {
    Gender? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: GenderSelectionScreen(
          onBack: () {},
          onContinue: (g) => selected = g,
        ),
      ),
    );

    expect(find.byKey(const Key('gender_continue_button')), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('gender_continue_button')),
    );
    expect(button.onPressed, isNull); // disabled until a selection is made

    await tester.tap(find.byKey(const Key('gender_option_female')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('gender_continue_button')));
    await tester.pump();

    expect(selected, Gender.female);
  });

  testWidgets('back button invokes onBack', (tester) async {
    var backTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GenderSelectionScreen(
          onBack: () => backTapped = true,
          onContinue: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('onboarding_back_link')));
    await tester.pump();

    expect(backTapped, isTrue);
  });

  testWidgets('initialSelection pre-selects a gender and enables Continue', (
    tester,
  ) async {
    Gender? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: GenderSelectionScreen(
          onBack: () {},
          onContinue: (g) => selected = g,
          initialSelection: Gender.female,
        ),
      ),
    );

    // Continue button should be enabled since a gender is pre-selected
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('gender_continue_button')),
    );
    expect(button.onPressed, isNotNull); // enabled with initialSelection

    await tester.tap(find.byKey(const Key('gender_continue_button')));
    await tester.pump();

    expect(selected, Gender.female);
  });

  testWidgets('selecting Male option enables Continue and reports the choice', (
    tester,
  ) async {
    Gender? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: GenderSelectionScreen(
          onBack: () {},
          onContinue: (g) => selected = g,
        ),
      ),
    );

    expect(find.byKey(const Key('gender_continue_button')), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('gender_continue_button')),
    );
    expect(button.onPressed, isNull); // disabled until a selection is made

    await tester.tap(find.byKey(const Key('gender_option_male')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('gender_continue_button')));
    await tester.pump();

    expect(selected, Gender.male);
  });
}

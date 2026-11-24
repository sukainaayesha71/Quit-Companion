import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_selection_screen.dart';

void main() {
  testWidgets(
    'shows all four products; continue is disabled until one is picked',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      ProductType? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: ProductSelectionScreen(
            onBack: () {},
            onContinue: (type) => selected = type,
          ),
        ),
      );

      expect(find.text('Vape'), findsOneWidget);
      expect(find.text('Cigarettes'), findsOneWidget);
      expect(find.text('Pouches'), findsOneWidget);
      expect(find.text('Hookah'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('product_selection_continue_button')),
      );
      expect(button.onPressed, isNull);

      await tester.ensureVisible(
        find.byKey(const Key('product_option_hookah')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_option_hookah')));
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('product_selection_continue_button')),
      );
      await tester.pump();

      expect(selected, ProductType.hookah);
    },
  );

  testWidgets('back link calls onBack', (tester) async {
    var backTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProductSelectionScreen(
          onBack: () => backTapped = true,
          onContinue: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('onboarding_back_link')));
    expect(backTapped, isTrue);
  });
}

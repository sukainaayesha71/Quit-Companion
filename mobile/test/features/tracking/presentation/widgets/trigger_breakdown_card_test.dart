import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/trigger_breakdown_card.dart';

void main() {
  testWidgets('renders one row per trigger with its label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TriggerBreakdownCard(
          counts: {
            TriggerCategory.stress: 5,
            TriggerCategory.boredom: 2,
            TriggerCategory.afterMeal: 0,
            TriggerCategory.socialPressure: 0,
            TriggerCategory.other: 1,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Boredom'), findsOneWidget);
    expect(find.text('Trigger Breakdown'), findsOneWidget);
  });
}

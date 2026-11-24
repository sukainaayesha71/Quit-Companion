import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/revealing_line_chart.dart';

void main() {
  testWidgets('renders and settles without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 120,
          width: 300,
          child: RevealingLineChart(values: const [1, 2, 3, 4, 3, 2, 1]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RevealingLineChart), findsOneWidget);
  });
}

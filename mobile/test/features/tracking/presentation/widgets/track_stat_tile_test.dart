import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/track_stat_tile.dart';

void main() {
  testWidgets('counts up to the target value and settles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrackStatTile(
          icon: Icons.local_fire_department,
          iconColor: Colors.red,
          value: 25,
          label: 'Longest Streak',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.text('Longest Streak'), findsOneWidget);
  });
}

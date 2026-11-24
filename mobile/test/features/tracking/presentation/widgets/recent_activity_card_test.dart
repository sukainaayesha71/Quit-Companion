import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/recent_activity_card.dart';

void main() {
  testWidgets('lists each activity item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecentActivityCard(
          items: [
            TrackActivityItem(
              date: DateTime(2026, 8, 22),
              title: 'Craving logged',
              subtitle: 'Boredom',
              isRelapse: false,
            ),
            TrackActivityItem(
              date: DateTime(2026, 8, 10),
              title: 'Relapse logged',
              subtitle: 'Social Pressure',
              isRelapse: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Craving logged'), findsOneWidget);
    expect(find.text('Relapse logged'), findsOneWidget);
  });

  testWidgets('shows an empty-state hint with no activity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RecentActivityCard(items: [])),
    );

    expect(
      find.byKey(const Key('track_recent_activity_empty')),
      findsOneWidget,
    );
  });
}

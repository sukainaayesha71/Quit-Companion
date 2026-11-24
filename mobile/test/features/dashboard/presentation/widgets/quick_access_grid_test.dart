import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/quick_access_grid.dart';

void main() {
  Widget buildGrid({
    required bool loggedCravingToday,
    VoidCallback? onAlternativesTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: QuickAccessGrid(
          onLogCravingTap: () {},
          onAlternativesTap: onAlternativesTap ?? () {},
          onMyQuitPlanTap: () {},
          onJournalTap: () {},
          onRelapseLogTap: () {},
          onHealthBotTap: () {},
          onRewardsTap: () {},
          onCommunityTap: () {},
          onKnowledgeHubTap: () {},
          isNicotineFreePhase: true,
          loggedCravingToday: loggedCravingToday,
        ),
      ),
    );
  }

  testWidgets('shows the checkmark badge when a craving was logged today', (
    tester,
  ) async {
    await tester.pumpWidget(buildGrid(loggedCravingToday: true));

    expect(
      find.byKey(const Key('dashboard_quick_access_log_craving_done_badge')),
      findsOneWidget,
    );
  });

  testWidgets('hides the checkmark badge when no craving was logged today', (
    tester,
  ) async {
    await tester.pumpWidget(buildGrid(loggedCravingToday: false));

    expect(
      find.byKey(const Key('dashboard_quick_access_log_craving_done_badge')),
      findsNothing,
    );
  });

  testWidgets('tapping the Alternatives tile calls onAlternativesTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      buildGrid(
        loggedCravingToday: false,
        onAlternativesTap: () => tapped = true,
      ),
    );

    await tester.tap(
      find.byKey(const Key('dashboard_quick_access_alternatives')),
    );
    await tester.pump();

    expect(tapped, isTrue);
  });
}

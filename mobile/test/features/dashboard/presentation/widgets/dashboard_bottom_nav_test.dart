import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_bottom_nav.dart';

void main() {
  for (final width in [320.0, 412.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('labels align at width $width and text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: DashboardBottomNav(
                onHealthBotTap: () {},
                onCommunityTap: () {},
                onTrackTap: () {},
                onProfileTap: () {},
              ),
            ),
          ),
        );
        final labels = ['Home', 'Track', 'Health-Bot', 'Community', 'Profile'];
        final top = tester.getTopLeft(find.text('Home')).dy;
        for (final label in labels) {
          expect(tester.getTopLeft(find.text(label)).dy, closeTo(top, .01));
        }
        final nav = tester.getRect(find.byType(DashboardBottomNav));
        final button = tester.getRect(
          find.byKey(const Key('dashboard_bottom_nav_health_bot')),
        );
        expect(nav.contains(button.topLeft), isTrue);
        expect(nav.contains(button.bottomRight - const Offset(.1, .1)), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  Widget buildNav({VoidCallback? onTrackTap, VoidCallback? onProfileTap}) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: DashboardBottomNav(
          onHealthBotTap: () {},
          onCommunityTap: () {},
          onTrackTap: onTrackTap ?? () {},
          onProfileTap: onProfileTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('tapping Track invokes onTrackTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildNav(onTrackTap: () => tapped = true));

    await tester.tap(find.byKey(const Key('dashboard_bottom_nav_track')));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tapping Profile invokes onProfileTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildNav(onProfileTap: () => tapped = true));

    await tester.tap(find.byKey(const Key('dashboard_bottom_nav_profile')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}

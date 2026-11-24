import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/shared/widgets/staggered_entrance.dart';

void main() {
  testWidgets(
    'fades and settles child into view as the parent animation completes',
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 500),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StaggeredEntrance(
            index: 0,
            parent: controller,
            child: const Text('hello'),
          ),
        ),
      );

      // Scoped to descend from StaggeredEntrance itself: MaterialApp's default
      // route-transition machinery (predictive-back / MaterialPageRoute) also
      // renders its own FadeTransition widgets in the tree, so an unscoped
      // find.byType(FadeTransition) would match more than one widget.
      final fadeFinder = find.descendant(
        of: find.byType(StaggeredEntrance),
        matching: find.byType(FadeTransition),
      );

      final opacityAtStart = tester
          .widget<FadeTransition>(fadeFinder)
          .opacity
          .value;
      expect(opacityAtStart, 0);

      controller.value = 1.0;
      await tester.pump();

      final opacityAtEnd = tester
          .widget<FadeTransition>(fadeFinder)
          .opacity
          .value;
      expect(opacityAtEnd, 1);
      expect(find.text('hello'), findsOneWidget);

      controller.dispose();
    },
  );
}

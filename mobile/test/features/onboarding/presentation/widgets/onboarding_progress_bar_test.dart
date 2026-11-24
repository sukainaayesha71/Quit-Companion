import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_progress_bar.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

void main() {
  testWidgets('renders totalSteps segments, filling up to currentStep', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnboardingProgressBar(currentStep: 2, totalSteps: 4),
        ),
      ),
    );

    final segments = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.key != null &&
                (w.key as Key).toString().contains(
                  'onboarding_progress_segment_',
                ),
          ),
        )
        .toList();
    expect(segments.length, 4);

    Color? colorOf(int i) => (segments[i].decoration as BoxDecoration).color;
    expect(colorOf(0), AppColors.sage);
    expect(colorOf(1), AppColors.sage);
    expect(colorOf(2), AppColors.sageLight);
    expect(colorOf(3), AppColors.sageLight);
  });
}

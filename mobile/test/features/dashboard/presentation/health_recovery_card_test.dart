import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/dashboard/domain/health_recovery_milestones.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/health_recovery_card.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';

void main() {
  testWidgets('shows planned quit date and sourced recovery milestones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HealthRecoveryCard(
              timeline: healthRecoveryMilestonesFor(ProductType.vape),
              productType: ProductType.vape,
              quitDate: DateTime(2026, 8, 20),
              daysUntilQuit: 7,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Vaping Recovery Timeline'), findsOneWidget);
    expect(find.textContaining('Your planned Quit Day is'), findsOneWidget);
    expect(find.text('First 3 days'), findsOneWidget);
    expect(
      find.textContaining('Source: National Cancer Institute'),
      findsWidgets,
    );
    expect(find.textContaining('Cigarette-specific milestones'), findsNothing);
    expect(find.textContaining('Within 20 minutes'), findsNothing);
  });

  testWidgets('shows the current quit-attempt day after Quit Day', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HealthRecoveryCard(
              timeline: healthRecoveryMilestonesFor(ProductType.cigarettes),
              productType: ProductType.cigarettes,
              quitDate: DateTime(2026, 8, 1),
              nicotineFreeDays: 14,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Cigarette Recovery Timeline'), findsOneWidget);
    expect(
      find.textContaining('You are 14 days into your current quit attempt'),
      findsOneWidget,
    );
    expect(find.text('Minutes'), findsOneWidget);
  });
}

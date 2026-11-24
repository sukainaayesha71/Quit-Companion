import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/weekly_progress_card.dart';

/// FR4 / UC6: 7-day / 30-day toggle and first-craving empty state.
void main() {
  Future<void> pumpCard(WidgetTester tester, WeeklyProgressCard card) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
  }

  final week = [0, 1, 0, 2, 0, 1, 1];
  final month = List<int>.generate(30, (i) => i % 3);

  String titleText(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('dashboard_progress_title')))
      .data!;

  testWidgets('starts on 7 days and switches to 30 days and back', (
    tester,
  ) async {
    await pumpCard(
      tester,
      WeeklyProgressCard(
        trend: week,
        pctBetterThanLastWeek: 25,
        monthlyTrend: month,
        pctBetterThanLastMonth: -10,
      ),
    );

    expect(titleText(tester), 'This Week');
    expect(find.text('25% better than last week'), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard_weekly_trend_chart')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('dashboard_progress_range_month')));
    await tester.pumpAndSettle();

    expect(titleText(tester), 'Last 30 Days');
    expect(find.text('10% more than previous 30 days'), findsOneWidget);
    expect(find.text('25% better than last week'), findsNothing);
    expect(
      find.byKey(const Key('dashboard_weekly_trend_chart')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('dashboard_progress_range_week')));
    await tester.pumpAndSettle();

    expect(titleText(tester), 'This Week');
    expect(find.text('25% better than last week'), findsOneWidget);
  });

  testWidgets(
    'the 30-day view omits the badge when there is nothing to compare',
    (tester) async {
      await pumpCard(
        tester,
        WeeklyProgressCard(
          trend: week,
          pctBetterThanLastWeek: 25,
          monthlyTrend: month,
          pctBetterThanLastMonth: null,
        ),
      );
      await tester.tap(find.byKey(const Key('dashboard_progress_range_month')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard_weekly_comparison_badge')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'without 30-day data the toggle is hidden (backwards compatible)',
    (tester) async {
      await pumpCard(
        tester,
        WeeklyProgressCard(trend: week, pctBetterThanLastWeek: null),
      );

      expect(
        find.byKey(const Key('dashboard_progress_range_month')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('dashboard_weekly_trend_chart')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a user with no craving logs sees the first-craving prompt instead of a flat chart',
    (tester) async {
      var tapped = 0;
      await pumpCard(
        tester,
        WeeklyProgressCard(
          trend: List.filled(7, 0),
          pctBetterThanLastWeek: null,
          monthlyTrend: List.filled(30, 0),
          hasAnyCravingLogs: false,
          onLogFirstCraving: () => tapped++,
        ),
      );

      expect(
        find.byKey(const Key('dashboard_first_craving_prompt')),
        findsOneWidget,
      );
      expect(find.text('Log your first craving'), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard_weekly_trend_chart')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('dashboard_progress_range_month')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('dashboard_first_craving_button')));
      expect(tapped, 1);
    },
  );

  testWidgets('fits a 320px-wide screen at 1.5x text in both ranges', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });

    await pumpCard(
      tester,
      WeeklyProgressCard(
        trend: week,
        pctBetterThanLastWeek: 100,
        monthlyTrend: month,
        pctBetterThanLastMonth: -250,
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('dashboard_progress_range_month')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await pumpCard(
      tester,
      WeeklyProgressCard(
        trend: List.filled(7, 0),
        pctBetterThanLastWeek: null,
        hasAnyCravingLogs: false,
        onLogFirstCraving: () {},
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

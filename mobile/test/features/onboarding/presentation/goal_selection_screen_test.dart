import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/goal_selection_screen.dart';

void main() {
  testWidgets(
    'selecting Quit Completely and tapping Generate My Plan calls onComplete with no date needed',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(1440, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller =
          OnboardingController(FakeUserRepository(), QuitDateCalculator())
            ..startOnboarding(userId: 'u1', email: 'a@b.com')
            ..recordConsent(true)
            ..recordProfile(
              productType: ProductType.cigarettes,
              baselineDailyUsage: 10,
            );
      var completed = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingController>.value(
          value: controller,
          child: MaterialApp(
            home: GoalSelectionScreen(
              onBack: () {},
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      expect(find.text('Quit Completely'), findsOneWidget);
      expect(find.text('Reduce Gradually'), findsOneWidget);
      expect(find.text('Quit by a Specific Date'), findsOneWidget);
      expect(find.text('Generate My Plan'), findsOneWidget);

      await tester.tap(find.byKey(const Key('goal_option_coldTurkey')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('goal_generate_plan_button')));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    },
  );

  testWidgets(
    'selecting Quit by a Specific Date reveals the inline calendar; picking a day and submitting succeeds',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      // Taller than the other tests in this file: the calendar grid (up to 6
      // rows) plus the 3 goal options and header push content well past what
      // a 1000-logical-px viewport fits, leaving the next-month arrow and day
      // cells scrolled out of the hit-testable area.
      tester.view.physicalSize = const Size(1440, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller =
          OnboardingController(FakeUserRepository(), QuitDateCalculator())
            ..startOnboarding(userId: 'u1', email: 'a@b.com')
            ..recordConsent(true)
            ..recordProfile(
              productType: ProductType.vape,
              baselineDailyUsage: 10,
            );
      var completed = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingController>.value(
          value: controller,
          child: MaterialApp(
            home: GoalSelectionScreen(
              onBack: () {},
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('goal_option_dateBased')));
      await tester.pump();

      expect(find.text('Choose your target quit date'), findsOneWidget);
      expect(find.byKey(const Key('goal_calendar_next_month')), findsOneWidget);

      // Pick a day 10 days from "today" via the next-month arrow to avoid
      // any today-vs-past-date flakiness right at month boundaries.
      await tester.tap(find.byKey(const Key('goal_calendar_next_month')));
      await tester.pump();
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1);
      await tester.tap(
        find.byKey(
          Key('goal_calendar_day_${nextMonth.year}_${nextMonth.month}_15'),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('goal_generate_plan_button')));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(controller.workingUser!.quitStrategy, isNotNull);
    },
  );

  testWidgets('Generate My Plan is disabled until a goal is picked', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        OnboardingController(FakeUserRepository(), QuitDateCalculator())
          ..startOnboarding(userId: 'u1', email: 'a@b.com')
          ..recordConsent(true)
          ..recordProfile(
            productType: ProductType.pouches,
            baselineDailyUsage: 6,
          );

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingController>.value(
        value: controller,
        child: MaterialApp(
          home: GoalSelectionScreen(onBack: () {}, onComplete: () {}),
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('goal_generate_plan_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'today (and earlier days) cannot be tapped to select a target date',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(1440, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller =
          OnboardingController(FakeUserRepository(), QuitDateCalculator())
            ..startOnboarding(userId: 'u1', email: 'a@b.com')
            ..recordConsent(true)
            ..recordProfile(
              productType: ProductType.cigarettes,
              baselineDailyUsage: 10,
            );

      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingController>.value(
          value: controller,
          child: MaterialApp(
            home: GoalSelectionScreen(onBack: () {}, onComplete: () {}),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('goal_option_dateBased')));
      await tester.pump();

      final now = DateTime.now();
      final todayCellKey = Key(
        'goal_calendar_day_${now.year}_${now.month}_${now.day}',
      );
      expect(find.byKey(todayCellKey), findsOneWidget);
      final todayInkWell = tester.widget<InkWell>(find.byKey(todayCellKey));
      expect(todayInkWell.onTap, isNull);

      // Tapping it (a no-op since onTap is null) must not select a date.
      await tester.tap(find.byKey(todayCellKey));
      await tester.pump();
      expect(find.text('Pick a target date'), findsOneWidget);
    },
  );

  testWidgets('GRADUAL cannot be submitted without a target date', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        OnboardingController(FakeUserRepository(), QuitDateCalculator())
          ..startOnboarding(userId: 'u1', email: 'a@b.com')
          ..recordConsent(true)
          ..recordProfile(
            productType: ProductType.vape,
            baselineDailyUsage: 10,
          );

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingController>.value(
        value: controller,
        child: MaterialApp(
          home: GoalSelectionScreen(onBack: () {}, onComplete: () {}),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('goal_option_gradual')));
    await tester.pump();

    expect(find.byKey(const Key('goal_target_date_hint')), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('goal_generate_plan_button')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('goal_error_text')), findsNothing);
  });

  testWidgets('selecting a target date enables a gradual quit plan', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1440, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        OnboardingController(FakeUserRepository(), QuitDateCalculator())
          ..startOnboarding(userId: 'u1', email: 'a@b.com')
          ..recordConsent(true)
          ..recordProfile(
            productType: ProductType.cigarettes,
            baselineDailyUsage: 10,
          );
    var completed = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingController>.value(
        value: controller,
        child: MaterialApp(
          home: GoalSelectionScreen(
            onBack: () {},
            onComplete: () => completed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('goal_option_gradual')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal_calendar_next_month')));
    await tester.pump();

    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    await tester.tap(
      find.byKey(
        Key('goal_calendar_day_${nextMonth.year}_${nextMonth.month}_15'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('goal_generate_plan_button')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(controller.workingUser!.quitStrategy, QuitStrategy.gradual);
    expect(controller.workingUser!.reductionSchedule, isNotNull);
  });

  testWidgets('choosing a dated goal scrolls its date picker into view', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        OnboardingController(FakeUserRepository(), QuitDateCalculator())
          ..startOnboarding(userId: 'u1', email: 'a@b.com')
          ..recordConsent(true)
          ..recordProfile(
            productType: ProductType.vape,
            baselineDailyUsage: 10,
          );

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingController>.value(
        value: controller,
        child: MaterialApp(
          home: GoalSelectionScreen(onBack: () {}, onComplete: () {}),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('goal_option_dateBased')));
    await tester.tap(find.byKey(const Key('goal_option_dateBased')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getRect(find.text('Choose your target quit date'))
          .overlaps(const Rect.fromLTWH(0, 0, 393, 852)),
      isTrue,
    );
    expect(find.byKey(const Key('goal_target_date_hint')), findsOneWidget);
  });
}

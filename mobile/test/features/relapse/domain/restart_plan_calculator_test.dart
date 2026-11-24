import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/relapse/domain/restart_plan_calculator.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  CravingLog craving() => CravingLog(
    logId: 'a',
    userId: 'u1',
    cravingIntensity: 4,
    mood: Mood.stressed,
    triggerCategory: TriggerCategory.stress,
    locationContext: 'Home',
    activity: 'Home',
    timestamp: DateTime(2026, 8, 10),
    relapseRiskScore: RelapseRiskLevel.low,
  );

  test('always includes the universal breathing-technique step', () {
    final plan = RestartPlanCalculator().generate(
      cravingHistory: const [],
      relapseTrigger: TriggerCategory.other,
    );

    expect(plan.steps, contains(contains('4-7-8 breathing')));
  });

  test(
    'the trigger-specific step matches the relapse trigger, not a generic one',
    () {
      final afterMealPlan = RestartPlanCalculator().generate(
        cravingHistory: const [],
        relapseTrigger: TriggerCategory.afterMeal,
      );
      final socialPlan = RestartPlanCalculator().generate(
        cravingHistory: const [],
        relapseTrigger: TriggerCategory.socialPressure,
      );

      expect(afterMealPlan.steps, contains(contains('after-meal')));
      expect(socialPlan.steps, contains(contains('offers you a cigarette')));
    },
  );

  test(
    'with craving history, includes an affirming step referencing past resisted cravings',
    () {
      final plan = RestartPlanCalculator().generate(
        cravingHistory: [craving(), craving()],
        relapseTrigger: TriggerCategory.stress,
      );

      expect(plan.steps, contains(contains('2 cravings')));
    },
  );

  test('with no craving history, includes a self-compassion step instead', () {
    final plan = RestartPlanCalculator().generate(
      cravingHistory: const [],
      relapseTrigger: TriggerCategory.stress,
    );

    expect(plan.steps, contains(contains('Be kind to yourself')));
  });

  test(
    'never suggests unbuilt-module functionality (Alternatives/Community/push notifications)',
    () {
      final plan = RestartPlanCalculator().generate(
        cravingHistory: const [],
        relapseTrigger: TriggerCategory.boredom,
      );

      final allText = plan.steps.join(' ');
      expect(allText, isNot(contains('community')));
      expect(allText, isNot(contains('Community')));
      expect(allText, isNot(contains('notification')));
    },
  );
}

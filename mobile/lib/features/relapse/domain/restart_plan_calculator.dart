import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/relapse/models/restart_plan.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

/// Pure implementation of SDD §7.4's `AI_Generate_Restart_Plan(CravingHistory,
/// RelapseTrigger)`, called from `Log_Relapse` — which is Module 5's
/// function, not built yet. This calculator is Module 4's piece of that
/// call: built and tested now, ready for Module 5 to invoke later.
///
/// Per the approved Module 4 plan (Open Decision 4): fixed templates only,
/// no live generation, and — unlike the approved reference screenshot's
/// third suggestion ("Check in with the community for extra support") —
/// nothing here points at a module that isn't built (Community, FR11).
class RestartPlanCalculator {
  RestartPlan generate({
    required List<CravingLog> cravingHistory,
    required TriggerCategory relapseTrigger,
  }) {
    final steps = <String>[
      'Try the 4-7-8 breathing technique when cravings hit.',
      _triggerTip(relapseTrigger),
    ];
    if (cravingHistory.isNotEmpty) {
      final count = cravingHistory.length;
      steps.add(
        "You've resisted $count craving${count == 1 ? '' : 's'} before this — that skill is still yours.",
      );
    } else {
      steps.add(
        "Be kind to yourself — one setback doesn't undo your progress.",
      );
    }
    return RestartPlan(steps: steps);
  }

  String _triggerTip(TriggerCategory trigger) {
    switch (trigger) {
      case TriggerCategory.stress:
        return "Notice what's stressing you today, and try stepping away for a few minutes when it hits.";
      case TriggerCategory.afterMeal:
        return 'Avoid your usual after-meal smoke spot for the next few days.';
      case TriggerCategory.socialPressure:
        return "Plan what you'll say if someone offers you a cigarette again.";
      case TriggerCategory.boredom:
        return 'Keep your hands busy — try a short walk or a simple task when boredom strikes.';
      case TriggerCategory.other:
        return 'Notice what led to this moment, and plan one small change for next time.';
    }
  }
}

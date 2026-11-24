import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';
import 'package:quit_companion/features/goals/models/weekly_plan.dart';

/// Pure implementation of SDD §7.7's `Generate_Weekly_Plan_Update` (FR17,
/// Module 4). No I/O — mirrors DashboardStateCalculator/QuitDateCalculator's
/// testable style (injectable `now`).
///
/// The SDD leaves `AI_Adapt_Plan` completely unspecified — no algorithm, no
/// backend, nothing beyond "adapt the plan from Progress." Per the approved
/// Module 4 plan (Open Decision 4: fixed templates, no live generation),
/// this selects deterministically from a small fixed template library based
/// on the last 7 days of usage/craving activity — the same "fixed,
/// pre-vetted content" posture FR7/FR8 already use elsewhere in this app.
class WeeklyPlanCalculator {
  static const starterGoals = <String>[
    'Choose a reason to quit and keep it somewhere you can see each day.',
    'Choose your quit date and approach in your profile when you are ready.',
    'Keep water nearby and choose a short activity to try when an urge arrives.',
    'Record your cravings, triggers and nicotine use each day to learn your patterns.',
    'Choose someone you can contact for encouragement and review what helped at the end of the week.',
  ];

  WeeklyPlan starterPlan() =>
      WeeklyPlan(goals: starterGoals, generatedAt: now());

  final DateTime Function() now;

  WeeklyPlanCalculator({DateTime Function()? now}) : now = now ?? DateTime.now;

  WeeklyPlan generate({
    required NicotineUser user,
    required List<UsageLog> usageLogs,
    required List<CravingLog> cravingLogs,
  }) {
    final quitDate = user.quitDate;
    if (quitDate == null) {
      throw StateError(
        'Cannot generate a weekly plan before quitDate is set (SDD FR3).',
      );
    }
    final today = _dateOnly(now());
    final quitDay = _dateOnly(quitDate);
    final windowStart = today.subtract(const Duration(days: 7));
    final isNicotineFree = !today.isBefore(quitDay);

    final recentUsage = usageLogs.where(
      (log) => !_dateOnly(log.date).isBefore(windowStart),
    );
    final recentCravings = cravingLogs.where(
      (log) => !log.timestamp.isBefore(windowStart),
    );

    final goals = <String>[];

    if (!isNicotineFree && user.quitStrategy == QuitStrategy.gradual) {
      final overTargetDays = recentUsage
          .where((log) => log.actualUsage > log.targetUsage)
          .length;
      if (overTargetDays >= 2) {
        goals.add(
          'This week: get back under your daily target — even one log under target rebuilds momentum.',
        );
      } else if (recentUsage.isNotEmpty) {
        goals.add(
          'Great consistency this week — keep logging your usage daily to stay on track for your Quit Day.',
        );
      }
    }

    final recentCravingList = recentCravings.toList();
    final highRiskCravings = recentCravingList
        .where((log) => log.relapseRiskScore == RelapseRiskLevel.high)
        .length;
    if (highRiskCravings >= 2) {
      goals.add(
        'A few intense cravings this week — try the 4-7-8 breathing technique next time one hits.',
      );
    } else if (recentCravings.isNotEmpty) {
      goals.add(
        "You're logging your cravings consistently — that awareness is a real skill.",
      );
    }

    final mostCommonTrigger = _mostCommonTrigger(recentCravingList);
    if (mostCommonTrigger != null) {
      goals.add(_triggerAction(mostCommonTrigger));
    }

    if (isNicotineFree) {
      final lastRelapseDate = user.lastRelapseDate;
      final relapsedThisWeek =
          lastRelapseDate != null &&
          !_dateOnly(lastRelapseDate).isBefore(windowStart);
      goals.add(
        relapsedThisWeek
            ? 'Getting back on track after a setback — focus on one day at a time this week.'
            : 'Keep your nicotine-free streak going — notice what helped you resist cravings this week.',
      );
    }

    if (!isNicotineFree &&
        user.quitStrategy != QuitStrategy.gradual &&
        goals.isNotEmpty) {
      goals.add(
        'Before your Quit Day, choose one person you can contact and decide what you will do when a craving starts.',
      );
    }

    if (goals.isEmpty) {
      goals.add(
        'Log your usage and cravings this week so we can tailor next week\'s plan to you.',
      );
    }

    return WeeklyPlan(goals: goals, generatedAt: now());
  }

  TriggerCategory? _mostCommonTrigger(List<CravingLog> cravingLogs) {
    if (cravingLogs.isEmpty) return null;

    final counts = <TriggerCategory, int>{};
    for (final log in cravingLogs) {
      counts.update(
        log.triggerCategory,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _triggerAction(TriggerCategory trigger) => switch (trigger) {
    TriggerCategory.stress =>
      'Stress was a common trigger this week. When it shows up, pause for a few slow breaths and note whether that helped.',
    TriggerCategory.afterMeal =>
      'After-meal urges showed up this week. Plan a short walk or change rooms after your next meal, then log how it goes.',
    TriggerCategory.socialPressure =>
      'Social pressure came up this week. Practice a short response to an offer and decide what non-nicotine option to keep nearby.',
    TriggerCategory.boredom =>
      'Boredom was a common trigger this week. Pick a five-minute activity to start when an urge appears, then log how it goes.',
    TriggerCategory.other =>
      'When an urge appears, note what was happening just before it and record one alternative response to try next time.',
  };

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

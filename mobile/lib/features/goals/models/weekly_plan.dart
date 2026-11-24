/// FR17 (Module 4, §7.7): result of `Generate_Weekly_Plan_Update`. Persisted
/// as `NicotineUser.weeklyGoals`/`weeklyGoalsUpdatedAt` (Module 4 plan Open
/// Decision 2) — no separate Firestore entity/collection.
class WeeklyPlan {
  final List<String> goals;
  final DateTime generatedAt;

  const WeeklyPlan({required this.goals, required this.generatedAt});
}

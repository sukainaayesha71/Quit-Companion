/// FR17 (Module 4, §7.4): result of `AI_Generate_Restart_Plan`, called from
/// `Log_Relapse` (Module 5, not built yet). Computed on-demand, never
/// persisted (Module 4 plan Open Decision 2) — §7.4 only says to display it.
class RestartPlan {
  final List<String> steps;

  const RestartPlan({required this.steps});
}

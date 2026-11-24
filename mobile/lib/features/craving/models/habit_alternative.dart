/// SDD §6 / SRDS class diagram: HabitAlternative(alternativeId, category,
/// description, successRate). [successRate] is deliberately NOT a static
/// authored number (the approved UI, docs/UI_Design/6a.png, shows a "80%
/// success rate for you" figure that HighRiskScreen's original build
/// explicitly declined to fabricate — see its class doc). Instead it is
/// left null in the fixed content library and only ever populated by
/// deriving it from real logged HabitAlternativeAttempt outcomes
/// (Module 7 plan) — never invented.
enum AlternativeCategory { exercise, quickFix, game }

class HabitAlternative {
  final String alternativeId;
  final String title;
  final String description;
  final AlternativeCategory category;

  /// Brief instruction shown on the "Try This" detail screen (SRDS UC4
  /// step 7: "brief instruction for each, e.g. '4-7-8 Breathing
  /// Exercise'"). Fixed, pre-vetted text — never AI-generated (FR7).
  final String instructions;

  const HabitAlternative({
    required this.alternativeId,
    required this.title,
    required this.description,
    required this.category,
    required this.instructions,
  });
}

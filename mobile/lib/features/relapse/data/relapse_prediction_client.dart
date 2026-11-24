import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

/// Which method actually produced a risk level, as reported by the backend
/// (`assessment_source`). Never inferred from configuration: a backend set
/// to ML can still answer with the rule-based fallback.
enum PredictionSource {
  /// The experimental EMASENS-trained ML model (`machine_learning`).
  machineLearning,

  /// The SRDS rule table (backend `rule_based` / `RuleBasedPredictor`).
  ruleBased,

  /// ML was configured but failed for this request; the rule table answered.
  ruleBasedFallback,

  /// Older backend or missing field: source not reported.
  unknown,
}

PredictionSource parsePredictionSource(Object? raw) => switch (raw) {
  'machine_learning' || 'ModelPredictor' => PredictionSource.machineLearning,
  'rule_based' || 'RuleBasedPredictor' => PredictionSource.ruleBased,
  'rule_based_fallback' => PredictionSource.ruleBasedFallback,
  _ => PredictionSource.unknown,
};

extension PredictionSourceDisplay on PredictionSource {
  /// User-facing label; null when the source wasn't reported.
  String? get label => switch (this) {
    PredictionSource.machineLearning => 'ML (Experimental)',
    PredictionSource.ruleBased => 'Rule-based',
    PredictionSource.ruleBasedFallback => 'Rule-based (ML unavailable)',
    PredictionSource.unknown => null,
  };
}

/// A risk level plus how it was produced.
class RelapsePrediction {
  final RelapseRiskLevel riskLevel;
  final PredictionSource source;
  final String? modelVersion;

  /// Model inputs the backend filled from training-set medians because the
  /// user didn't answer them (ML only).
  final List<String> imputedFeatures;

  const RelapsePrediction({
    required this.riskLevel,
    this.source = PredictionSource.unknown,
    this.modelVersion,
    this.imputedFeatures = const [],
  });
}

class RelapsePredictionException implements Exception {
  final String message;
  RelapsePredictionException(this.message);

  @override
  String toString() => message;
}

/// Talks to the FastAPI backend's POST /predict/relapse (FR5, SDD §2's
/// architecture diagram) — the rule-based predictor is what actually
/// answers every request in production (backend RELAPSE_PREDICTOR_MODE
/// defaults to rule_based). The ten optional mood-slider readings
/// (Open Decision 6) are only consumed by the backend's research-preview
/// ModelPredictor path, which normal app users never reach — they're sent
/// whenever available so that path stays usable for evaluation, without
/// changing anything about the response normal users see.
abstract class RelapsePredictionClient {
  Future<RelapseRiskLevel> predict({
    required int intensity,
    required Mood mood,
    required TriggerCategory triggerCategory,
    required int last24hCount,
    double? moodHappy,
    double? moodExcited,
    double? moodEnthusiastic,
    double? moodContented,
    double? moodCalm,
    double? moodIrritable,
    double? moodAnxious,
    double? moodStressed,
    double? moodSad,
    double? moodBored,
    Map<String, double>? recoveryContext,
  });

  /// Same request as [predict], also returning the prediction source the
  /// backend reported. Null mood values and an empty/null recovery context
  /// are sent as *missing*, never as default answers.
  Future<RelapsePrediction> predictDetailed({
    required int intensity,
    required Mood mood,
    required TriggerCategory triggerCategory,
    required int last24hCount,
    double? moodHappy,
    double? moodExcited,
    double? moodEnthusiastic,
    double? moodContented,
    double? moodCalm,
    double? moodIrritable,
    double? moodAnxious,
    double? moodStressed,
    double? moodSad,
    double? moodBored,
    Map<String, double>? recoveryContext,
  });
}

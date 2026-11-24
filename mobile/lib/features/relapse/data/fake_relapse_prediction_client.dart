import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

/// In-memory RelapsePredictionClient for tests — never makes a network
/// call. Defaults to a fixed risk level; construct with [fail] to simulate
/// a backend failure.
class FakeRelapsePredictionClient implements RelapsePredictionClient {
  final RelapseRiskLevel fixedRiskLevel;
  final bool fail;

  /// Source reported by [predictDetailed] (what a backend would return).
  final PredictionSource fixedSource;

  FakeRelapsePredictionClient({
    this.fixedRiskLevel = RelapseRiskLevel.low,
    this.fail = false,
    this.fixedSource = PredictionSource.ruleBased,
  });

  Map<String, double>? lastRecoveryContext;

  int predictCount = 0;
  int? lastLast24hCount;
  double? lastMoodHappy;
  double? lastMoodExcited;
  double? lastMoodEnthusiastic;
  double? lastMoodContented;
  double? lastMoodCalm;
  double? lastMoodIrritable;
  double? lastMoodAnxious;
  double? lastMoodStressed;
  double? lastMoodSad;
  double? lastMoodBored;

  @override
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
  }) async {
    predictCount++;
    lastLast24hCount = last24hCount;
    lastMoodHappy = moodHappy;
    lastMoodExcited = moodExcited;
    lastMoodEnthusiastic = moodEnthusiastic;
    lastMoodContented = moodContented;
    lastMoodCalm = moodCalm;
    lastMoodIrritable = moodIrritable;
    lastMoodAnxious = moodAnxious;
    lastMoodStressed = moodStressed;
    lastMoodSad = moodSad;
    lastMoodBored = moodBored;
    lastRecoveryContext = recoveryContext;
    if (fail) {
      throw RelapsePredictionException(
        'Could not assess this craving. Please try again.',
      );
    }
    return fixedRiskLevel;
  }

  @override
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
  }) async {
    final level = await predict(
      intensity: intensity,
      mood: mood,
      triggerCategory: triggerCategory,
      last24hCount: last24hCount,
      moodHappy: moodHappy,
      moodExcited: moodExcited,
      moodEnthusiastic: moodEnthusiastic,
      moodContented: moodContented,
      moodCalm: moodCalm,
      moodIrritable: moodIrritable,
      moodAnxious: moodAnxious,
      moodStressed: moodStressed,
      moodSad: moodSad,
      moodBored: moodBored,
      recoveryContext: recoveryContext,
    );
    return RelapsePrediction(riskLevel: level, source: fixedSource);
  }
}

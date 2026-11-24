import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/relapse/data/http_relapse_prediction_client.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

/// ML integration fixes (2026-11-23): payload honesty and prediction source.
void main() {
  group('parsePredictionSource', () {
    test('maps every backend value; unknown or missing is safe', () {
      expect(
        parsePredictionSource('machine_learning'),
        PredictionSource.machineLearning,
      );
      expect(
        parsePredictionSource('ModelPredictor'),
        PredictionSource.machineLearning,
      );
      expect(
        parsePredictionSource('RuleBasedPredictor'),
        PredictionSource.ruleBased,
      );
      expect(parsePredictionSource('rule_based'), PredictionSource.ruleBased);
      expect(
        parsePredictionSource('rule_based_fallback'),
        PredictionSource.ruleBasedFallback,
      );
      expect(parsePredictionSource(null), PredictionSource.unknown);
      expect(parsePredictionSource(42), PredictionSource.unknown);
      expect(PredictionSource.unknown.label, isNull);
      expect(PredictionSource.machineLearning.label, 'ML (Experimental)');
    });
  });

  group('HttpRelapsePredictionClient', () {
    late Map<String, dynamic> sent;
    HttpRelapsePredictionClient client(Map<String, dynamic> response) =>
        HttpRelapsePredictionClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode(response), 200);
          }),
          getIdToken: () async => 'token',
        );

    test(
      'unanswered sliders and an empty check-in are omitted, not sent as defaults',
      () async {
        final c = client({
          'risk_level': 'medium',
          'assessment_source': 'machine_learning',
        });
        await c.predictDetailed(
          intensity: 6,
          mood: Mood.stressed,
          triggerCategory: TriggerCategory.stress,
          last24hCount: 1,
          moodAnxious: 8,
          recoveryContext: const {},
        );
        expect(sent['mood_anxious'], 8);
        expect(sent.keys.where((k) => k.startsWith('mood_')), ['mood_anxious']);
        expect(sent.containsKey('recovery_context'), isFalse);
      },
    );

    test('an answered check-in is sent as given', () async {
      final c = client({
        'risk_level': 'low',
        'assessment_source': 'machine_learning',
      });
      await c.predictDetailed(
        intensity: 3,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        last24hCount: 1,
        recoveryContext: const {'motivation_imp': 9},
      );
      expect(sent['recovery_context'], {'motivation_imp': 9});
    });

    test(
      'parses source, model version and imputed features from the backend',
      () async {
        final c = client({
          'risk_level': 'high',
          'assessment_source': 'machine_learning',
          'model_version': 'emasens-xgboost-v1',
          'imputed_features': ['pain_imp', 'cigarette_availability_imp'],
        });
        final result = await c.predictDetailed(
          intensity: 9,
          mood: Mood.stressed,
          triggerCategory: TriggerCategory.stress,
          last24hCount: 3,
        );
        expect(result.riskLevel, RelapseRiskLevel.high);
        expect(result.source, PredictionSource.machineLearning);
        expect(result.modelVersion, 'emasens-xgboost-v1');
        expect(result.imputedFeatures, [
          'pain_imp',
          'cigarette_availability_imp',
        ]);
      },
    );

    test('a rule-based fallback is reported as such', () async {
      final c = client({
        'risk_level': 'medium',
        'assessment_source': 'rule_based_fallback',
      });
      final result = await c.predictDetailed(
        intensity: 5,
        mood: Mood.bored,
        triggerCategory: TriggerCategory.boredom,
        last24hCount: 1,
      );
      expect(result.source, PredictionSource.ruleBasedFallback);
    });

    test('an older backend without source fields is handled safely', () async {
      final c = client({'risk_level': 'low'});
      final result = await c.predictDetailed(
        intensity: 2,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        last24hCount: 0,
      );
      expect(result.source, PredictionSource.unknown);
      expect(result.imputedFeatures, isEmpty);
      final level = await c.predict(
        intensity: 2,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        last24hCount: 0,
      );
      expect(level, RelapseRiskLevel.low);
    });
  });
}

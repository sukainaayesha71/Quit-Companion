import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/craving/data/craving_log_codec.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/craving/presentation/screens/high_risk_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/log_craving_screen.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

Future<void> _pumpAlternatives(
  WidgetTester tester, {
  RelapseRiskLevel? riskLevel,
  PredictionSource? source,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HighRiskScreen(
        userId: 'u1',
        triggerCategory: TriggerCategory.stress,
        mood: Mood.stressed,
        controller: AlternativesController(
          FakeHabitAlternativeAttemptRepository(),
        ),
        riskLevel: riskLevel,
        predictionSource: source,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<CravingLog>> _saved(FakeCravingLogRepository repo) =>
    repo.getRecentLogs('u1', DateTime(2000));

Future<CravingLog> _submitWith(
  RelapseRiskLevel level,
  PredictionSource source, {
  bool fail = false,
}) async {
  final repo = FakeCravingLogRepository();
  final controller = CravingLogController(
    repo,
    FakeRelapsePredictionClient(
      fixedRiskLevel: level,
      fixedSource: source,
      fail: fail,
    ),
  );
  await controller.submitCraving(
    userId: 'u1',
    intensity: 9,
    mood: Mood.stressed,
    triggerCategory: TriggerCategory.stress,
    locationContext: 'Home',
    activity: 'Eating',
  );
  return (await _saved(repo)).single;
}

void main() {
  group('Alternatives screen shows the assessment it came from', () {
    testWidgets('High Risk scored by ML', (tester) async {
      await _pumpAlternatives(
        tester,
        riskLevel: RelapseRiskLevel.high,
        source: PredictionSource.machineLearning,
      );
      expect(
        find.byKey(const Key('high_risk_assessment_result')),
        findsOneWidget,
      );
      expect(find.text('High Risk'), findsOneWidget);
      expect(find.text('Scored by: ML (Experimental)'), findsOneWidget);
    });

    testWidgets('a rule-based fallback is shown as such, never as ML', (
      tester,
    ) async {
      await _pumpAlternatives(
        tester,
        riskLevel: RelapseRiskLevel.high,
        source: PredictionSource.ruleBasedFallback,
      );
      expect(find.text('High Risk'), findsOneWidget);
      expect(
        find.text('Scored by: Rule-based (ML unavailable)'),
        findsOneWidget,
      );
      expect(find.textContaining('ML (Experimental)'), findsNothing);
    });

    testWidgets('a rule-based assessment shows Rule-based', (tester) async {
      await _pumpAlternatives(
        tester,
        riskLevel: RelapseRiskLevel.high,
        source: PredictionSource.ruleBased,
      );
      expect(find.text('Scored by: Rule-based'), findsOneWidget);
      expect(find.textContaining('ML (Experimental)'), findsNothing);
    });

    testWidgets('an unknown source shows the risk level but no source', (
      tester,
    ) async {
      await _pumpAlternatives(
        tester,
        riskLevel: RelapseRiskLevel.high,
        source: PredictionSource.unknown,
      );
      expect(find.text('High Risk'), findsOneWidget);
      expect(find.byKey(const Key('craving_prediction_source')), findsNothing);
    });

    testWidgets('browsing without an assessment shows no risk result', (
      tester,
    ) async {
      await _pumpAlternatives(tester);
      expect(
        find.byKey(const Key('high_risk_assessment_result')),
        findsNothing,
      );
      expect(find.text('High Risk'), findsNothing);
      expect(find.byKey(const Key('craving_prediction_source')), findsNothing);
    });
  });

  group('the saved craving records how it was scored', () {
    test('ML', () async {
      final log = await _submitWith(
        RelapseRiskLevel.high,
        PredictionSource.machineLearning,
      );
      expect(log.relapseRiskScore, RelapseRiskLevel.high);
      expect(log.assessmentSource, 'machine_learning');
    });

    test('rule-based', () async {
      final log = await _submitWith(
        RelapseRiskLevel.medium,
        PredictionSource.ruleBased,
      );
      expect(log.assessmentSource, 'rule_based');
    });

    test('rule-based fallback', () async {
      final log = await _submitWith(
        RelapseRiskLevel.high,
        PredictionSource.ruleBasedFallback,
      );
      expect(log.assessmentSource, 'rule_based_fallback');
    });

    test('nothing when the assessment is still pending', () async {
      final log = await _submitWith(
        RelapseRiskLevel.high,
        PredictionSource.machineLearning,
        fail: true,
      );
      expect(log.riskAssessmentPending, isTrue);
      expect(log.assessmentSource, isNull);
    });

    test('the offline copy keeps the source; older records have none', () {
      final log = CravingLog(
        logId: 'l1',
        userId: 'u1',
        cravingIntensity: 8,
        mood: Mood.sad,
        triggerCategory: TriggerCategory.boredom,
        locationContext: 'Home',
        activity: 'Relaxing/watching TV',
        timestamp: DateTime(2026, 11, 26, 9),
        relapseRiskScore: RelapseRiskLevel.high,
        assessmentSource: 'machine_learning',
      );
      final encoded = encodeCraving(log);
      expect(decodeCraving(encoded).assessmentSource, 'machine_learning');
      final older = Map<String, dynamic>.of(encoded)..remove('assessmentSource');
      expect(decodeCraving(older).assessmentSource, isNull);
    });

    test('the stored values parse back to the same source', () {
      for (final source in [
        PredictionSource.machineLearning,
        PredictionSource.ruleBased,
        PredictionSource.ruleBasedFallback,
      ]) {
        expect(parsePredictionSource(source.wireName), source);
      }
      expect(PredictionSource.unknown.wireName, isNull);
    });
  });

  testWidgets(
    'the Log Craving redirect passes the live High Risk result and its source',
    (tester) async {
      final repo = FakeCravingLogRepository();
      final controller = CravingLogController(
        repo,
        FakeRelapsePredictionClient(
          fixedRiskLevel: RelapseRiskLevel.high,
          fixedSource: PredictionSource.ruleBasedFallback,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LogCravingScreen(
            userId: 'u1',
            controller: controller,
            alternativesController: AlternativesController(
              FakeHabitAlternativeAttemptRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('craving_mood_stressed')));
      await tester.ensureVisible(
        find.byKey(const Key('craving_trigger_stress')),
      );
      await tester.tap(find.byKey(const Key('craving_trigger_stress')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('craving_location_dropdown')),
      );
      await tester.tap(find.byKey(const Key('craving_location_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('craving_activity_dropdown')),
      );
      await tester.tap(find.byKey(const Key('craving_activity_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Working/studying').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(HighRiskScreen), findsOneWidget);
      expect(find.text('High Risk'), findsOneWidget);
      expect(
        find.text('Scored by: Rule-based (ML unavailable)'),
        findsOneWidget,
      );
      expect(find.textContaining('ML (Experimental)'), findsNothing);
      expect(
        (await _saved(repo)).single.assessmentSource,
        'rule_based_fallback',
      );
    },
  );
}

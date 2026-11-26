import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
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

/// Returns the next risk level from [levels] for each assessment, and can
/// hold an assessment open with [hold] to simulate a slow backend.
class _ScriptedPredictionClient extends FakeRelapsePredictionClient {
  final List<RelapseRiskLevel> levels;
  Completer<void>? hold;
  int _next = 0;

  _ScriptedPredictionClient(this.levels)
    : super(fixedSource: PredictionSource.machineLearning);

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
    final level = levels[_next++ % levels.length];
    final pending = hold;
    if (pending != null) await pending.future;
    return RelapsePrediction(riskLevel: level, source: fixedSource);
  }
}

/// Fails the first save only, to produce an error state.
class _FailingOnceRepository extends FakeCravingLogRepository {
  bool failNext = true;

  @override
  Future<void> logCraving(CravingLog log) async {
    if (failNext) {
      failNext = false;
      throw Exception('network down');
    }
    return super.logCraving(log);
  }
}

/// Opens Log Craving with one shared controller, like the dashboard does.
class _Host extends StatelessWidget {
  final CravingLogController controller;
  final AlternativesController alternatives;

  const _Host({required this.controller, required this.alternatives});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('open_log_craving'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LogCravingScreen(
                userId: 'u1',
                controller: controller,
                alternativesController: alternatives,
              ),
            ),
          ),
          child: const Text('Log Craving'),
        ),
      ),
    );
  }
}

void main() {
  late FakeCravingLogRepository repository;
  late _ScriptedPredictionClient prediction;
  late CravingLogController controller;
  var clock = DateTime(2026, 11, 26, 10);

  CravingLogController buildController(FakeCravingLogRepository repo) =>
      CravingLogController(
        repo,
        prediction,
        // Distinct timestamps, so every entry gets its own log id.
        now: () => clock = clock.add(const Duration(minutes: 1)),
      );

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          controller: controller,
          alternatives: AlternativesController(
            FakeHabitAlternativeAttemptRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLogCraving(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open_log_craving')));
    await tester.pumpAndSettle();
  }

  void expectFreshForm() {
    expect(find.byType(LogCravingScreen), findsOneWidget);
    expect(find.byKey(const Key('craving_risk_result')), findsNothing);
    expect(find.byKey(const Key('craving_submit_button')), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.byKey(const Key('craving_error_text')), findsNothing);
    expect(find.byKey(const Key('craving_validation_error')), findsNothing);
  }

  Future<void> closeWithX(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('craving_close_button')));
    await tester.tap(find.byKey(const Key('craving_close_button')));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String notes = '',
    bool settle = true,
  }) async {
    await tester.tap(find.byKey(const Key('craving_mood_stressed')));
    await tester.ensureVisible(find.byKey(const Key('craving_trigger_stress')));
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
    if (notes.isNotEmpty) {
      await tester.ensureVisible(find.byKey(const Key('craving_notes_field')));
      await tester.enterText(
        find.byKey(const Key('craving_notes_field')),
        notes,
      );
    }
    await tester.ensureVisible(find.byKey(const Key('craving_submit_button')));
    await tester.tap(find.byKey(const Key('craving_submit_button')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<List<CravingLog>> savedLogs() =>
      repository.getRecentLogs('u1', DateTime(2000));

  setUp(() {
    clock = DateTime(2026, 11, 26, 10);
    repository = FakeCravingLogRepository();
  });

  testWidgets(
    'every opening shows a fresh form and each entry is its own assessment',
    (tester) async {
      prediction = _ScriptedPredictionClient([
        RelapseRiskLevel.medium,
        RelapseRiskLevel.low,
        RelapseRiskLevel.medium,
        RelapseRiskLevel.low,
      ]);
      controller = buildController(repository);
      await pumpHost(tester);

      // 1st craving: Medium, closed with Done.
      await openLogCraving(tester);
      expectFreshForm();
      await fillAndSubmit(tester, notes: 'first');
      expect(find.text('Medium Risk'), findsOneWidget);
      await tester.tap(find.byKey(const Key('craving_result_done_button')));
      await tester.pumpAndSettle();
      expect(find.byType(LogCravingScreen), findsNothing);

      // 2nd craving: fresh form, new result (Low), closed with the X.
      await openLogCraving(tester);
      expectFreshForm();
      expect(find.text('Medium Risk'), findsNothing);
      await fillAndSubmit(tester, notes: 'second');
      expect(find.text('Low Risk'), findsOneWidget);
      await closeWithX(tester);

      // 3rd craving: fresh form again, closed with the system back button.
      await openLogCraving(tester);
      expectFreshForm();
      expect(find.text('Low Risk'), findsNothing);
      await fillAndSubmit(tester, notes: 'third');
      expect(find.text('Medium Risk'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LogCravingScreen), findsNothing);

      // 4th opening: still a fresh form; leaving without submitting saves nothing.
      await openLogCraving(tester);
      expectFreshForm();
      await closeWithX(tester);

      // All three cravings are saved as separate records with their own results.
      final logs = await savedLogs();
      expect(logs.map((l) => l.notes), ['first', 'second', 'third']);
      expect(logs.map((l) => l.relapseRiskScore), [
        RelapseRiskLevel.medium,
        RelapseRiskLevel.low,
        RelapseRiskLevel.medium,
      ]);
      expect(logs.map((l) => l.logId).toSet(), hasLength(3));
      expect(prediction.predictCount, 0); // predictDetailed is scripted
    },
  );

  testWidgets('a reopened form starts empty, not with the previous answers', (
    tester,
  ) async {
    prediction = _ScriptedPredictionClient([RelapseRiskLevel.medium]);
    controller = buildController(repository);
    await pumpHost(tester);

    await openLogCraving(tester);
    await fillAndSubmit(tester, notes: 'previous notes');
    await tester.tap(find.byKey(const Key('craving_result_done_button')));
    await tester.pumpAndSettle();

    await openLogCraving(tester);
    expectFreshForm();
    // Submitting straight away must ask for the details again.
    await tester.ensureVisible(find.byKey(const Key('craving_submit_button')));
    await tester.tap(find.byKey(const Key('craving_submit_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('craving_validation_error')), findsOneWidget);
    expect(find.text('previous notes'), findsNothing);
    expect(await savedLogs(), hasLength(1));
  });

  testWidgets('a previous error is not shown when Log Craving is reopened', (
    tester,
  ) async {
    prediction = _ScriptedPredictionClient([RelapseRiskLevel.medium]);
    repository = _FailingOnceRepository();
    controller = buildController(repository);
    await pumpHost(tester);

    await openLogCraving(tester);
    await fillAndSubmit(tester);
    expect(find.byKey(const Key('craving_error_text')), findsOneWidget);
    await closeWithX(tester);

    await openLogCraving(tester);
    expectFreshForm();
    await fillAndSubmit(tester);
    expect(find.text('Medium Risk'), findsOneWidget);
    expect(await savedLogs(), hasLength(1));
  });

  testWidgets(
    'closing during a slow assessment still saves it, without overwriting the new form',
    (tester) async {
      prediction = _ScriptedPredictionClient([
        RelapseRiskLevel.medium,
        RelapseRiskLevel.low,
      ]);
      controller = buildController(repository);
      await pumpHost(tester);

      final slow = Completer<void>();
      prediction.hold = slow;
      await openLogCraving(tester);
      await fillAndSubmit(tester, notes: 'slow one', settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await closeWithX(tester);

      await openLogCraving(tester);
      expectFreshForm();

      // The earlier assessment finishes while the new form is open.
      prediction.hold = null;
      slow.complete();
      await tester.pumpAndSettle();
      expectFreshForm();
      final logs = await savedLogs();
      expect(logs.single.notes, 'slow one');
      expect(logs.single.relapseRiskScore, RelapseRiskLevel.medium);

      // The new entry gets its own result.
      await fillAndSubmit(tester, notes: 'new one');
      expect(find.text('Low Risk'), findsOneWidget);
      expect((await savedLogs()).map((l) => l.notes), ['slow one', 'new one']);
    },
  );

  testWidgets('after a High risk redirect, reopening shows a fresh form', (
    tester,
  ) async {
    prediction = _ScriptedPredictionClient([
      RelapseRiskLevel.high,
      RelapseRiskLevel.medium,
    ]);
    controller = buildController(repository);
    await pumpHost(tester);

    await openLogCraving(tester);
    await fillAndSubmit(tester);
    expect(find.byType(HighRiskScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HighRiskScreen), findsNothing);

    await openLogCraving(tester);
    expectFreshForm();
    await fillAndSubmit(tester);
    expect(find.text('Medium Risk'), findsOneWidget);
    expect((await savedLogs()).map((l) => l.relapseRiskScore), [
      RelapseRiskLevel.high,
      RelapseRiskLevel.medium,
    ]);
  });

  group('CravingLogController.startNewEntry', () {
    test('clears the previous result but keeps saved logs', () async {
      prediction = _ScriptedPredictionClient([RelapseRiskLevel.medium]);
      controller = buildController(repository);
      await controller.submitCraving(
        userId: 'u1',
        intensity: 6,
        mood: Mood.stressed,
        triggerCategory: TriggerCategory.stress,
        locationContext: 'Home',
        activity: 'Eating',
      );
      expect(controller.status, CravingLogStatus.success);
      expect(controller.lastRiskLevel, RelapseRiskLevel.medium);
      expect(controller.lastPredictionSource, PredictionSource.machineLearning);

      controller.startNewEntry();

      expect(controller.status, CravingLogStatus.idle);
      expect(controller.lastRiskLevel, isNull);
      expect(controller.lastPredictionSource, isNull);
      expect(controller.assessmentPending, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.suggestProfessionalSupport, isFalse);
      expect(await savedLogs(), hasLength(1));
    });

    test(
      'a pending assessment result is still saved when shown after a new entry',
      () async {
        prediction = _ScriptedPredictionClient([RelapseRiskLevel.low])
          ..hold = Completer<void>();
        controller = buildController(repository);
        final submission = controller.submitCraving(
          userId: 'u1',
          intensity: 3,
          mood: Mood.bored,
          triggerCategory: TriggerCategory.boredom,
          locationContext: 'Work',
          activity: 'Taking a break',
        );
        await Future<void>.delayed(Duration.zero);
        controller.startNewEntry();
        prediction.hold!.complete();

        expect(await submission, isTrue);
        expect(controller.status, CravingLogStatus.idle);
        expect(controller.lastRiskLevel, isNull);
        expect((await savedLogs()).single.relapseRiskScore, RelapseRiskLevel.low);
      },
    );
  });
}

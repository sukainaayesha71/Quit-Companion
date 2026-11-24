import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/presentation/screens/high_risk_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/log_craving_screen.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

// Open Decision 6 (2026-08-17) mood-slider field keys, in the same order
// as log_craving_screen.dart's _moodSliderLabels map.
const _moodSliderFields = [
  'moodHappy',
  'moodExcited',
  'moodEnthusiastic',
  'moodContented',
  'moodCalm',
  'moodIrritable',
  'moodAnxious',
  'moodStressed',
  'moodSad',
  'moodBored',
];

void main() {
  CravingLogController buildController({
    RelapseRiskLevel risk = RelapseRiskLevel.low,
    bool fail = false,
  }) {
    return CravingLogController(
      FakeCravingLogRepository(),
      FakeRelapsePredictionClient(fixedRiskLevel: risk, fail: fail),
    );
  }

  AlternativesController buildAlternativesController() =>
      AlternativesController(FakeHabitAlternativeAttemptRepository());

  Future<void> pumpScreen(
    WidgetTester tester,
    CravingLogController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LogCravingScreen(
          userId: 'u1',
          controller: controller,
          alternativesController: buildAlternativesController(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('craving_mood_stressed')));
    // The ten Open Decision 6 mood sliders push everything below them
    // further down the SingleChildScrollView than the default test
    // viewport shows, so these taps need an explicit scroll-into-view
    // first — a real device scrolls this the same way, only implicitly.
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
  }

  testWidgets('renders every field from the approved UI reference', (
    tester,
  ) async {
    await pumpScreen(tester, buildController());

    expect(find.byKey(const Key('craving_intensity_slider')), findsOneWidget);
    expect(find.byKey(const Key('craving_mood_stressed')), findsOneWidget);
    expect(find.byKey(const Key('craving_mood_bored')), findsOneWidget);
    expect(find.byKey(const Key('craving_mood_sad')), findsOneWidget);
    expect(find.byKey(const Key('craving_mood_happy')), findsOneWidget);
    expect(find.byKey(const Key('craving_mood_social')), findsOneWidget);
    expect(find.byKey(const Key('craving_trigger_stress')), findsOneWidget);
    expect(find.byKey(const Key('craving_trigger_afterMeal')), findsOneWidget);
    expect(
      find.byKey(const Key('craving_trigger_socialPressure')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('craving_trigger_boredom')), findsOneWidget);
    expect(find.byKey(const Key('craving_trigger_other')), findsOneWidget);
    expect(find.byKey(const Key('craving_location_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('craving_activity_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('craving_notes_field')), findsOneWidget);
    expect(find.byKey(const Key('craving_submit_button')), findsOneWidget);
  });

  testWidgets('location and activity selections are saved as separate values', (
    tester,
  ) async {
    final repository = FakeCravingLogRepository();
    final controller = CravingLogController(
      repository,
      FakeRelapsePredictionClient(fixedRiskLevel: RelapseRiskLevel.low),
    );
    await pumpScreen(tester, controller);

    await fillRequiredFields(tester);
    await tester.ensureVisible(find.byKey(const Key('craving_submit_button')));
    await tester.tap(find.byKey(const Key('craving_submit_button')));
    await tester.pumpAndSettle();

    final logs = await repository.getRecentLogs('u1', DateTime(2000));
    expect(logs.single.locationContext, 'Home');
    expect(logs.single.activity, 'Working/studying');
  });

  testWidgets(
    'submitting without selecting mood/trigger/location/activity shows a validation error',
    (tester) async {
      await pumpScreen(tester, buildController());

      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pump();

      expect(find.byKey(const Key('craving_validation_error')), findsOneWidget);
    },
  );

  testWidgets(
    'a Low risk submission shows the pseudocode-exact "Log Saved. Keep going!" message',
    (tester) async {
      await pumpScreen(tester, buildController(risk: RelapseRiskLevel.low));

      await fillRequiredFields(tester);
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('craving_risk_result')), findsOneWidget);
      expect(find.text('Log saved. Keep going!'), findsOneWidget);
      expect(find.byKey(const Key('craving_submit_button')), findsNothing);
    },
  );

  testWidgets(
    'a High risk submission navigates to the approved 6a HighRiskScreen, not the inline banner',
    (tester) async {
      await pumpScreen(tester, buildController(risk: RelapseRiskLevel.high));

      await fillRequiredFields(tester);
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(HighRiskScreen), findsOneWidget);
      expect(
        find.byKey(const Key('craving_risk_result')),
        findsNothing,
      ); // replaced, not stacked on top
      expect(
        find.byType(LogCravingScreen),
        findsNothing,
      ); // pushReplacement, not push
    },
  );

  testWidgets(
    'the HighRiskScreen skip link returns straight to Dashboard with a single pop',
    (tester) async {
      final controller = buildController(risk: RelapseRiskLevel.high);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LogCravingScreen(
                    userId: 'u1',
                    controller: controller,
                    alternativesController: buildAlternativesController(),
                  ),
                ),
              ),
              child: const Text('dashboard'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('dashboard'));
      await tester.pumpAndSettle();

      await fillRequiredFields(tester);
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();
      expect(find.byType(HighRiskScreen), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('high_risk_skip_link')));
      await tester.tap(find.byKey(const Key('high_risk_skip_link')));
      await tester.pumpAndSettle();

      expect(find.text('dashboard'), findsOneWidget);
      expect(find.byType(HighRiskScreen), findsNothing);
      expect(find.byType(LogCravingScreen), findsNothing);
    },
  );

  testWidgets('renders all ten Open Decision 6 mood-rating sliders', (
    tester,
  ) async {
    await pumpScreen(tester, buildController());

    for (final field in _moodSliderFields) {
      expect(find.byKey(Key('craving_mood_slider_$field')), findsOneWidget);
    }
  });

  testWidgets(
    'submitting without touching any mood slider saves all ten as unanswered (null)',
    (tester) async {
      final repository = FakeCravingLogRepository();
      final controller = CravingLogController(
        repository,
        FakeRelapsePredictionClient(fixedRiskLevel: RelapseRiskLevel.low),
      );
      await pumpScreen(tester, controller);

      await fillRequiredFields(tester);
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();

      final logs = await repository.getRecentLogs('u1', DateTime(2000));
      expect(logs, hasLength(1));
      final log = logs.first;
      expect(log.moodHappy, isNull);
      expect(log.moodExcited, isNull);
      expect(log.moodEnthusiastic, isNull);
      expect(log.moodContented, isNull);
      expect(log.moodCalm, isNull);
      expect(log.moodIrritable, isNull);
      expect(log.moodAnxious, isNull);
      expect(log.moodStressed, isNull);
      expect(log.moodSad, isNull);
      expect(log.moodBored, isNull);
    },
  );

  testWidgets(
    'moving one mood slider saves only that rating; untouched sliders stay unanswered',
    (tester) async {
      final repository = FakeCravingLogRepository();
      final controller = CravingLogController(
        repository,
        FakeRelapsePredictionClient(fixedRiskLevel: RelapseRiskLevel.low),
      );
      await pumpScreen(tester, controller);

      await fillRequiredFields(tester);
      final anxiousSlider = tester.widget<Slider>(
        find.byKey(const Key('craving_mood_slider_moodAnxious')),
      );
      anxiousSlider.onChanged!(9);
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();

      final logs = await repository.getRecentLogs('u1', DateTime(2000));
      expect(logs.first.moodAnxious, 9.0);
      expect(logs.first.moodHappy, isNull); // untouched: not a fabricated 5
    },
  );

  testWidgets(
    'a prediction failure saves the log and labels the assessment pending',
    (tester) async {
      // Regression coverage for CravingLogController's fallback-risk-level
      // behavior: a relapse-risk backend outage previously lost the
      // craving log entirely and left the user stuck on an error with
      // nothing saved. It should now succeed and show the normal risk
      // result banner instead.
      await pumpScreen(tester, buildController(fail: true));

      await fillRequiredFields(tester);
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('craving_error_text')), findsNothing);
      expect(find.byKey(const Key('craving_risk_result')), findsOneWidget);
      expect(find.text('Medium Risk'), findsNothing);
      expect(find.text('Craving Saved'), findsOneWidget);
      expect(
        find.textContaining('risk assessment will update'),
        findsOneWidget,
      );
    },
  );

  group('SRDS 4.2 professional-support prompt', () {
    Future<CravingLogController> controllerWithHighRatings(int count) async {
      final repository = FakeCravingLogRepository();
      final now = DateTime.now();
      for (var i = 1; i <= count; i++) {
        await repository.logCraving(
          CravingLog(
            logId: 'seed$i',
            userId: 'u1',
            cravingIntensity: 6,
            mood: Mood.sad,
            triggerCategory: TriggerCategory.stress,
            locationContext: 'Home',
            activity: 'Resting',
            timestamp: now.subtract(Duration(days: i)),
            relapseRiskScore: RelapseRiskLevel.low,
            moodAnxious: 9,
            moodSad: 9,
          ),
        );
      }
      return CravingLogController(
        repository,
        FakeRelapsePredictionClient(fixedRiskLevel: RelapseRiskLevel.low),
      );
    }

    Future<void> submitForm(WidgetTester tester) async {
      await fillRequiredFields(tester);
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'after repeated high anxiety/sadness ratings a gentle prompt offers support',
      (tester) async {
        final controller = await controllerWithHighRatings(3);
        await pumpScreen(tester, controller);

        await submitForm(tester);

        expect(
          find.byKey(const Key('professional_support_prompt')),
          findsOneWidget,
        );
        final body = tester
            .widget<Text>(
              find.byKey(const Key('professional_support_prompt_body')),
            )
            .data!
            .toLowerCase();
        // Supportive and non-diagnostic: describes only what the user rated.
        for (final word in [
          'depress',
          'disorder',
          'diagnos',
          'illness',
          'you have',
        ]) {
          expect(body.contains(word), isFalse, reason: word);
        }

        await tester.tap(
          find.byKey(const Key('professional_support_prompt_view')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CrisisSupportScreen), findsOneWidget);
      },
    );

    testWidgets('"Not now" closes the prompt and the normal result is shown', (
      tester,
    ) async {
      final controller = await controllerWithHighRatings(3);
      await pumpScreen(tester, controller);

      await submitForm(tester);
      await tester.tap(
        find.byKey(const Key('professional_support_prompt_dismiss')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('professional_support_prompt')),
        findsNothing,
      );
      expect(find.byType(CrisisSupportScreen), findsNothing);
      expect(controller.status, CravingLogStatus.success);
    });

    testWidgets('without repeated high ratings no prompt appears', (
      tester,
    ) async {
      final controller = await controllerWithHighRatings(1);
      await pumpScreen(tester, controller);

      await submitForm(tester);

      expect(
        find.byKey(const Key('professional_support_prompt')),
        findsNothing,
      );
    });
  });

  group('ML integration fixes (2026-11-23)', () {
    CravingLogController controllerWith(
      FakeCravingLogRepository repo,
      FakeRelapsePredictionClient client,
    ) => CravingLogController(repo, client);

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(
        find.byKey(const Key('craving_submit_button')),
      );
      await tester.tap(find.byKey(const Key('craving_submit_button')));
      await tester.pumpAndSettle();
    }

    void moveSlider(WidgetTester tester, String key, double value) {
      tester.widget<Slider>(find.byKey(Key(key))).onChanged!(value);
    }

    testWidgets(
      'untouched mood sliders show "–" and are sent as missing; moved ones are sent',
      (tester) async {
        final repo = FakeCravingLogRepository();
        final client = FakeRelapsePredictionClient();
        await pumpScreen(tester, controllerWith(repo, client));
        await fillRequiredFields(tester);

        expect(
          find.byKey(const Key('craving_mood_rating_note')),
          findsOneWidget,
        );
        expect(find.text('–'), findsNWidgets(10));
        moveSlider(tester, 'craving_mood_slider_moodSad', 8);
        await tester.pump();
        expect(find.text('–'), findsNWidgets(9));

        await submit(tester);

        expect(client.lastMoodSad, 8.0);
        expect(client.lastMoodHappy, isNull);
        expect(client.lastMoodAnxious, isNull);
        final log = (await repo.getRecentLogs('u1', DateTime(2000))).single;
        expect(log.moodSad, 8.0);
        expect(log.moodCalm, isNull);
      },
    );

    testWidgets('"Clear mood ratings" makes every slider unanswered again', (
      tester,
    ) async {
      final client = FakeRelapsePredictionClient();
      await pumpScreen(
        tester,
        controllerWith(FakeCravingLogRepository(), client),
      );
      await fillRequiredFields(tester);
      moveSlider(tester, 'craving_mood_slider_moodHappy', 9);
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('craving_mood_clear_button')),
      );
      await tester.tap(find.byKey(const Key('craving_mood_clear_button')));
      await tester.pump();
      await submit(tester);

      expect(client.lastMoodHappy, isNull);
    });

    testWidgets(
      'the recovery check-in is shown open with its explanation on every log',
      (tester) async {
        await pumpScreen(tester, buildController());
        expect(find.byKey(const Key('craving_checkin_card')), findsOneWidget);
        expect(
          find.byKey(const Key('craving_checkin_explanation')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('craving_checkin_slider_motivation_imp')),
          findsOneWidget,
        );
        expect(
          find.text('Motivation to stay nicotine-free: not answered'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'answered check-in questions are sent; unanswered ones are not',
      (tester) async {
        final repo = FakeCravingLogRepository();
        final client = FakeRelapsePredictionClient();
        await pumpScreen(tester, controllerWith(repo, client));
        await fillRequiredFields(tester);
        moveSlider(tester, 'craving_checkin_slider_motivation_imp', 9);
        moveSlider(tester, 'craving_checkin_slider_confidence_imp', 3);
        await tester.pump();

        await submit(tester);

        expect(client.lastRecoveryContext, {
          'motivation_imp': 9.0,
          'confidence_imp': 3.0,
        });
        expect(
          (await repo.getRecentLogs(
            'u1',
            DateTime(2000),
          )).single.recoveryContext,
          {'motivation_imp': 9.0, 'confidence_imp': 3.0},
        );
      },
    );

    testWidgets(
      'skipping the check-in still saves the craving and sends nothing for it',
      (tester) async {
        final repo = FakeCravingLogRepository();
        final client = FakeRelapsePredictionClient();
        final controller = controllerWith(repo, client);
        await pumpScreen(tester, controller);
        await fillRequiredFields(tester);
        moveSlider(tester, 'craving_checkin_slider_pain_imp', 7);
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('craving_checkin_skip_button')),
        );
        await tester.tap(find.byKey(const Key('craving_checkin_skip_button')));
        await tester.pump();
        expect(
          find.byKey(const Key('craving_checkin_skipped_text')),
          findsOneWidget,
        );

        await submit(tester);

        expect(controller.status, CravingLogStatus.success);
        expect(client.lastRecoveryContext, isEmpty);
        final log = (await repo.getRecentLogs('u1', DateTime(2000))).single;
        expect(log.recoveryContext, isEmpty);
        expect(log.nicotineUsedSinceLastCheckin, isNull);
      },
    );

    testWidgets('a skipped check-in can be reopened and answered', (
      tester,
    ) async {
      await pumpScreen(tester, buildController());
      await tester.ensureVisible(
        find.byKey(const Key('craving_checkin_skip_button')),
      );
      await tester.tap(find.byKey(const Key('craving_checkin_skip_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('craving_checkin_answer_button')));
      await tester.pump();
      expect(
        find.byKey(const Key('craving_checkin_slider_motivation_imp')),
        findsOneWidget,
      );
    });

    for (final (source, label) in [
      (PredictionSource.machineLearning, 'Scored by: ML (Experimental)'),
      (PredictionSource.ruleBased, 'Scored by: Rule-based'),
      (
        PredictionSource.ruleBasedFallback,
        'Scored by: Rule-based (ML unavailable)',
      ),
    ]) {
      testWidgets('result shows the backend-reported source: $label', (
        tester,
      ) async {
        final client = FakeRelapsePredictionClient(
          fixedRiskLevel: RelapseRiskLevel.medium,
          fixedSource: source,
        );
        await pumpScreen(
          tester,
          controllerWith(FakeCravingLogRepository(), client),
        );
        await fillRequiredFields(tester);
        await submit(tester);
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('no source label when the backend did not report one', (
      tester,
    ) async {
      final client = FakeRelapsePredictionClient(
        fixedSource: PredictionSource.unknown,
      );
      await pumpScreen(
        tester,
        controllerWith(FakeCravingLogRepository(), client),
      );
      await fillRequiredFields(tester);
      await submit(tester);
      expect(find.byKey(const Key('craving_prediction_source')), findsNothing);
    });

    testWidgets('no source label while the assessment is pending (offline)', (
      tester,
    ) async {
      final client = FakeRelapsePredictionClient(fail: true);
      await pumpScreen(
        tester,
        controllerWith(FakeCravingLogRepository(), client),
      );
      await fillRequiredFields(tester);
      await submit(tester);
      expect(find.text('Craving Saved'), findsOneWidget);
      expect(find.byKey(const Key('craving_prediction_source')), findsNothing);
    });

    testWidgets(
      'a high-risk result shows its source on the alternatives screen',
      (tester) async {
        final client = FakeRelapsePredictionClient(
          fixedRiskLevel: RelapseRiskLevel.high,
          fixedSource: PredictionSource.machineLearning,
        );
        await pumpScreen(
          tester,
          controllerWith(FakeCravingLogRepository(), client),
        );
        await fillRequiredFields(tester);
        await submit(tester);
        expect(find.byType(HighRiskScreen), findsOneWidget);
        expect(find.text('Scored by: ML (Experimental)'), findsOneWidget);
      },
    );
  });
}

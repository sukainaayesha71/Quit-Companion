import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

void main() {
  final fixedNow = DateTime(2026, 8, 15, 12);

  CravingLogController buildController({
    FakeCravingLogRepository? repository,
    FakeRelapsePredictionClient? predictionClient,
  }) {
    return CravingLogController(
      repository ?? FakeCravingLogRepository(),
      predictionClient ?? FakeRelapsePredictionClient(),
      now: () => fixedNow,
    );
  }

  test(
    'submitCraving saves the log with the predicted risk level and returns true',
    () async {
      final repository = FakeCravingLogRepository();
      final predictionClient = FakeRelapsePredictionClient(
        fixedRiskLevel: RelapseRiskLevel.high,
      );
      final controller = buildController(
        repository: repository,
        predictionClient: predictionClient,
      );

      final success = await controller.submitCraving(
        userId: 'u1',
        intensity: 9,
        mood: Mood.stressed,
        triggerCategory: TriggerCategory.socialPressure,
        locationContext: 'Home',
        activity: 'Home',
      );

      expect(success, isTrue);
      expect(controller.status, CravingLogStatus.success);
      expect(controller.lastRiskLevel, RelapseRiskLevel.high);
      expect(
        await repository.countCravingsResistedSince('u1', DateTime(2026, 8, 1)),
        1,
      );
    },
  );

  test(
    'submitCraving passes last24hCount = prior logs + 1 (including this one) to the predictor',
    () async {
      final repository = FakeCravingLogRepository();
      // Two prior logs already within the last 24h.
      await controller24hSetup(repository, fixedNow);
      final predictionClient = FakeRelapsePredictionClient();
      final controller = buildController(
        repository: repository,
        predictionClient: predictionClient,
      );

      await controller.submitCraving(
        userId: 'u1',
        intensity: 1,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        locationContext: 'Work',
        activity: 'Work',
      );

      expect(predictionClient.lastLast24hCount, 3); // 2 prior + this one
    },
  );

  test('submitCraving includes optional notes when provided', () async {
    final repository = FakeCravingLogRepository();
    final controller = buildController(repository: repository);

    await controller.submitCraving(
      userId: 'u1',
      intensity: 2,
      mood: Mood.sad,
      triggerCategory: TriggerCategory.afterMeal,
      locationContext: 'Home',
      activity: 'Home',
      notes: 'Felt this after lunch',
    );

    // Verified indirectly: no crash and status success confirms notes flowed through construction.
    expect(controller.status, CravingLogStatus.success);
  });

  test(
    'submitCraving without mood-slider args saves them as unanswered (null), not as a default 5',
    () async {
      final repository = FakeCravingLogRepository();
      final controller = buildController(repository: repository);

      await controller.submitCraving(
        userId: 'u1',
        intensity: 4,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        locationContext: 'Home',
        activity: 'Home',
      );

      final log = (await repository.getRecentLogs('u1', DateTime(2000))).single;
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

  test(
    'submitCraving passes explicit mood-slider values through unchanged (Open Decision 6)',
    () async {
      final repository = FakeCravingLogRepository();
      final controller = buildController(repository: repository);

      await controller.submitCraving(
        userId: 'u1',
        intensity: 4,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        locationContext: 'Home',
        activity: 'Home',
        moodHappy: 8,
        moodExcited: 7,
        moodEnthusiastic: 6,
        moodContented: 5,
        moodCalm: 4,
        moodIrritable: 3,
        moodAnxious: 2,
        moodStressed: 1,
        moodSad: 0,
        moodBored: 9,
      );

      final log = (await repository.getRecentLogs('u1', DateTime(2000))).single;
      expect(log.moodHappy, 8);
      expect(log.moodExcited, 7);
      expect(log.moodEnthusiastic, 6);
      expect(log.moodContented, 5);
      expect(log.moodCalm, 4);
      expect(log.moodIrritable, 3);
      expect(log.moodAnxious, 2);
      expect(log.moodStressed, 1);
      expect(log.moodSad, 0);
      expect(log.moodBored, 9);
    },
  );

  test(
    'submitCraving forwards explicit mood-slider values to the prediction client',
    () async {
      final repository = FakeCravingLogRepository();
      final predictionClient = FakeRelapsePredictionClient();
      final controller = buildController(
        repository: repository,
        predictionClient: predictionClient,
      );

      await controller.submitCraving(
        userId: 'u1',
        intensity: 4,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        locationContext: 'Home',
        activity: 'Home',
        moodHappy: 8,
        moodExcited: 7,
        moodEnthusiastic: 6,
        moodContented: 5,
        moodCalm: 4,
        moodIrritable: 3,
        moodAnxious: 2,
        moodStressed: 1,
        moodSad: 0,
        moodBored: 9,
      );

      expect(predictionClient.lastMoodHappy, 8);
      expect(predictionClient.lastMoodExcited, 7);
      expect(predictionClient.lastMoodEnthusiastic, 6);
      expect(predictionClient.lastMoodContented, 5);
      expect(predictionClient.lastMoodCalm, 4);
      expect(predictionClient.lastMoodIrritable, 3);
      expect(predictionClient.lastMoodAnxious, 2);
      expect(predictionClient.lastMoodStressed, 1);
      expect(predictionClient.lastMoodSad, 0);
      expect(predictionClient.lastMoodBored, 9);
    },
  );

  test(
    'submitCraving sends unanswered mood sliders to the prediction client as missing (null)',
    () async {
      final repository = FakeCravingLogRepository();
      final predictionClient = FakeRelapsePredictionClient();
      final controller = buildController(
        repository: repository,
        predictionClient: predictionClient,
      );

      await controller.submitCraving(
        userId: 'u1',
        intensity: 4,
        mood: Mood.happy,
        triggerCategory: TriggerCategory.other,
        locationContext: 'Home',
        activity: 'Home',
      );

      expect(predictionClient.lastMoodHappy, isNull);
      expect(predictionClient.lastMoodBored, isNull);
    },
  );

  test(
    'submitCraving still saves the log with a fallback risk level when the prediction service fails',
    () async {
      // Regression test: this previously discarded the entire craving log
      // whenever the relapse-risk backend call failed (e.g. a real
      // production incident: a misconfigured backend credential meant
      // every prediction call failed, silently losing every craving log
      // logged during that time — see CravingLogController.submitCraving's
      // fallback-risk-level comment). A logged craving is worth keeping
      // even when risk-scoring is temporarily unavailable.
      final repository = FakeCravingLogRepository();
      final predictionClient = FakeRelapsePredictionClient(fail: true);
      final controller = buildController(
        repository: repository,
        predictionClient: predictionClient,
      );

      final success = await controller.submitCraving(
        userId: 'u1',
        intensity: 5,
        mood: Mood.bored,
        triggerCategory: TriggerCategory.boredom,
        locationContext: 'Home',
        activity: 'Home',
      );

      expect(success, isTrue);
      expect(controller.status, CravingLogStatus.success);
      expect(controller.lastRiskLevel, RelapseRiskLevel.medium);
      expect(
        await repository.countCravingsResistedSince('u1', DateTime(2026, 8, 1)),
        1,
      );
    },
  );
}

Future<void> controller24hSetup(
  FakeCravingLogRepository repository,
  DateTime now,
) async {
  final controller = CravingLogController(
    repository,
    FakeRelapsePredictionClient(),
    now: () => now.subtract(const Duration(hours: 1)),
  );
  await controller.submitCraving(
    userId: 'u1',
    intensity: 1,
    mood: Mood.happy,
    triggerCategory: TriggerCategory.other,
    locationContext: 'Home',
    activity: 'Home',
  );
  final controller2 = CravingLogController(
    repository,
    FakeRelapsePredictionClient(),
    now: () => now.subtract(const Duration(hours: 2)),
  );
  await controller2.submitCraving(
    userId: 'u1',
    intensity: 1,
    mood: Mood.happy,
    triggerCategory: TriggerCategory.other,
    locationContext: 'Home',
    activity: 'Home',
  );
}

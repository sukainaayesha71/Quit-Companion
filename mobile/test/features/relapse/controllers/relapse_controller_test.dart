import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/relapse/controllers/relapse_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/relapse/domain/restart_plan_calculator.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart'
    as craving_mood;
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/reminders/data/notification_event_client.dart';

class _CapturingNotificationEventClient implements NotificationEventClient {
  final List<NotificationEventType> events = [];

  @override
  Future<void> send(NotificationEventType event) async => events.add(event);
}

void main() {
  final fixedToday = DateTime(2026, 8, 15);

  RelapseController buildController({
    required FakeUserRepository userRepository,
    FakeJournalRepository? journalRepository,
    FakeCravingLogRepository? cravingLogRepository,
    NotificationEventClient? notificationEventClient,
  }) {
    return RelapseController(
      journalRepository ?? FakeJournalRepository(),
      userRepository,
      cravingLogRepository ?? FakeCravingLogRepository(),
      RestartPlanCalculator(),
      notificationEventClient: notificationEventClient,
      now: () => fixedToday,
    );
  }

  test(
    'submitRelapse saves a flagged journal entry, updates lastRelapseDate, and produces a restart plan',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
        ),
      );
      final journalRepository = FakeJournalRepository();
      final notificationClient = _CapturingNotificationEventClient();
      final controller = buildController(
        userRepository: userRepository,
        journalRepository: journalRepository,
        notificationEventClient: notificationClient,
      );

      final success = await controller.submitRelapse(
        userId: 'u1',
        productUsed: ProductType.cigarettes,
        triggerCategory: TriggerCategory.stress,
        mood: RelapseMood.guilty,
        notes: 'Had a rough day',
      );

      expect(success, isTrue);
      expect(controller.status, RelapseStatus.success);
      expect(controller.restartPlan, isNotNull);
      expect(controller.restartPlan!.steps, isNotEmpty);
      expect(notificationClient.events, [NotificationEventType.restartPlan]);

      final savedUser = await userRepository.getUser('u1');
      expect(savedUser!.lastRelapseDate, fixedToday);

      final entries = await journalRepository.getEntries('u1');
      expect(entries, hasLength(1));
      expect(entries.first.relapseFlag, isTrue);
      expect(entries.first.productUsed, ProductType.cigarettes);
      expect(entries.first.triggerCategory, TriggerCategory.stress);
      expect(entries.first.mood, RelapseMood.guilty);
      expect(entries.first.entryText, 'Had a rough day');
    },
  );

  test(
    'submitRelapse uses the user-selected relapseDate for the journal entry, but today for lastRelapseDate',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
        ),
      );
      final journalRepository = FakeJournalRepository();
      final controller = buildController(
        userRepository: userRepository,
        journalRepository: journalRepository,
      );

      await controller.submitRelapse(
        userId: 'u1',
        relapseDate: DateTime(2026, 8, 13), // backdated two days
        triggerCategory: TriggerCategory.stress,
        mood: RelapseMood.sad,
      );

      final entry = (await journalRepository.getEntries('u1')).single;
      expect(entry.entryDate, DateTime(2026, 8, 13));

      final savedUser = await userRepository.getUser('u1');
      expect(savedUser!.lastRelapseDate, fixedToday); // not backdated
    },
  );

  test(
    'submitRelapse leaves entryText null when notes is blank (no fabricated summary)',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 1),
        ),
      );
      final journalRepository = FakeJournalRepository();
      final controller = buildController(
        userRepository: userRepository,
        journalRepository: journalRepository,
      );

      await controller.submitRelapse(
        userId: 'u1',
        productUsed: ProductType.vape,
        triggerCategory: TriggerCategory.boredom,
        mood: RelapseMood.numb,
      );

      final entry = (await journalRepository.getEntries('u1')).single;
      expect(entry.entryText, isNull);
    },
  );

  test('the restart plan uses the recent craving history', () async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitStrategy: QuitStrategy.coldTurkey,
        quitDate: DateTime(2026, 8, 1),
      ),
    );
    final cravingLogRepository = FakeCravingLogRepository();
    await cravingLogRepository.logCraving(
      CravingLog(
        logId: 'c1',
        userId: 'u1',
        cravingIntensity: 3,
        mood: craving_mood.Mood.happy,
        triggerCategory: TriggerCategory.other,
        locationContext: 'Home',
        activity: 'Home',
        timestamp: DateTime(2026, 8, 10),
        relapseRiskScore: RelapseRiskLevel.low,
      ),
    );
    final controller = buildController(
      userRepository: userRepository,
      cravingLogRepository: cravingLogRepository,
    );

    await controller.submitRelapse(
      userId: 'u1',
      triggerCategory: TriggerCategory.socialPressure,
      mood: RelapseMood.frustrated,
    );

    expect(controller.restartPlan!.steps, contains(contains('1 craving')));
  });

  test(
    'submitRelapse is rejected during the Countdown phase (FR12 precondition)',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.dateBased,
          quitDate: DateTime(
            2026,
            8,
            25,
          ), // in the future relative to fixedToday
        ),
      );
      final controller = buildController(userRepository: userRepository);

      final success = await controller.submitRelapse(
        userId: 'u1',
        triggerCategory: TriggerCategory.stress,
        mood: RelapseMood.sad,
      );

      expect(success, isFalse);
      expect(controller.status, RelapseStatus.error);
      expect(controller.errorMessage, isNotNull);

      final savedUser = await userRepository.getUser('u1');
      expect(savedUser!.lastRelapseDate, isNull);
    },
  );

  test(
    'submitRelapse sets an error state when the user does not exist',
    () async {
      final controller = buildController(userRepository: FakeUserRepository());

      final success = await controller.submitRelapse(
        userId: 'missing-user',
        triggerCategory: TriggerCategory.stress,
        mood: RelapseMood.sad,
      );

      expect(success, isFalse);
      expect(controller.status, RelapseStatus.error);
    },
  );
}

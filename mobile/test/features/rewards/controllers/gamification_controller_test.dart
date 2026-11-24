import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/rewards/data/fake_badge_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/rewards/models/badge.dart' as models;
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/reminders/data/notification_event_client.dart';

class _CapturingNotificationEventClient implements NotificationEventClient {
  final List<NotificationEventType> events = [];

  @override
  Future<void> send(NotificationEventType event) async => events.add(event);
}

CravingLog _cravingLogAt(DateTime timestamp) {
  return CravingLog(
    logId: timestamp.microsecondsSinceEpoch.toString(),
    userId: 'u1',
    cravingIntensity: 3,
    mood: Mood.happy,
    triggerCategory: TriggerCategory.other,
    locationContext: 'Home',
    activity: 'Work',
    timestamp: timestamp,
    relapseRiskScore: RelapseRiskLevel.low,
  );
}

void main() {
  final fixedToday = DateTime(2026, 8, 19);

  GamificationController buildController({
    required FakeUserRepository userRepository,
    FakeUsageLogRepository? usageLogRepository,
    FakeCravingLogRepository? cravingLogRepository,
    FakeBadgeRepository? badgeRepository,
    NotificationEventClient? notificationEventClient,
  }) {
    return GamificationController(
      userRepository,
      usageLogRepository ?? FakeUsageLogRepository(),
      cravingLogRepository ?? FakeCravingLogRepository(),
      badgeRepository ?? FakeBadgeRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      notificationEventClient: notificationEventClient,
      now: () => fixedToday,
    );
  }

  test(
    'Countdown-phase user sees no badges yet, and the Reduction Streak is consumed, not recalculated',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.gradual,
          quitDate: DateTime(2026, 8, 25),
          baselineDailyUsage: 10,
          costPerUnit: 2,
          reductionSchedule: {DateTime(2026, 8, 19): 6},
        ),
      );
      final usageLogRepository = FakeUsageLogRepository();
      final controller = buildController(
        userRepository: userRepository,
        usageLogRepository: usageLogRepository,
      );

      await controller.loadRewards('u1');

      expect(controller.status, GamificationStatus.loaded);
      expect(controller.isNicotineFreePhase, isFalse);
      expect(controller.earnedBadges, isEmpty);
    },
  );

  test(
    'a Nicotine-Free-phase user newly crossing 10 days is awarded both First Day Hero and 1 Week Warrior',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 9), // 10 days before fixedToday
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final badgeRepository = FakeBadgeRepository();
      final notificationClient = _CapturingNotificationEventClient();
      final controller = buildController(
        userRepository: userRepository,
        badgeRepository: badgeRepository,
        notificationEventClient: notificationClient,
      );

      await controller.loadRewards('u1');

      expect(controller.status, GamificationStatus.loaded);
      expect(controller.isNicotineFreePhase, isTrue);
      expect(controller.newlyEarnedBadgeTypes, [
        models.BadgeType.firstDayHero,
        models.BadgeType.oneWeekWarrior,
      ]);
      expect(controller.earnedBadges.map((b) => b.badgeType), [
        models.BadgeType.firstDayHero,
        models.BadgeType.oneWeekWarrior,
      ]);
      expect(badgeRepository.getBadges('u1'), completion(hasLength(2)));
      expect(notificationClient.events, [NotificationEventType.badgeEarned]);
    },
  );

  test(
    'a badge already earned in a prior session is not re-awarded or duplicated',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 9),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final badgeRepository = FakeBadgeRepository();
      await badgeRepository.saveBadge(
        models.Badge(
          badgeId: 'u1_firstDayHero',
          userId: 'u1',
          badgeType: models.BadgeType.firstDayHero,
          dateEarned: DateTime(2026, 8, 10),
        ),
      );
      final controller = buildController(
        userRepository: userRepository,
        badgeRepository: badgeRepository,
      );

      await controller.loadRewards('u1');

      expect(controller.newlyEarnedBadgeTypes, [
        models.BadgeType.oneWeekWarrior,
      ]);
      expect(controller.earnedBadges.map((b) => b.badgeType).toSet(), {
        models.BadgeType.firstDayHero,
        models.BadgeType.oneWeekWarrior,
      });
    },
  );

  test(
    'engagement streak is derived from the union of craving and usage log dates',
    () async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 9),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final cravingLogRepository = FakeCravingLogRepository();
      await cravingLogRepository.logCraving(
        _cravingLogAt(DateTime(2026, 8, 19)),
      );
      await cravingLogRepository.logCraving(
        _cravingLogAt(DateTime(2026, 8, 18)),
      );
      final controller = buildController(
        userRepository: userRepository,
        cravingLogRepository: cravingLogRepository,
      );

      await controller.loadRewards('u1');

      expect(controller.engagementStreak, 2);
    },
  );

  test('a load failure surfaces an error status', () async {
    final controller = buildController(userRepository: FakeUserRepository());

    await controller.loadRewards('missing-user');

    expect(controller.status, GamificationStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  group('FR9/UC7 celebration queue', () {
    Future<FakeUserRepository> userWithQuitDate(
      DateTime quitDate, {
      String userId = 'u1',
      FakeUserRepository? repository,
    }) async {
      final userRepository = repository ?? FakeUserRepository();
      await userRepository.saveUser(
        NicotineUser(
          userId: userId,
          email: '$userId@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: quitDate,
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      return userRepository;
    }

    test(
      'newly awarded badges are queued lowest tier first and taken one at a time',
      () async {
        final controller = buildController(
          userRepository: await userWithQuitDate(DateTime(2026, 8, 9)),
        );

        await controller.loadRewards('u1');

        expect(controller.hasPendingCelebration, isTrue);
        expect(controller.pendingCelebrations.map((b) => b.badgeType), [
          models.BadgeType.firstDayHero,
          models.BadgeType.oneWeekWarrior,
        ]);
        expect(
          controller.takeNextCelebration()?.badgeType,
          models.BadgeType.firstDayHero,
        );
        expect(
          controller.takeNextCelebration()?.badgeType,
          models.BadgeType.oneWeekWarrior,
        );
        expect(controller.takeNextCelebration(), isNull);
        expect(controller.hasPendingCelebration, isFalse);
      },
    );

    test('a celebrated badge is never queued again on later loads', () async {
      final badgeRepository = FakeBadgeRepository();
      final controller = buildController(
        userRepository: await userWithQuitDate(DateTime(2026, 8, 9)),
        badgeRepository: badgeRepository,
      );

      await controller.loadRewards('u1');
      while (controller.takeNextCelebration() != null) {}
      await controller.loadRewards('u1');

      expect(controller.hasPendingCelebration, isFalse);
      expect(await badgeRepository.getBadges('u1'), hasLength(2));
      expect(controller.totalPoints, 60);
    });

    test(
      'concurrent loads (Dashboard + Rewards) queue each badge only once',
      () async {
        final controller = buildController(
          userRepository: await userWithQuitDate(DateTime(2026, 8, 18)),
        );

        await Future.wait([
          controller.loadRewards('u1'),
          controller.loadRewards('u1'),
        ]);

        expect(controller.pendingCelebrations.map((b) => b.badgeType), [
          models.BadgeType.firstDayHero,
        ]);
        expect(controller.totalPoints, 10);
      },
    );

    test('badges earned in a previous session are not celebrated', () async {
      final badgeRepository = FakeBadgeRepository();
      await badgeRepository.saveBadge(
        models.Badge(
          badgeId: 'u1_firstDayHero',
          userId: 'u1',
          badgeType: models.BadgeType.firstDayHero,
          dateEarned: DateTime(2026, 8, 10),
        ),
      );
      final controller = buildController(
        userRepository: await userWithQuitDate(DateTime(2026, 8, 9)),
        badgeRepository: badgeRepository,
      );

      await controller.loadRewards('u1');

      expect(controller.pendingCelebrations.map((b) => b.badgeType), [
        models.BadgeType.oneWeekWarrior,
      ]);
    });

    test('Countdown-phase users get no celebrations', () async {
      final controller = buildController(
        userRepository: await userWithQuitDate(DateTime(2026, 8, 25)),
      );

      await controller.loadRewards('u1');

      expect(controller.hasPendingCelebration, isFalse);
    });

    test('a badge whose save fails is not celebrated', () async {
      final badgeRepository = FakeBadgeRepository()
        ..failWith = Exception('offline');
      final controller = buildController(
        userRepository: await userWithQuitDate(DateTime(2026, 8, 9)),
        badgeRepository: badgeRepository,
      );

      await controller.loadRewards('u1');

      expect(controller.status, GamificationStatus.error);
      expect(controller.hasPendingCelebration, isFalse);
    });

    test(
      "switching to a different user drops the previous user's pending celebrations",
      () async {
        final userRepository = await userWithQuitDate(DateTime(2026, 8, 9));
        await userWithQuitDate(
          DateTime(2026, 8, 25),
          userId: 'u2',
          repository: userRepository,
        );
        final controller = buildController(userRepository: userRepository);

        await controller.loadRewards('u1');
        expect(controller.hasPendingCelebration, isTrue);
        await controller.loadRewards('u2');

        expect(controller.hasPendingCelebration, isFalse);
      },
    );
  });

  group('Step 2 lifecycle fixes', () {
    Future<GamificationController> loaded() async {
      final users = FakeUserRepository();
      await users.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 8, 9),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final controller = buildController(userRepository: users);
      await controller.loadRewards('u1');
      return controller;
    }

    test(
      'takeAllCelebrations returns every pending badge once, in order',
      () async {
        final controller = await loaded();
        expect(controller.takeAllCelebrations().map((b) => b.badgeType), [
          models.BadgeType.firstDayHero,
          models.BadgeType.oneWeekWarrior,
        ]);
        expect(controller.takeAllCelebrations(), isEmpty);
        expect(controller.hasPendingCelebration, isFalse);
      },
    );

    test(
      'clearSession (logout / account deletion) drops pending celebrations',
      () async {
        final controller = await loaded();
        expect(controller.hasPendingCelebration, isTrue);

        controller.clearSession();

        expect(controller.hasPendingCelebration, isFalse);
        expect(controller.earnedBadges, isEmpty);
        expect(controller.status, GamificationStatus.idle);
      },
    );
  });
}

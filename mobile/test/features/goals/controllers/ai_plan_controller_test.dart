import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/goals/domain/weekly_plan_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';

class _CoachingSpy extends CoachingClient {
  int requests = 0;
  _CoachingSpy() : super(baseUrl: 'http://unused.test');
  @override
  Future<CoachingPlan> plan(
    String kind, {
    String trigger = 'other',
    String mood = 'happy',
  }) async {
    requests++;
    return const CoachingPlan([
      'AI-selected action',
    ], 'gemini_catalogue_selection');
  }
}

void main() {
  final fixedToday = DateTime(2026, 8, 15);

  for (final source in [
    'local_fallback',
    'personalized_fallback',
    'gemini_catalogue_selection',
  ]) {
    test(
      'opening plan with saved $source automatically resolves AI availability',
      () async {
        final users = FakeUserRepository();
        final usage = FakeUsageLogRepository();
        final coaching = _CoachingSpy();
        await users.saveUser(
          NicotineUser(
            userId: 'u1',
            email: 'a@b.com',
            quitDate: fixedToday,
            weeklyGoals: const ['Saved action'],
            weeklyGoalsUpdatedAt: fixedToday,
            weeklyPlanSource: source,
          ),
        );
        await usage.logUsage(
          UsageLog(
            logId: 'l1',
            userId: 'u1',
            date: fixedToday,
            actualUsage: 2,
            targetUsage: 3,
          ),
        );
        final controller = AiPlanController(
          users,
          usage,
          FakeCravingLogRepository(),
          WeeklyPlanCalculator(now: () => fixedToday),
          now: () => fixedToday,
          coachingClient: coaching,
        );
        await controller.loadWeeklyPlan('u1');
        expect(
          coaching.requests,
          source == 'gemini_catalogue_selection' ? 0 : 1,
        );
        expect(controller.planSource, 'gemini_catalogue_selection');
        expect(
          controller.plan!.goals,
          contains(
            source == 'gemini_catalogue_selection'
                ? 'Saved action'
                : 'AI-selected action',
          ),
        );
      },
    );
  }

  test('first activity refreshes a starter plan before seven days', () async {
    final users = FakeUserRepository();
    final usage = FakeUsageLogRepository();
    await users.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitDate: fixedToday,
        weeklyGoals: ['Starter placeholder'],
        weeklyGoalsUpdatedAt: fixedToday,
        weeklyPlanSource: 'generic_starter',
      ),
    );
    await usage.logUsage(
      UsageLog(
        logId: 'l1',
        userId: 'u1',
        date: fixedToday,
        actualUsage: 2,
        targetUsage: 3,
      ),
    );
    final controller = AiPlanController(
      users,
      usage,
      FakeCravingLogRepository(),
      WeeklyPlanCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
    await controller.loadWeeklyPlan('u1');
    expect(controller.planSource, 'local_fallback');
    expect(controller.plan!.goals, isNot(contains('Starter placeholder')));
  });

  AiPlanController buildController({
    required FakeUserRepository userRepository,
  }) {
    return AiPlanController(
      userRepository,
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      WeeklyPlanCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
  }

  test(
    'loadWeeklyPlan computes and exposes a plan for a user with a quit plan set up',
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
      final controller = buildController(userRepository: userRepository);

      await controller.loadWeeklyPlan('u1');

      expect(controller.status, AiPlanStatus.loaded);
      expect(controller.plan, isNotNull);
      expect(controller.plan!.goals, isNotEmpty);
    },
  );

  test(
    'loadWeeklyPlan persists the computed plan back onto the user profile',
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
      final controller = buildController(userRepository: userRepository);

      await controller.loadWeeklyPlan('u1');

      final saved = await userRepository.getUser('u1');
      expect(saved!.weeklyGoals, controller.plan!.goals);
      expect(saved.weeklyGoalsUpdatedAt, fixedToday);
    },
  );

  test(
    'missing profile receives a starter plan without creating a profile',
    () async {
      final controller = buildController(userRepository: FakeUserRepository());

      await controller.loadWeeklyPlan('missing-user');

      expect(controller.status, AiPlanStatus.loaded);
      expect(controller.errorMessage, isNull);
      expect(controller.plan!.goals, hasLength(5));
      expect(controller.planSource, 'generic_starter');
    },
  );

  test('incomplete onboarding receives a generic starter plan', () async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      const NicotineUser(userId: 'u1', email: 'a@b.com'),
    );
    final controller = buildController(userRepository: userRepository);

    await controller.loadWeeklyPlan('u1');

    expect(controller.status, AiPlanStatus.loaded);
    expect(controller.planSource, 'generic_starter');
    expect(controller.plan!.goals, hasLength(5));
  });

  test(
    'new account receives generic goals and keeps them for seven days',
    () async {
      final users = FakeUserRepository();
      await users.saveUser(
        NicotineUser(userId: 'u1', email: 'a@b.com', quitDate: fixedToday),
      );
      final controller = buildController(userRepository: users);
      await controller.loadWeeklyPlan('u1');
      expect(controller.planSource, 'generic_starter');
      final saved = (await users.getUser('u1'))!;
      expect(saved.weeklyPlanSource, 'generic_starter');
      await users.saveUser(
        saved.copyWith(weeklyGoals: ['Keep my existing weekly goal']),
      );
      await controller.loadWeeklyPlan('u1');
      expect(controller.plan!.goals, ['Keep my existing weekly goal']);
      await controller.loadWeeklyPlan('u1', forceRefresh: true);
      expect(
        controller.plan!.goals,
        isNot(contains('Keep my existing weekly goal')),
      );
    },
  );

  test('expired weekly goals are refreshed', () async {
    final users = FakeUserRepository();
    await users.saveUser(
      NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        quitDate: fixedToday,
        weeklyGoals: ['Old goal'],
        weeklyGoalsUpdatedAt: fixedToday.subtract(const Duration(days: 7)),
      ),
    );
    final controller = buildController(userRepository: users);
    await controller.loadWeeklyPlan('u1');
    expect(controller.plan!.goals, isNot(contains('Old goal')));
    expect(controller.plan!.generatedAt, fixedToday);
  });
}

// Step 13 performance measurements (LOCAL, no device, no real network).
//
// Remote latency is SIMULATED with fixed delays — these numbers show how the
// app's own call pattern behaves under a given per-request latency; they are
// not real 4G or production measurements. Each test prints a "[perf]" line
// recorded in docs/superpowers/plans/2026-11-23-step13-performance-record.md.
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/habit_alternative_library.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';
import 'package:quit_companion/features/craving/data/offline_craving_log_repository.dart';
import 'package:quit_companion/features/craving/domain/habit_alternative_matcher.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';

const _simulatedLatency = Duration(milliseconds: 300);

/// Remote craving store with a fixed per-request delay and a call counter.
class _SlowRemote extends FakeCravingLogRepository {
  int historyFetches = 0;
  @override
  Future<List<CravingLog>> getRecentLogs(String userId, DateTime since) async {
    historyFetches++;
    await Future<void>.delayed(_simulatedLatency);
    return super.getRecentLogs(userId, since);
  }
}

class _SlowUsers extends FakeUserRepository {
  @override
  Future<NicotineUser?> getUser(String userId) async {
    await Future<void>.delayed(_simulatedLatency);
    return super.getUser(userId);
  }
}

class _SlowUsage extends FakeUsageLogRepository {
  @override
  Future<List<UsageLog>> getUsageLogs(String userId) async {
    await Future<void>.delayed(_simulatedLatency);
    return super.getUsageLogs(userId);
  }
}

CravingLog _log(int i, DateTime at) => CravingLog(
  logId: 'l$i',
  userId: 'u1',
  cravingIntensity: 1 + i % 10,
  mood: Mood.values[i % Mood.values.length],
  triggerCategory: TriggerCategory.values[i % TriggerCategory.values.length],
  locationContext: 'Home',
  activity: 'Resting',
  timestamp: at,
  relapseRiskScore: RelapseRiskLevel.low,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  recommendationVisibilityTests();

  test(
    'Dashboard load: elapsed time and remote history fetches at 300 ms per request',
    () async {
      final now = DateTime(2026, 11, 23, 12);
      final remote = _SlowRemote();
      for (var i = 0; i < 300; i++) {
        await remote.logCraving(_log(i, now.subtract(Duration(hours: i * 5))));
      }
      final users = _SlowUsers();
      await users.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          quitStrategy: QuitStrategy.coldTurkey,
          quitDate: DateTime(2026, 10, 1),
          baselineDailyUsage: 10,
          costPerUnit: 2,
        ),
      );
      final repo = OfflineCravingLogRepository(remote);
      addTearDown(repo.dispose);
      final controller = DashboardController(
        users,
        _SlowUsage(),
        repo,
        DashboardStateCalculator(now: () => now),
        now: () => now,
      );

      final sw = Stopwatch()..start();
      await controller.loadDashboard('u1');
      sw.stop();

      // ignore: avoid_print
      print(
        '[perf] dashboard_load simulated_latency=${_simulatedLatency.inMilliseconds}ms '
        'elapsed=${sw.elapsedMilliseconds}ms remote_history_fetches=${remote.historyFetches} '
        'status=${controller.status.name}',
      );
      expect(controller.status, DashboardStatus.loaded);
    },
  );

  test(
    'Habit recommendations: on-device ranking time (shown before any server re-rank)',
    () {
      final sw = Stopwatch()..start();
      const runs = 1000;
      for (var i = 0; i < runs; i++) {
        rankAlternatives(
          library: habitAlternativeLibrary,
          triggerCategory: TriggerCategory.values[i % 5],
          mood: Mood.values[i % 5],
        );
      }
      sw.stop();
      final perCallUs = sw.elapsedMicroseconds / runs;
      // ignore: avoid_print
      print(
        '[perf] local_recommendations per_call=${perCallUs.toStringAsFixed(1)}us runs=$runs',
      );
      expect(perCallUs, lessThan(2000 * 1000));
    },
  );

  test(
    'Craving update: local save to change event (offline-first repository)',
    () async {
      final repo = OfflineCravingLogRepository(_SlowRemote());
      addTearDown(repo.dispose);
      final received = Completer<void>();
      final sub = repo.watchChanges('u1').listen((_) {
        if (!received.isCompleted) received.complete();
      });
      addTearDown(sub.cancel);

      final sw = Stopwatch()..start();
      await repo.logCraving(_log(1, DateTime(2026, 11, 23)));
      await received.future;
      sw.stop();
      // ignore: avoid_print
      print('[perf] craving_update_local elapsed=${sw.elapsedMilliseconds}ms');
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 500)));
    },
  );

  test(
    'Community update: in-memory stream propagation (no Firestore)',
    () async {
      final repo = FakeCommunityPostRepository();
      final got = Completer<void>();
      final sub = repo.watchPosts().listen((posts) {
        if (posts.isNotEmpty && !got.isCompleted) got.complete();
      });
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);

      final sw = Stopwatch()..start();
      await repo.createPost(
        CommunityPost(
          postId: 'p',
          userId: 'other',
          anonymizedUsername: 'Peer',
          content: 'Day 5!',
          category: PostCategory.milestone,
          timestamp: DateTime(2026, 11, 23),
        ),
      );
      await got.future;
      sw.stop();
      // ignore: avoid_print
      print(
        '[perf] community_update_in_memory elapsed=${sw.elapsedMilliseconds}ms',
      );
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 500)));
    },
  );
}

class _SlowCoaching extends CoachingClient {
  final gate = Completer<List<String>>();
  _SlowCoaching()
    : super(baseUrl: 'http://unused.invalid', getToken: () async => 't');
  @override
  Future<List<String>> rank(String trigger, String mood) => gate.future;
}

void recommendationVisibilityTests() {
  test(
    'Habit recommendations: on-device list is shown before a slow server re-rank',
    () async {
      final coaching = _SlowCoaching();
      final controller = AlternativesController(
        FakeHabitAlternativeAttemptRepository(),
        coachingClient: coaching,
      );
      final sw = Stopwatch()..start();
      Duration? firstVisible;
      controller.addListener(() {
        if (firstVisible == null &&
            !controller.isRecommendationsLoading &&
            controller.recommendations.isNotEmpty) {
          firstVisible = sw.elapsed;
        }
      });

      final done = controller.loadRecommendations(
        userId: 'u1',
        triggerCategory: TriggerCategory.stress,
        mood: Mood.stressed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        firstVisible,
        isNotNull,
        reason: 'local ranking visible without waiting for the server',
      );
      final localFirst = controller.recommendations.first.alternativeId;

      final serverFirst = controller.recommendations.last.alternativeId;
      coaching.gate.complete([serverFirst]);
      await done;
      // ignore: avoid_print
      print(
        '[perf] recommendations_first_visible elapsed=${firstVisible!.inMilliseconds}ms (server re-rank still pending)',
      );
      expect(controller.recommendations.first.alternativeId, serverFirst);
      expect(localFirst, isNot(serverFirst));
    },
  );
}

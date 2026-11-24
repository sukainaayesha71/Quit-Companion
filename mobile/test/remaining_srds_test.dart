import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quit_companion/features/craving/data/offline_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/community/data/fake_community_post_repository.dart';
import 'package:quit_companion/features/community/models/community_post.dart';
import 'package:quit_companion/features/community/models/post_category.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/rewards/data/fake_badge_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/shared/domain/privacy_redactor.dart';

class _DisconnectedRemote extends FakeCravingLogRepository {
  bool online = false;
  @override
  Future<void> logCraving(CravingLog log) async {
    if (!online) throw StateError('offline');
    await super.logCraving(log);
  }

  @override
  Future<List<CravingLog>> getRecentLogs(String user, DateTime since) async {
    if (!online) throw StateError('offline');
    return super.getRecentLogs(user, since);
  }

  @override
  Future<void> deleteLog({
    required String userId,
    required String logId,
  }) async {
    if (!online) throw StateError('offline');
    await super.deleteLog(userId: userId, logId: logId);
  }
}

CravingLog _log(String user, String id) => CravingLog(
  logId: id,
  userId: user,
  cravingIntensity: 6,
  mood: Mood.stressed,
  triggerCategory: TriggerCategory.stress,
  locationContext: 'Home',
  activity: 'Reading',
  timestamp: DateTime(2026, 11, 17),
  relapseRiskScore: RelapseRiskLevel.medium,
  riskAssessmentPending: true,
  recoveryContext: const {'confidence_imp': 3},
  nicotineUsedSinceLastCheckin: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'offline entries survive repository restart, stay account-scoped and sync once online',
    () async {
      final remote = _DisconnectedRemote();
      final first = OfflineCravingLogRepository(remote);
      await first.logCraving(_log('u1', 'a'));
      await first.logCraving(_log('u2', 'b'));
      first.dispose();
      final restored = OfflineCravingLogRepository(remote);
      addTearDown(restored.dispose);
      final logs = await restored.getRecentLogs('u1', DateTime(2026));
      expect(logs.map((log) => log.logId), ['a']);
      expect(logs.single.riskAssessmentPending, isTrue);
      expect(logs.single.recoveryContext['confidence_imp'], 3);
      expect(logs.single.nicotineUsedSinceLastCheckin, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      remote.online = true;
      await restored.flush('u1');
      await restored.flush('u1');
      expect(await remote.countLoggedSince('u1', DateTime(2026)), 1);
      expect(await remote.countLoggedSince('u2', DateTime(2026)), 0);
    },
  );

  test(
    'offline deletion survives restart and is applied after reconnecting',
    () async {
      final remote = _DisconnectedRemote()..online = true;
      await remote.logCraving(_log('u1', 'a'));
      final first = OfflineCravingLogRepository(remote);
      await first.getRecentLogs('u1', DateTime(2026));
      remote.online = false;
      await first.deleteLog(userId: 'u1', logId: 'a');
      first.dispose();
      final restored = OfflineCravingLogRepository(remote);
      addTearDown(restored.dispose);
      expect(await restored.getRecentLogs('u1', DateTime(2026)), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      remote.online = true;
      await restored.flush('u1');
      expect(await remote.getRecentLogs('u1', DateTime(2026)), isEmpty);
    },
  );

  test(
    'community listeners receive another client post and live like changes',
    () async {
      final repository = FakeCommunityPostRepository();
      final updates = <List<CommunityPost>>[];
      final subscription = repository.watchPosts().listen(updates.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      await repository.createPost(
        CommunityPost(
          postId: 'p',
          userId: 'other',
          anonymizedUsername: 'Peer',
          content: 'One day at a time',
          category: PostCategory.tip,
          timestamp: DateTime(2026),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(updates.last.single.postId, 'p');
      await repository.setLiked(postId: 'p', userId: 'u1', liked: true);
      await Future<void>.delayed(Duration.zero);
      expect(updates.last.single.likeCount, 1);
    },
  );

  test(
    'opening rewards repeatedly never awards duplicate milestone points',
    () async {
      final users = FakeUserRepository();
      await users.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'test@example.com',
          quitDate: DateTime(2026, 1, 1),
        ),
      );
      DateTime today() => DateTime(2026, 1, 9);
      final controller = GamificationController(
        users,
        FakeUsageLogRepository(),
        FakeCravingLogRepository(),
        FakeBadgeRepository(),
        DashboardStateCalculator(now: today),
        now: today,
      );
      await controller.loadRewards('u1');
      expect(controller.totalPoints, 60);
      await controller.loadRewards('u1');
      expect(controller.totalPoints, 60);
      expect(controller.earnedBadges, hasLength(2));
    },
  );

  test(
    'contact details and the account display name are removed from shared text',
    () {
      final sanitized = redactContactDetails(
        'I am Ahsan Ali. Reach me at ahsan@example.com or +92 300 1234567.',
        displayName: 'Ahsan Ali',
      );
      expect(sanitized, isNot(contains('ahsan@example.com')));
      expect(sanitized, isNot(contains('1234567')));
      expect(sanitized, isNot(contains('Ahsan Ali')));
    },
  );
}

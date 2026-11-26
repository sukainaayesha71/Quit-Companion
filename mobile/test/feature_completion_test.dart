import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/knowledge/data/fake_article_bookmark_repository.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/data/fake_journal_repository.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';

class _DelayedClient implements HealthBotClient {
  final response = Completer<HealthBotAnswer>();
  @override
  Future<HealthBotAnswer> ask({
    required String query,
    List<HealthBotTurn> history = const [],
    HealthBotUserContext? userContext,
  }) => response.future;
}

void main() {
  test(
    'HealthBot restores only the current account history and emergency styling',
    () async {
      final repository = FakeHealthBotRepository();
      for (final id in ['u1', 'u2']) {
        await repository.logConversation(
          HealthBotConversation(
            conversationId: id,
            userId: id,
            query: 'query $id',
            botResponse: 'answer $id',
            timestamp: DateTime(2026),
            isEmergency: true,
          ),
        );
      }
      final controller = HealthBotController(FakeHealthBotClient(), repository);
      await controller.loadHistory('u1');
      expect(controller.transcript.map((m) => m.text), [
        'query u1',
        'answer u1',
      ]);
      expect(controller.transcript.last.isEmergency, isTrue);
      controller.clearSession();
      expect(controller.transcript, isEmpty);
      await controller.loadHistory('u2');
      expect(controller.transcript.map((m) => m.text), [
        'query u2',
        'answer u2',
      ]);
    },
  );

  test('late HealthBot replies cannot enter another account session', () async {
    final client = _DelayedClient();
    final controller = HealthBotController(client, FakeHealthBotRepository());
    final pending = controller.sendQuery(userId: 'u1', text: 'hello');
    controller.clearSession();
    client.response.complete(
      const HealthBotAnswer(
        type: HealthBotAnswerType.matched,
        responseText: 'old reply',
      ),
    );
    await pending;
    expect(controller.transcript, isEmpty);
  });

  test(
    'saved articles filter combines with categories and updates after unbookmarking',
    () async {
      final controller = KnowledgeHubController(
        FakeArticleBookmarkRepository(),
      );
      await controller.loadArticles(userId: 'u1');
      final article = controller.articles.first;
      await controller.toggleBookmark(
        userId: 'u1',
        articleId: article.articleId,
      );
      controller.setSavedOnly(true);
      controller.setFilter(article.category);
      expect(controller.filteredArticles.map((a) => a.articleId), [
        article.articleId,
      ]);
      await controller.toggleBookmark(
        userId: 'u1',
        articleId: article.articleId,
      );
      expect(controller.filteredArticles, isEmpty);
    },
  );

  test(
    'craving deletion refreshes history, risk history and counts without deleting another account',
    () async {
      final users = FakeUserRepository();
      await users.saveUser(
        NicotineUser(
          userId: 'u1',
          email: 'u1@test.com',
          quitDate: DateTime(2026),
        ),
      );
      final cravings = FakeCravingLogRepository();
      for (final id in ['u1', 'u2']) {
        await cravings.logCraving(
          CravingLog(
            logId: 'same-id',
            userId: id,
            cravingIntensity: 5,
            mood: Mood.stressed,
            triggerCategory: TriggerCategory.stress,
            locationContext: 'Home',
            activity: 'Resting',
            timestamp: DateTime(2026, 2),
            relapseRiskScore: RelapseRiskLevel.medium,
          ),
        );
      }
      final attempts = FakeHabitAlternativeAttemptRepository();
      await attempts.logAttempt(
        HabitAlternativeAttempt(
          attemptId: 'a1',
          userId: 'u1',
          alternativeId: 'walk',
          triggerCategory: TriggerCategory.stress,
          mood: Mood.stressed,
          attemptedAt: DateTime(2026),
          outcomeHelped: true,
        ),
      );
      final controller = TrackController(
        cravings,
        FakeJournalRepository(),
        users,
        attemptRepository: attempts,
        now: () => DateTime(2026, 3),
      );
      await controller.loadTrack('u1');
      expect(controller.habitAttempts, 1);
      expect(controller.completedHabitAttempts, 1);
      expect(controller.helpfulHabitAttempts, 1);
      expect(
        await controller.deleteCraving(controller.cravingHistory.single),
        isTrue,
      );
      expect(controller.totalCravingsLogged, 0);
      expect(controller.riskHistory, isEmpty);
      expect(await cravings.countLoggedSince('u2', DateTime(2026)), 1);
    },
  );
}

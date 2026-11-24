import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/craving/data/habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/domain/habit_alternative_matcher.dart';
import 'package:quit_companion/features/craving/models/habit_alternative.dart';
import 'package:quit_companion/features/craving/models/habit_alternative_attempt.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';
import 'package:quit_companion/shared/domain/perf_log.dart';

/// Ranks the fixed, curated library using current context and the user's
/// locally stored attempt outcomes. Recommendation text is never generated.
class AlternativesController extends ChangeNotifier {
  final HabitAlternativeAttemptRepository _repository;
  final DateTime Function() now;
  final CoachingClient? coachingClient;

  AlternativesController(
    this._repository, {
    DateTime Function()? now,
    this.coachingClient,
  }) : now = now ?? DateTime.now;

  List<HabitAlternative> recommendations = [];
  List<HabitAlternativeAttempt> attemptHistory = [];
  AlternativeCategory? filter;
  String? feedbackMessage;
  String? _lastAttemptId;
  TriggerCategory? _recommendationTrigger;
  Mood? _recommendationMood;
  bool isRecommendationsLoading = false;
  bool isHistoryLoading = false;
  String? historyErrorMessage;

  List<HabitAlternative> get filteredRecommendations => filter == null
      ? recommendations
      : recommendations.where((a) => a.category == filter).toList();

  Future<void> loadRecommendations({
    required String userId,
    required TriggerCategory triggerCategory,
    required Mood mood,
  }) async {
    _recommendationTrigger = triggerCategory;
    _recommendationMood = mood;
    isRecommendationsLoading = true;
    notifyListeners();
    final sw = Stopwatch()..start();
    await loadAttemptHistory(userId);
    recommendations = rankAlternatives(
      triggerCategory: triggerCategory,
      mood: mood,
      attemptHistory: attemptHistory,
    );
    // Step 13: show the on-device ranking right away; the server re-rank
    // (up to its 5 s timeout) only reorders the list when it arrives.
    isRecommendationsLoading = false;
    notifyListeners();
    logPerf('recommendations_local', sw.elapsed);
    await _rankRemotely(triggerCategory, mood);
    logPerf('recommendations_with_server_rerank', sw.elapsed);
    notifyListeners();
  }

  void setFilter(AlternativeCategory? category) {
    filter = category;
    notifyListeners();
  }

  Future<void> _rankRemotely(TriggerCategory trigger, Mood mood) async {
    if (coachingClient == null) return;
    try {
      final ids = await coachingClient!.rank(trigger.name, mood.name);
      final local = [...recommendations];
      recommendations = [
        for (final id in ids) ...local.where((a) => a.alternativeId == id),
        ...local.where((a) => !ids.contains(a.alternativeId)),
      ];
    } catch (_) {
      /* Local personalized ranking remains available offline. */
    }
  }

  Future<void> loadAttemptHistory(String userId) async {
    isHistoryLoading = true;
    historyErrorMessage = null;
    notifyListeners();
    try {
      final attempts = await _repository.getAttempts(userId);
      attempts.sort(
        (first, second) => second.attemptedAt.compareTo(first.attemptedAt),
      );
      attemptHistory = attempts;
    } catch (e) {
      debugPrint('AlternativesController.loadAttemptHistory failed: $e');
      attemptHistory = [];
      historyErrorMessage =
          'Could not load your activity history. Check your connection and try again.';
    } finally {
      isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectAlternative({
    required String userId,
    required HabitAlternative alternative,
    required TriggerCategory triggerCategory,
    required Mood mood,
  }) async {
    final attemptId = now().microsecondsSinceEpoch.toString();
    _lastAttemptId = attemptId;
    feedbackMessage = null;
    final attempt = HabitAlternativeAttempt(
      attemptId: attemptId,
      userId: userId,
      alternativeId: alternative.alternativeId,
      triggerCategory: triggerCategory,
      mood: mood,
      attemptedAt: now(),
    );
    try {
      await _repository.logAttempt(attempt);
      attemptHistory = [attempt, ...attemptHistory];
    } catch (e) {
      // Non-fatal, matching every other module's fire-and-forget logging
      // pattern (HealthBotController, JournalController) — a persistence
      // failure must never block the user from trying the alternative.
      debugPrint(
        'AlternativesController.selectAlternative: failed to log attempt (non-fatal): $e',
      );
    }
    notifyListeners();
  }

  Future<void> recordOutcome({
    required String userId,
    required bool helped,
    String? attemptId,
  }) async {
    final targetAttempt = attemptId ?? _lastAttemptId;
    if (targetAttempt == null) return;
    try {
      await _repository.recordOutcome(
        userId: userId,
        attemptId: targetAttempt,
        helped: helped,
      );
      attemptHistory = attemptHistory
          .map(
            (attempt) => attempt.attemptId == targetAttempt
                ? attempt.copyWith(outcomeHelped: helped)
                : attempt,
          )
          .toList();
      final triggerCategory = _recommendationTrigger;
      final mood = _recommendationMood;
      if (triggerCategory != null && mood != null) {
        recommendations = rankAlternatives(
          triggerCategory: triggerCategory,
          mood: mood,
          attemptHistory: attemptHistory,
        );
      }
      feedbackMessage = helped
          ? 'Glad that helped!'
          : 'Thanks for letting us know.';
      if (triggerCategory != null && mood != null) {
        await _rankRemotely(triggerCategory, mood);
      }
      notifyListeners();
    } catch (e) {
      debugPrint(
        'AlternativesController.recordOutcome: failed to record outcome (non-fatal): $e',
      );
    }
  }
}

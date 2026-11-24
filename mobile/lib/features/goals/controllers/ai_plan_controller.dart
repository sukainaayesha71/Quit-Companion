import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/goals/domain/weekly_plan_calculator.dart';
import 'package:quit_companion/features/goals/models/weekly_plan.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';

enum AiPlanStatus { idle, loading, loaded, error }

/// Loads a saved weekly plan, refreshing after seven days or a new relapse.
/// Accounts without activity receive a generic starter plan.
class AiPlanController extends ChangeNotifier {
  final UserRepository _userRepository;
  final UsageLogRepository _usageLogRepository;
  final CravingLogRepository _cravingLogRepository;
  final WeeklyPlanCalculator _calculator;
  final DateTime Function() now;
  final CoachingClient? coachingClient;
  String planSource = 'local_fallback';

  String get planExplanation => switch (planSource) {
    'generic_starter' =>
      'Starter plan: log your activity to personalize your next steps.',
    'gemini_catalogue_selection' =>
      'AI-selected activities based on your profile and activity feedback.',
    'personalized_fallback' =>
      'Suggested activities based on your activity feedback. AI selection was unavailable.',
    'saved_plan' => 'Your saved plan for this week.',
    _ => 'Suggestions based on your recent logs. AI selection was unavailable.',
  };

  AiPlanController(
    this._userRepository,
    this._usageLogRepository,
    this._cravingLogRepository,
    this._calculator, {
    DateTime Function()? now,
    this.coachingClient,
  }) : now = now ?? DateTime.now;

  AiPlanStatus status = AiPlanStatus.idle;
  String? errorMessage;
  WeeklyPlan? plan;
  NicotineUser? user;

  Future<void> loadWeeklyPlan(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (status == AiPlanStatus.loading) return;
    status = AiPlanStatus.loading;
    errorMessage = null;
    plan = null;
    user = null;
    notifyListeners();
    try {
      final loadedUser = await _userRepository.getUser(userId);
      user = loadedUser;
      if (loadedUser == null || loadedUser.quitDate == null) {
        plan = _calculator.starterPlan();
        planSource = 'generic_starter';
        status = AiPlanStatus.loaded;
        notifyListeners();
        return;
      }
      final windowStart = now().subtract(const Duration(days: 7));
      final usageLogs = await _usageLogRepository.getUsageLogs(userId);
      final cravingLogs = await _cravingLogRepository.getRecentLogs(
        userId,
        windowStart,
      );
      final hasActivity =
          cravingLogs.isNotEmpty ||
          usageLogs.any((log) => !log.date.isBefore(windowStart));
      final savedAt = loadedUser.weeklyGoalsUpdatedAt;
      final relapseAt = loadedUser.lastRelapseDate;
      final savedSource = loadedUser.weeklyPlanSource;
      if (!forceRefresh &&
          savedAt != null &&
          savedSource != null &&
          !savedAt.isAfter(now()) &&
          now().difference(savedAt) < const Duration(days: 7) &&
          (loadedUser.weeklyGoals?.isNotEmpty ?? false) &&
          (relapseAt == null || !relapseAt.isAfter(savedAt)) &&
          !(hasActivity &&
              coachingClient != null &&
              savedSource != 'gemini_catalogue_selection') &&
          !(savedSource == 'generic_starter' && hasActivity)) {
        plan = WeeklyPlan(goals: loadedUser.weeklyGoals!, generatedAt: savedAt);
        planSource = savedSource;
        status = AiPlanStatus.loaded;
        notifyListeners();
        return;
      }
      var weeklyPlan = !hasActivity
          ? _calculator.starterPlan()
          : _calculator.generate(
              user: loadedUser,
              usageLogs: usageLogs,
              cravingLogs: cravingLogs,
            );
      planSource = hasActivity ? 'local_fallback' : 'generic_starter';
      if (hasActivity && coachingClient != null) {
        try {
          final triggerCounts = <String, int>{};
          for (final log in cravingLogs) {
            triggerCounts.update(
              log.triggerCategory.name,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          }
          final trigger = triggerCounts.isEmpty
              ? 'other'
              : triggerCounts.entries
                    .reduce((a, b) => a.value >= b.value ? a : b)
                    .key;
          final generated = await coachingClient!.plan(
            'weekly',
            trigger: trigger,
            mood: cravingLogs.isEmpty ? 'happy' : cravingLogs.first.mood.name,
          );
          // Keep the goals derived from usage and quit progress alongside
          // suggested activities rather than replacing them with a catalogue.
          if (generated.source != 'generic_starter') {
            weeklyPlan = WeeklyPlan(
              goals: {...weeklyPlan.goals, ...generated.steps}.toList(),
              generatedAt: now(),
            );
            planSource = generated.source;
          }
        } catch (_) {
          /* Keep the offline plan available. */
        }
      }
      final updatedUser = loadedUser.copyWith(
        weeklyGoals: weeklyPlan.goals,
        weeklyGoalsUpdatedAt: weeklyPlan.generatedAt,
        weeklyPlanSource: planSource,
      );
      await _userRepository.saveUser(updatedUser);
      user = updatedUser;
      plan = weeklyPlan;
      status = AiPlanStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('AiPlanController.loadWeeklyPlan failed: $e');
      errorMessage =
          'Could not load your weekly plan. Check your connection and try again.';
      status = AiPlanStatus.error;
      notifyListeners();
    }
  }
}

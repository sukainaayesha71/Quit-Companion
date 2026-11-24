import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/crisis_support/domain/professional_support_check.dart';
import 'package:quit_companion/features/reminders/data/high_risk_checkin_scheduler.dart';
import 'package:quit_companion/features/reminders/domain/high_risk_checkin_policy.dart';
import 'package:quit_companion/shared/domain/perf_log.dart';

/// Fallback when the relapse-risk backend is unreachable (see
/// submitCraving): medium is the middle ground between falsely reassuring
/// the user with "low" and triggering the more intensive High-risk/
/// alternatives flow with "high" for what might just be a network blip.
const _fallbackRiskLevelOnPredictionFailure = RelapseRiskLevel.medium;

enum CravingLogStatus { idle, submitting, success, error }

/// FR5/FR6 (Module 3): orchestrates a single Log Craving submission —
/// counts the last-24h logs (feeds the relapse-risk rule), scores it via
/// RelapsePredictionClient, then persists the CravingLog with that result.
class CravingLogController extends ChangeNotifier {
  final CravingLogRepository _cravingLogRepository;
  final RelapsePredictionClient _relapsePredictionClient;
  final DateTime Function() now;
  final ProfessionalSupportCheck _supportCheck;

  /// FR11/UC9 gentle check-ins; null in tests that don't exercise them.
  final HighRiskCheckInScheduler? checkInScheduler;

  CravingLogController(
    this._cravingLogRepository,
    this._relapsePredictionClient, {
    DateTime Function()? now,
    ProfessionalSupportCheck supportCheck = const ProfessionalSupportCheck(),
    this.checkInScheduler,
  }) : now = now ?? DateTime.now,
       _supportCheck = supportCheck;

  /// The in-flight check-in evaluation for the last submission. Runs in the
  /// background so it never delays the result screen; exposed for tests.
  @visibleForTesting
  Future<CheckInDecision?>? pendingCheckIn;

  CravingLogStatus status = CravingLogStatus.idle;
  String? errorMessage;
  RelapseRiskLevel? lastRiskLevel;
  bool assessmentPending = false;

  /// Which method produced [lastRiskLevel], as reported by the backend
  /// (null while pending/offline). Shown on the result.
  PredictionSource? lastPredictionSource;

  /// SRDS 4.2: true after a successful submission when the user has
  /// repeatedly rated themselves highly anxious or sad (see
  /// ProfessionalSupportCheck) and hasn't been prompted within the
  /// cooldown. LogCravingScreen shows the gentle prompt, then calls
  /// [markProfessionalSupportPromptShown].
  bool suggestProfessionalSupport = false;
  DateTime? _lastSupportPromptAt;

  void markProfessionalSupportPromptShown() {
    suggestProfessionalSupport = false;
    _lastSupportPromptAt = now();
  }

  Future<bool> submitCraving({
    required String userId,
    required int intensity,
    required Mood mood,
    required TriggerCategory triggerCategory,
    required String locationContext,
    required String activity,
    String? notes,
    Map<String, double> recoveryContext = const {},
    bool? nicotineUsedSinceLastCheckin,
    // ML integration fix (2026-11-23): only ratings the user actually gave.
    // null = not answered; it is stored and sent as missing (the backend's
    // fitted imputer handles it), never as a fabricated default of 5.
    double? moodHappy,
    double? moodExcited,
    double? moodEnthusiastic,
    double? moodContented,
    double? moodCalm,
    double? moodIrritable,
    double? moodAnxious,
    double? moodStressed,
    double? moodSad,
    double? moodBored,
  }) async {
    status = CravingLogStatus.submitting;
    errorMessage = null;
    suggestProfessionalSupport = false;
    notifyListeners();
    try {
      final timestamp = now();
      var priorCount = 0;
      try {
        priorCount = await _cravingLogRepository
            .countLoggedSince(
              userId,
              timestamp.subtract(const Duration(hours: 24)),
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        /* Local capture must remain available offline. */
      }
      assessmentPending = false;
      lastPredictionSource = null;
      RelapseRiskLevel riskLevel;
      final predictionTimer = Stopwatch()..start();
      try {
        final prediction = await _relapsePredictionClient
            .predictDetailed(
              intensity: intensity,
              mood: mood,
              triggerCategory: triggerCategory,
              // Includes this entry; see backend/app/relapse/router.py.
              last24hCount: priorCount + 1,
              moodHappy: moodHappy,
              moodExcited: moodExcited,
              moodEnthusiastic: moodEnthusiastic,
              moodContented: moodContented,
              moodCalm: moodCalm,
              moodIrritable: moodIrritable,
              moodAnxious: moodAnxious,
              moodStressed: moodStressed,
              moodSad: moodSad,
              moodBored: moodBored,
              recoveryContext: recoveryContext,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw RelapsePredictionException(
                  'Assessment is pending until the service is reachable.',
                );
              },
            );
        riskLevel = prediction.riskLevel;
        lastPredictionSource = prediction.source;
      } on RelapsePredictionException catch (e) {
        // A craving log is worth saving even when the risk-scoring backend
        // is down — losing the user's entry entirely (the previous
        // behavior) meant My Quit Plan and Dashboard stats silently never
        // reflected cravings logged during any backend outage. Falls back
        // to a fixed conservative risk level instead of guessing.
        debugPrint(
          'CravingLogController.submitCraving: prediction failed, saving with fallback risk level: $e',
        );
        riskLevel = _fallbackRiskLevelOnPredictionFailure;
        assessmentPending = true;
      }
      logPerf(
        assessmentPending ? 'relapse_prediction_failed' : 'relapse_prediction',
        predictionTimer.elapsed,
      );
      final log = CravingLog(
        logId: timestamp.microsecondsSinceEpoch.toString(),
        userId: userId,
        cravingIntensity: intensity,
        mood: mood,
        triggerCategory: triggerCategory,
        locationContext: locationContext,
        activity: activity,
        notes: notes,
        timestamp: timestamp,
        relapseRiskScore: riskLevel,
        riskAssessmentPending: assessmentPending,
        recoveryContext: recoveryContext,
        nicotineUsedSinceLastCheckin: nicotineUsedSinceLastCheckin,
        moodHappy: moodHappy,
        moodExcited: moodExcited,
        moodEnthusiastic: moodEnthusiastic,
        moodContented: moodContented,
        moodCalm: moodCalm,
        moodIrritable: moodIrritable,
        moodAnxious: moodAnxious,
        moodStressed: moodStressed,
        moodSad: moodSad,
        moodBored: moodBored,
      );
      await _cravingLogRepository.logCraving(log);
      suggestProfessionalSupport = await _shouldSuggestSupport(userId, log);
      // Not awaited: the scheduler never throws and must not slow saving.
      pendingCheckIn = checkInScheduler?.onCravingLogged(userId, log);
      lastRiskLevel = riskLevel;
      status = CravingLogStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      // Logged so a real failure is diagnosable from logcat instead of
      // requiring inference — the earlier physical-device diagnosis had no
      // way to confirm what actually failed here.
      debugPrint('CravingLogController.submitCraving failed: $e');
      errorMessage =
          'Could not log this craving. Check your connection and try again.';
      status = CravingLogStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Never blocks or fails a submission: any lookup error (e.g. offline)
  /// simply means no prompt this time.
  Future<bool> _shouldSuggestSupport(String userId, CravingLog saved) async {
    final current = now();
    final last = _lastSupportPromptAt;
    if (last != null &&
        current.difference(last) < ProfessionalSupportCheck.promptCooldown) {
      return false;
    }
    try {
      final recent = await _cravingLogRepository
          .getRecentLogs(
            userId,
            current.subtract(ProfessionalSupportCheck.window),
          )
          .timeout(const Duration(seconds: 2));
      final logs = [...recent.where((l) => l.logId != saved.logId), saved];
      return _supportCheck.shouldSuggest(logs, now: current);
    } catch (_) {
      return false;
    }
  }
}

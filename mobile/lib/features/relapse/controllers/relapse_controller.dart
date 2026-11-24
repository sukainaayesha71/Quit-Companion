import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/journal/data/journal_repository.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/relapse/domain/restart_plan_calculator.dart';
import 'package:quit_companion/features/journal/models/journal_entry.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/relapse/models/restart_plan.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/reminders/data/notification_event_client.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';
import 'package:quit_companion/features/reminders/data/high_risk_checkin_scheduler.dart';

enum RelapseStatus { idle, submitting, success, error }

/// FR12 (Module 5): SDD §7.4's `Log_Relapse` — saves the relapse as a
/// flagged JournalEntry, updates `lastRelapseDate` (DashboardStateCalculator,
/// Module 2, already reacts to this correctly — no change needed there),
/// then reuses Module 4's already-built RestartPlanCalculator, exactly the
/// dependency that module's plan left open for this one to complete.
class RelapseController extends ChangeNotifier {
  final JournalRepository _journalRepository;
  final UserRepository _userRepository;
  final CravingLogRepository _cravingLogRepository;
  final RestartPlanCalculator _restartPlanCalculator;
  final NotificationEventClient _notificationEventClient;
  final DateTime Function() now;
  final CoachingClient? coachingClient;

  /// FR11/UC9: a confirmed relapse cancels any pending gentle check-in.
  final HighRiskCheckInScheduler? checkInScheduler;

  RelapseController(
    this._journalRepository,
    this._userRepository,
    this._cravingLogRepository,
    this._restartPlanCalculator, {
    NotificationEventClient? notificationEventClient,
    DateTime Function()? now,
    this.coachingClient,
    this.checkInScheduler,
  }) : _notificationEventClient =
           notificationEventClient ?? const NoopNotificationEventClient(),
       now = now ?? DateTime.now;

  RelapseStatus status = RelapseStatus.idle;
  String? errorMessage;
  RestartPlan? restartPlan;

  Future<bool> submitRelapse({
    required String userId,
    DateTime? relapseDate,
    ProductType? productUsed,
    required TriggerCategory triggerCategory,
    required RelapseMood mood,
    String? notes,
  }) async {
    status = RelapseStatus.submitting;
    errorMessage = null;
    notifyListeners();
    try {
      final user = await _userRepository.getUser(userId);
      if (user == null || user.quitDate == null) {
        errorMessage = 'Your quit plan is not set up yet.';
        status = RelapseStatus.error;
        notifyListeners();
        return false;
      }
      final today = _dateOnly(now());
      final quitDay = _dateOnly(user.quitDate!);
      if (today.isBefore(quitDay)) {
        // FR12: "A relapse event is only loggable... in the Nicotine-Free
        // phase" — SDD §8 requires this precondition check explicitly.
        errorMessage = 'Relapse logging is only available after your Quit Day.';
        status = RelapseStatus.error;
        notifyListeners();
        return false;
      }

      final trimmedNotes = notes?.trim();
      final entry = JournalEntry(
        entryId: now().microsecondsSinceEpoch.toString(),
        userId: userId,
        entryText: (trimmedNotes != null && trimmedNotes.isNotEmpty)
            ? trimmedNotes
            : null,
        // "When did this happen?" — the journal record reflects what the
        // user actually says, even if backdated. `lastRelapseDate` below
        // stays `today` regardless — SDD §7.4 says literally
        // "User.lastRelapseDate = Today", not the user-selected date.
        entryDate: relapseDate ?? now(),
        relapseFlag: true,
        productUsed: productUsed,
        triggerCategory: triggerCategory,
        mood: mood,
      );
      await _journalRepository.saveEntry(entry);
      await _userRepository.saveUser(user.copyWith(lastRelapseDate: today));
      await checkInScheduler?.onRelapseLogged(userId);

      final cravingHistory = await _cravingLogRepository.getRecentLogs(
        userId,
        today.subtract(const Duration(days: 30)),
      );
      restartPlan = _restartPlanCalculator.generate(
        cravingHistory: cravingHistory,
        relapseTrigger: triggerCategory,
      );
      if (coachingClient != null) {
        try {
          final generated = await coachingClient!.plan(
            'restart',
            trigger: triggerCategory.name,
          );
          restartPlan = RestartPlan(steps: generated.steps);
        } catch (_) {
          /* Preserve the local restart plan during outages. */
        }
      }
      try {
        await _notificationEventClient.send(NotificationEventType.restartPlan);
      } catch (e) {
        debugPrint('Could not send restart-plan notification: $e');
      }
      status = RelapseStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('RelapseController.submitRelapse failed: $e');
      errorMessage =
          'Could not log this relapse. Check your connection and try again.';
      status = RelapseStatus.error;
      notifyListeners();
      return false;
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

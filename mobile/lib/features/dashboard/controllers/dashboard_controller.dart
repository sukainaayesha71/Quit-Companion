import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/craving/data/craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/tracking/domain/weekly_trend_calculator.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/shared/domain/perf_log.dart';

enum DashboardStatus { idle, loading, loaded, error }

/// FR4/FR10/FR16 (Module 2): loads the signed-in user's dashboard state and
/// exposes SDD §7.5's Countdown-phase usage logging.
class DashboardController extends ChangeNotifier {
  final UserRepository _userRepository;
  final UsageLogRepository _usageLogRepository;
  final CravingLogRepository _cravingLogRepository;
  final DashboardStateCalculator _calculator;
  final WeeklyTrendCalculator _weeklyTrendCalculator;
  final DateTime Function() now;

  DashboardController(
    this._userRepository,
    this._usageLogRepository,
    this._cravingLogRepository,
    this._calculator, {
    DateTime Function()? now,
    WeeklyTrendCalculator? weeklyTrendCalculator,
  }) : now = now ?? DateTime.now,
       _weeklyTrendCalculator =
           weeklyTrendCalculator ??
           WeeklyTrendCalculator(now: now ?? DateTime.now);

  DashboardStatus status = DashboardStatus.idle;
  String? errorMessage;
  DashboardState? state;
  List<int> weeklyTrend = List.filled(7, 0);
  double? pctBetterThanLastWeek;
  bool todaysCravingLogged = false;

  /// FR4/UC6 30-day view of the progress chart — same craving-log data and
  /// bucketing as [weeklyTrend], over 30 days, compared with the 30 before.
  List<int> monthlyTrend = List.filled(30, 0);
  double? pctBetterThanLastMonth;

  /// FR4/UC6 first-craving empty state: false only once a load has
  /// confirmed the user has never logged a craving. Defaults to true so the
  /// prompt never flashes up before data arrives.
  bool hasAnyCravingLogs = true;

  /// FR4/UC6 high-risk banner: the user's most recent craving log, if it
  /// was scored high risk within the last [highRiskBannerWindow]. A later
  /// lower-risk log, or a still-pending assessment, clears it.
  CravingLog? recentHighRiskLog;
  static const highRiskBannerWindow = Duration(hours: 24);

  NicotineUser? _user;
  NicotineUser? get user => _user;
  StreamSubscription<void>? _liveSubscription;
  String? _watchedUser;
  int _loadEpoch = 0;

  void clearSession() {
    _loadEpoch++;
    unawaited(_liveSubscription?.cancel());
    _liveSubscription = null;
    _watchedUser = null;
    _user = null;
    state = null;
    status = DashboardStatus.idle;
    weeklyTrend = List.filled(7, 0);
    monthlyTrend = List.filled(30, 0);
    pctBetterThanLastMonth = null;
    hasAnyCravingLogs = true;
    recentHighRiskLog = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_liveSubscription?.cancel());
    super.dispose();
  }

  Future<void> loadDashboard(String userId) async {
    final loadTimer = Stopwatch()..start();
    final epoch = ++_loadEpoch;
    final source = _cravingLogRepository;
    if (_watchedUser != userId && source is LiveCravingLogRepository) {
      _watchedUser = userId;
      await _liveSubscription?.cancel();
      _liveSubscription = (source as LiveCravingLogRepository)
          .watchChanges(userId)
          .listen((_) {
            if (status != DashboardStatus.loading) {
              unawaited(loadDashboard(userId));
            }
          }, onError: (Object _) {});
    }
    status = DashboardStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final user = await _userRepository.getUser(userId);
      if (epoch != _loadEpoch) return;
      if (user == null || user.quitDate == null) {
        // Keep the loaded user (so the header can still greet them by name)
        // even though there's no quit plan yet to build dashboard state
        // from — these are independent facts. Previously this discarded
        // the whole user on a missing quitDate, which made the greeting
        // fall back to "Hi there" for every account without a completed
        // quit plan (e.g. phone/OTP sign-ups, which never go through
        // onboarding at all) even though their name was saved correctly.
        _user = user;
        state = null;
        errorMessage = 'Your quit plan is not set up yet.';
        status = DashboardStatus.error;
        notifyListeners();
        return;
      }
      _user = user;
      final today = _dateOnly(now());
      // Step 13: these reads are independent, so they run in parallel
      // instead of one after another (each is a network round trip).
      // 60 days of logs: the 30-day chart plus the 30 days it is compared
      // against; the 7-day trend uses the same logs.
      final usageFuture = _usageLogRepository.getUsageLogs(userId);
      final resistedFuture = _cravingLogRepository.countCravingsResistedSince(
        userId,
        _effectiveStart(user),
      );
      final recentFuture = _cravingLogRepository.getRecentLogs(
        userId,
        today.subtract(const Duration(days: 59)),
      );
      final todayCountFuture = _cravingLogRepository.countLoggedSince(
        userId,
        today,
      );
      final usageLogs = await usageFuture;
      final cravingsResisted = await resistedFuture;
      final recentLogs = await recentFuture;
      final trendResult = _weeklyTrendCalculator.calculate(recentLogs);
      weeklyTrend = trendResult.weeklyTrend;
      pctBetterThanLastWeek = trendResult.pctBetterThanLastWeek;
      final monthResult = _weeklyTrendCalculator.calculateRange(
        recentLogs,
        days: 30,
      );
      monthlyTrend = monthResult.trend;
      pctBetterThanLastMonth = monthResult.pctBetterThanPreviousPeriod;
      recentHighRiskLog = _findRecentHighRiskLog(recentLogs);
      todaysCravingLogged = await todayCountFuture > 0;
      hasAnyCravingLogs =
          recentLogs.isNotEmpty ||
          await _cravingLogRepository.countLoggedSince(userId, DateTime(1970)) >
              0;
      if (epoch != _loadEpoch) return;
      state = _calculator.calculate(
        user: user,
        usageLogs: usageLogs,
        cravingsResisted: cravingsResisted,
      );
      status = DashboardStatus.loaded;
      logPerf('dashboard_load', loadTimer.elapsed);
      notifyListeners();
    } catch (e) {
      errorMessage =
          'Could not load your dashboard. Check your connection and try again.';
      status = DashboardStatus.error;
      notifyListeners();
    }
  }

  /// SDD §7.5: only reachable in the Countdown phase. Returns false (and
  /// sets errorMessage) rather than throwing, so a caller can show a
  /// message without a try/catch — mirrors PhoneAuthController's style.
  Future<bool> logUsage(double actualUsage) async {
    final user = _user;
    if (user == null) {
      errorMessage = 'Load the dashboard before logging usage.';
      status = DashboardStatus.error;
      notifyListeners();
      return false;
    }
    if (state is! CountdownState) {
      errorMessage = 'Usage logging is only available before your Quit Day.';
      status = DashboardStatus.error;
      notifyListeners();
      return false;
    }
    final today = _dateOnly(now());
    final targetUsage = user.reductionSchedule?[today] ?? 0;
    final log = UsageLog(
      logId: today.toIso8601String(),
      userId: user.userId,
      date: today,
      actualUsage: actualUsage,
      targetUsage: targetUsage,
    );
    try {
      await _usageLogRepository.logUsage(log);
      await loadDashboard(user.userId);
      return true;
    } catch (e) {
      errorMessage =
          'Could not save your usage. Check your connection and try again.';
      status = DashboardStatus.error;
      notifyListeners();
      return false;
    }
  }

  CravingLog? _findRecentHighRiskLog(List<CravingLog> logs) {
    if (logs.isEmpty) return null;
    // Not every repository guarantees order, so find the newest log.
    final latest = logs.reduce(
      (a, b) => b.timestamp.isAfter(a.timestamp) ? b : a,
    );
    final isRecent = !latest.timestamp.isBefore(
      now().subtract(highRiskBannerWindow),
    );
    final isHighRisk =
        latest.relapseRiskScore == RelapseRiskLevel.high &&
        !latest.riskAssessmentPending;
    return isRecent && isHighRisk ? latest : null;
  }

  DateTime _effectiveStart(NicotineUser user) {
    final quitDate = _dateOnly(user.quitDate!);
    final lastRelapseDate = user.lastRelapseDate != null
        ? _dateOnly(user.lastRelapseDate!)
        : null;
    return (lastRelapseDate != null && lastRelapseDate.isAfter(quitDate))
        ? lastRelapseDate
        : quitDate;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

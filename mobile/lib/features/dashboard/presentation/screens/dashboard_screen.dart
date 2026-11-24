import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/community/controllers/community_controller.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/journal/controllers/journal_controller.dart';
import 'package:quit_companion/features/knowledge/controllers/knowledge_hub_controller.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/auth/data/account_deletion_repository.dart';
import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';
import 'package:quit_companion/features/relapse/controllers/relapse_controller.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/shared/widgets/staggered_entrance.dart';
import 'package:quit_companion/features/community/presentation/screens/community_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/high_risk_screen.dart';
import 'package:quit_companion/features/craving/presentation/screens/log_craving_screen.dart';
import 'package:quit_companion/features/goals/presentation/screens/weekly_plan_screen.dart';
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_screen.dart';
import 'package:quit_companion/features/journal/presentation/screens/journal_screen.dart';
import 'package:quit_companion/features/knowledge/presentation/screens/knowledge_hub_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/profile_screen.dart';
import 'package:quit_companion/features/relapse/presentation/screens/relapse_log_screen.dart';
import 'package:quit_companion/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:quit_companion/features/rewards/presentation/widgets/badge_celebration_listener.dart';
import 'package:quit_companion/features/reminders/presentation/screens/reminder_settings_screen.dart';
import 'package:quit_companion/features/tracking/presentation/screens/track_screen.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/countdown_state_view.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_background.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_bottom_nav.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_header.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/health_recovery_card.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/high_risk_banner.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/milestone_progress_card.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/nicotine_free_state_view.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/quick_access_grid.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/weekly_progress_card.dart';

/// FR4 (Module 2): top-level Dashboard, picking Countdown vs. Nicotine-Free
/// display per SDD §7.2. Layout follows docs/UI_Design/dashboard 5.png
/// (approved reference) — header, state card(s), Quick Access grid, This
/// Week card, bottom nav. Always receives an already-live
/// DashboardController and loads on mount — mirrors OtpVerificationScreen's
/// controller-injection style from Module 1.
///
/// [cravingLogController] is Module 3's entry point (FR5/FR6);
/// [aiPlanController] is Module 4's (FR17); [journalController] and
/// [relapseController] are Module 5's (FR12); [healthBotController] is
/// Module 6's (FR8) — the Quick Access tiles actually wired up, mirroring
/// how `controller` itself is injected rather than read via Provider
/// inside this screen.
class DashboardScreen extends StatefulWidget {
  final String userId;
  final DashboardController controller;
  final CravingLogController cravingLogController;
  final AiPlanController aiPlanController;
  final JournalController journalController;
  final RelapseController relapseController;
  final HealthBotController healthBotController;
  final AlternativesController alternativesController;
  final GamificationController gamificationController;
  final CommunityController communityController;
  final KnowledgeHubController knowledgeHubController;
  final ReminderController reminderController;
  final TrackController trackController;
  final ProfileController profileController;
  final VoidCallback onLogout;
  final Future<void> Function()? onAccountDeleted;
  final BiometricLockService biometricLockService;
  final AccountDeletionRepository accountDeletionRepository;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.controller,
    required this.cravingLogController,
    required this.aiPlanController,
    required this.journalController,
    required this.relapseController,
    required this.healthBotController,
    required this.alternativesController,
    required this.gamificationController,
    required this.communityController,
    required this.knowledgeHubController,
    required this.reminderController,
    required this.trackController,
    required this.profileController,
    required this.onLogout,
    this.onAccountDeleted,
    this.biometricLockService = const UnavailableBiometricLockService(),
    this.accountDeletionRepository =
        const UnconfiguredAccountDeletionRepository(),
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _hasAnimatedIn = false;
  bool _hasCheckedMilestones = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Deferred: loadDashboard's first notifyListeners() fires before any
    // await point, i.e. synchronously — calling it directly here would
    // notify DashboardController's Provider scope while this widget's own
    // parent is still mid-build, which Provider disallows.
    Future.microtask(() => widget.controller.loadDashboard(widget.userId));
    // FR14/Module 11: re-syncs the on-device reminder schedule with the
    // user's persisted setting every time the Dashboard is reached — the
    // app's most frequently-visited screen — so a reminder schedule that
    // survives an app restart doesn't depend on the user ever opening
    // the Reminders settings screen again after first configuring it.
    Future.microtask(() => widget.reminderController.loadSettings());
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    // Runs once per screen visit, the first time a load actually succeeds —
    // not on every subsequent setState (e.g. from logUsage or the reminder
    // sync), which would otherwise replay the entrance animation each time.
    if (!_hasAnimatedIn && widget.controller.status == DashboardStatus.loaded) {
      _hasAnimatedIn = true;
      _entranceController.forward();
    }
    if (!_hasCheckedMilestones &&
        widget.controller.status == DashboardStatus.loaded) {
      _hasCheckedMilestones = true;
      Future.microtask(
        () => widget.gamificationController.loadRewards(widget.userId),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    // Quick Access / This Week are general app chrome (docs/UI_Design/
    // dashboard 5.png) — only shown once a dashboard actually loaded, not
    // stacked underneath a loading spinner or error message.
    final showChrome =
        controller.status == DashboardStatus.loaded && controller.state != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            key: const Key('dashboard_background'),
            child: const IgnorePointer(child: DashboardBackground()),
          ),
          // FR9 / UC7: badges are awarded by the loadRewards call above
          // (_onControllerChanged), so the Dashboard is usually where a
          // newly-earned badge is first celebrated.
          BadgeCelebrationListener(
            controller: widget.gamificationController,
            child: const SizedBox.shrink(),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaggeredEntrance(
                      index: 0,
                      parent: _entranceController,
                      child: DashboardHeader(
                        name: controller.user?.name,
                        onNotificationsTap: () =>
                            _openReminderSettings(context),
                      ),
                    ),
                    if (showChrome && controller.recentHighRiskLog != null) ...[
                      const SizedBox(height: 20),
                      StaggeredEntrance(
                        index: 1,
                        parent: _entranceController,
                        child: HighRiskBanner(
                          onTryAlternative: () =>
                              _openAlternativesForHighRisk(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    StaggeredEntrance(
                      index: 1,
                      parent: _entranceController,
                      child: _buildBody(),
                    ),
                    if (showChrome) ...[
                      const SizedBox(height: 28),
                      StaggeredEntrance(
                        index: 2,
                        parent: _entranceController,
                        child: const Text(
                          'Quick Access',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StaggeredEntrance(
                        index: 2,
                        parent: _entranceController,
                        child: QuickAccessGrid(
                          onLogCravingTap: () => _openLogCraving(context),
                          onAlternativesTap: () => _openAlternatives(context),
                          onMyQuitPlanTap: () => _openWeeklyPlan(context),
                          onJournalTap: () => _openJournal(context),
                          onRelapseLogTap: () => _openRelapseLog(context),
                          onHealthBotTap: () => _openHealthBot(context),
                          onRewardsTap: () => _openRewards(context),
                          onCommunityTap: () => _openCommunity(context),
                          onKnowledgeHubTap: () => _openKnowledgeHub(context),
                          isNicotineFreePhase:
                              controller.state is NicotineFreeState,
                          loggedCravingToday: controller.todaysCravingLogged,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StaggeredEntrance(
                        index: 3,
                        parent: _entranceController,
                        child: WeeklyProgressCard(
                          trend: controller.weeklyTrend,
                          pctBetterThanLastWeek:
                              controller.pctBetterThanLastWeek,
                          monthlyTrend: controller.monthlyTrend,
                          pctBetterThanLastMonth:
                              controller.pctBetterThanLastMonth,
                          hasAnyCravingLogs: controller.hasAnyCravingLogs,
                          onLogFirstCraving: () => _openLogCraving(context),
                        ),
                      ),
                      if (controller.state is NicotineFreeState) ...[
                        const SizedBox(height: 16),
                        StaggeredEntrance(
                          index: 4,
                          parent: _entranceController,
                          child: MilestoneProgressCard(
                            nicotineFreeDays:
                                (controller.state as NicotineFreeState)
                                    .nicotineFreeDays,
                          ),
                        ),
                      ],
                      if (controller.state is CountdownState ||
                          controller.state is NicotineFreeState) ...[
                        const SizedBox(height: 16),
                        StaggeredEntrance(
                          index: 5,
                          parent: _entranceController,
                          child: _buildHealthRecoveryCard(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DashboardBottomNav(
        onHealthBotTap: () => _openHealthBot(context),
        onCommunityTap: () => _openCommunity(context),
        onTrackTap: () => _openTrack(context),
        onProfileTap: () => _openProfile(context),
      ),
    );
  }

  Future<void> _openLogCraving(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogCravingScreen(
          userId: widget.userId,
          controller: widget.cravingLogController,
          alternativesController: widget.alternativesController,
        ),
      ),
    );
    // FR4/UC6: a newly logged craving can clear the first-craving prompt,
    // raise or clear the high-risk banner, and change the chart — none of
    // which refresh on their own (no craving repository is live).
    if (mounted) await widget.controller.loadDashboard(widget.userId);
  }

  /// FR4/UC6 high-risk banner action: the same HighRiskScreen as the
  /// Alternatives tile, but personalized with the triggering craving's real
  /// trigger and mood, like LogCravingScreen's own high-risk redirect.
  void _openAlternativesForHighRisk(BuildContext context) {
    final log = widget.controller.recentHighRiskLog;
    if (log == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HighRiskScreen(
          userId: widget.userId,
          triggerCategory: log.triggerCategory,
          mood: log.mood,
          controller: widget.alternativesController,
        ),
      ),
    );
  }

  /// Module 7's Quick Access entry point — reaches the same HighRiskScreen
  /// (SRDS Get_Habit_Alternatives) that a high-risk craving log routes to
  /// (see LogCravingScreen), but browsed on demand rather than triggered by
  /// one. There's no real trigger/mood context outside a craving log, so
  /// this passes TriggerCategory.other/Mood.happy — the matcher's neutral
  /// pair that boosts no category (see habit_alternative_matcher.dart),
  /// leaving the library in its authored order instead of a fabricated
  /// recommendation.
  void _openAlternatives(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HighRiskScreen(
          userId: widget.userId,
          triggerCategory: TriggerCategory.other,
          mood: Mood.happy,
          controller: widget.alternativesController,
        ),
      ),
    );
  }

  void _openWeeklyPlan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeeklyPlanScreen(
          userId: widget.userId,
          controller: widget.aiPlanController,
        ),
      ),
    );
  }

  Future<void> _openJournal(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalScreen(
          userId: widget.userId,
          controller: widget.journalController,
        ),
      ),
    );
    if (mounted) await widget.controller.loadDashboard(widget.userId);
  }

  Future<void> _openRelapseLog(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RelapseLogScreen(
          userId: widget.userId,
          controller: widget.relapseController,
        ),
      ),
    );
    if (mounted) await widget.controller.loadDashboard(widget.userId);
  }

  void _openHealthBot(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthBotScreen(
          userId: widget.userId,
          controller: widget.healthBotController,
        ),
      ),
    );
  }

  void _openRewards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RewardsScreen(
          userId: widget.userId,
          controller: widget.gamificationController,
        ),
      ),
    );
  }

  void _openCommunity(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityScreen(
          userId: widget.userId,
          controller: widget.communityController,
        ),
      ),
    );
  }

  void _openKnowledgeHub(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeHubScreen(
          userId: widget.userId,
          controller: widget.knowledgeHubController,
        ),
      ),
    );
  }

  void _openReminderSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReminderSettingsScreen(controller: widget.reminderController),
      ),
    );
  }

  void _openTrack(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackScreen(
          userId: widget.userId,
          trackController: widget.trackController,
          dashboardController: widget.controller,
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: widget.userId,
          dashboardController: widget.controller,
          profileController: widget.profileController,
          aiPlanController: widget.aiPlanController,
          reminderController: widget.reminderController,
          gamificationController: widget.gamificationController,
          onLogout: widget.onLogout,
          onAccountDeleted: widget.onAccountDeleted,
          biometricLockService: widget.biometricLockService,
          accountDeletionRepository: widget.accountDeletionRepository,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final controller = widget.controller;

    if (controller.status == DashboardStatus.loading ||
        controller.status == DashboardStatus.idle) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          key: Key('dashboard_loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (controller.status == DashboardStatus.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            controller.errorMessage ?? 'Something went wrong.',
            key: const Key('dashboard_error_text'),
            style: const TextStyle(color: AppColors.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final state = controller.state;
    if (state is CountdownState) {
      return CountdownStateView(state: state, controller: controller);
    }
    if (state is NicotineFreeState) {
      return NicotineFreeStateView(state: state);
    }
    return const SizedBox.shrink();
  }

  Widget _buildHealthRecoveryCard() {
    final state = widget.controller.state;
    if (state is CountdownState) {
      return HealthRecoveryCard(
        timeline: state.healthRecoveryTimeline,
        productType: widget.controller.user?.productType,
        quitDate: state.plannedQuitDate,
        daysUntilQuit: state.daysUntilQuit,
      );
    }
    if (state is NicotineFreeState) {
      return HealthRecoveryCard(
        timeline: state.healthRecoveryTimeline,
        productType: widget.controller.user?.productType,
        quitDate: state.recoveryStartDate,
        nicotineFreeDays: state.nicotineFreeDays,
      );
    }
    return const SizedBox.shrink();
  }
}

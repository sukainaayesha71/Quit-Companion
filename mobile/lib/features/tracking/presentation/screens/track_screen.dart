import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/tracking/controllers/track_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/shared/widgets/staggered_entrance.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/recent_activity_card.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/revealing_line_chart.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/track_stat_tile.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/trigger_breakdown_card.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/monthly_progress_card.dart';
import 'package:quit_companion/features/tracking/presentation/screens/widgets/risk_history_card.dart';
import 'package:quit_companion/features/craving/presentation/screens/craving_history_screen.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';

class TrackScreen extends StatefulWidget {
  final String userId;
  final TrackController trackController;
  final DashboardController dashboardController;

  const TrackScreen({
    super.key,
    required this.userId,
    required this.trackController,
    required this.dashboardController,
  });

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _hasAnimatedIn = false;

  @override
  void initState() {
    super.initState();
    widget.trackController.addListener(_onChanged);
    Future.microtask(() => widget.trackController.loadTrack(widget.userId));
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_hasAnimatedIn &&
        widget.trackController.status == TrackStatus.loaded) {
      _hasAnimatedIn = true;
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    widget.trackController.removeListener(_onChanged);
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.trackController;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Track Your Progress')),
      body: SafeArea(child: _buildBody(controller)),
    );
  }

  Widget _buildBody(TrackController controller) {
    if (controller.status == TrackStatus.loading ||
        controller.status == TrackStatus.idle) {
      return const Center(
        key: Key('track_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (controller.status == TrackStatus.error) {
      return Center(
        child: Text(
          controller.errorMessage ?? 'Something went wrong.',
          key: const Key('track_error_text'),
          style: const TextStyle(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: const Key('track_craving_history_button'),
            icon: const Icon(Icons.history),
            label: const Text('View and manage craving history'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CravingHistoryScreen(
                    userId: widget.userId,
                    controller: controller,
                  ),
                ),
              );
              if (mounted) {
                await widget.dashboardController.loadDashboard(widget.userId);
              }
            },
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 0,
            parent: _entranceController,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This Week',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: RevealingLineChart(
                      values: widget.dashboardController.weeklyTrend,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 1,
            parent: _entranceController,
            child: Row(
              children: [
                Expanded(
                  child: TrackStatTile(
                    valueKey: const Key('track_total_cravings_tile'),
                    icon: Icons.local_fire_department_outlined,
                    iconColor: AppColors.terracotta,
                    value: controller.totalCravingsLogged,
                    label: 'Total Cravings\nLogged',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TrackStatTile(
                    valueKey: const Key('track_resisted_tile'),
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.sageDark,
                    value: ((controller.resistedPercent ?? 0) * 100).round(),
                    formatter: (v) =>
                        controller.resistedPercent == null ? '-' : '$v%',
                    label: 'Cravings\nResisted',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TrackStatTile(
                    valueKey: const Key('track_longest_streak_tile'),
                    icon: Icons.emoji_events_outlined,
                    iconColor: AppColors.terracotta,
                    value: controller.longestStreakDays,
                    formatter: (v) => '$v day${v == 1 ? '' : 's'}',
                    label: 'Longest\nStreak',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 2,
            parent: _entranceController,
            child: TriggerBreakdownCard(counts: controller.triggerBreakdown),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 3,
            parent: _entranceController,
            child: RecentActivityCard(items: controller.recentActivity),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 4,
            parent: _entranceController,
            child: MonthlyProgressCard(summaries: controller.monthlySummaries),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 5,
            parent: _entranceController,
            child: RiskHistoryCard(items: controller.riskHistory),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Habit Tracking Statistics',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.habitErrorMessage ??
                        '${controller.habitAttempts} activities tried • ${controller.completedHabitAttempts} completed • ${controller.helpfulHabitAttempts} helped',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _moneySummary(),
        ],
      ),
    );
  }

  Widget _moneySummary() {
    final state = widget.dashboardController.state;
    final user = widget.dashboardController.user;
    final saved = switch (state) {
      NicotineFreeState s => s.moneySaved,
      CountdownState s => s.moneySavedSoFar ?? 0.0,
      _ => 0.0,
    };
    final baseline = (user?.baselineDailyUsage ?? 0) * (user?.costPerUnit ?? 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Money Saved Analytics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Estimated savings: ${saved.toStringAsFixed(2)}'),
            Text(
              'Baseline spending: ${baseline.toStringAsFixed(2)}/day • ${(baseline * 7).toStringAsFixed(2)}/week • ${(baseline * 30).toStringAsFixed(2)}/30 days',
            ),
            const Text(
              'Estimates use your saved consumption and cost per unit.',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';

/// Shows the user's saved quit strategy and personal context alongside the
/// fixed weekly actions calculated from recent usage and craving logs.
class WeeklyPlanScreen extends StatefulWidget {
  final String userId;
  final AiPlanController controller;

  const WeeklyPlanScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends State<WeeklyPlanScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() => widget.controller.loadWeeklyPlan(widget.userId));
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('weekly_plan_back_button'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.sageLight,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'My Quit Plan',
                      key: Key('weekly_plan_title'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('weekly_plan_refresh'),
                    tooltip: 'Refresh plan',
                    onPressed: controller.status == AiPlanStatus.loading
                        ? null
                        : () => controller.loadWeeklyPlan(
                            widget.userId,
                            forceRefresh: true,
                          ),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Your quit date, chosen approach, personal reasons, and next steps.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildBody(controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AiPlanController controller) {
    if (controller.status == AiPlanStatus.loading ||
        controller.status == AiPlanStatus.idle) {
      return const _PlanLoadingIndicator();
    }
    if (controller.status == AiPlanStatus.error) {
      return Center(
        child: Text(
          controller.errorMessage ?? 'Something went wrong.',
          key: const Key('weekly_plan_error_text'),
          style: const TextStyle(color: AppColors.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    final user = controller.user;

    final goals = controller.plan?.goals ?? const <String>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null && user.quitDate != null)
            _buildOverview(context, user, controller.now()),
          if (user != null && _hasText(user.primaryMotivation))
            _buildDetailCard(
              icon: Icons.favorite_border_rounded,
              title: 'Why you want to quit',
              detail: user.primaryMotivation!.trim(),
              key: const Key('quit_plan_motivation'),
            ),
          if (user != null && _hasText(user.personalChallenges))
            _buildDetailCard(
              icon: Icons.support_outlined,
              title: 'Challenges to plan for',
              detail: user.personalChallenges!.trim(),
              key: const Key('quit_plan_challenges'),
            ),
          if (user != null && _hasText(user.pastQuitAttempts))
            _buildDetailCard(
              icon: Icons.history_rounded,
              title: 'What you learned from past attempts',
              detail: user.pastQuitAttempts!.trim(),
              key: const Key('quit_plan_past_attempts'),
            ),
          const SizedBox(height: 8),
          const Text(
            "This week's actions",
            key: Key('weekly_plan_actions_heading'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.planExplanation,
            key: const Key('weekly_plan_source'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < goals.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _buildGoalCard(goals[index], index),
          ],
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context, NicotineUser user, DateTime now) {
    final plannedQuitDate = _dateOnly(user.quitDate!);
    final today = _dateOnly(now);
    final lastRelapseDate = user.lastRelapseDate == null
        ? null
        : _dateOnly(user.lastRelapseDate!);
    final currentAttemptStart =
        lastRelapseDate != null && lastRelapseDate.isAfter(plannedQuitDate)
        ? lastRelapseDate
        : plannedQuitDate;
    final daysUntilQuit = plannedQuitDate.difference(today).inDays;
    final daysIntoAttempt = today.difference(currentAttemptStart).inDays;
    final quitDayText = MaterialLocalizations.of(
      context,
    ).formatMediumDate(plannedQuitDate);
    final statusText = daysUntilQuit > 0
        ? '$daysUntilQuit day${daysUntilQuit == 1 ? '' : 's'} to go'
        : daysIntoAttempt == 0
        ? 'Your Quit Day is today'
        : 'Day $daysIntoAttempt of this quit attempt';

    return Container(
      key: const Key('quit_plan_overview'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your plan at a glance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _overviewLine(
            'Approach',
            _strategyLabel(user.quitStrategy),
            key: const Key('quit_plan_strategy'),
          ),
          const SizedBox(height: 10),
          _overviewLine(
            'Quit Day',
            '$quitDayText · $statusText',
            key: const Key('quit_plan_target_date'),
          ),
        ],
      ),
    );
  }

  Widget _overviewLine(String label, String value, {required Key key}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            key: key,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String detail,
    required Key key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.sageDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(String goal, int index) {
    return Container(
      key: Key('weekly_plan_goal_$index'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.flag_outlined,
            color: AppColors.terracotta,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              goal,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _strategyLabel(QuitStrategy? strategy) => switch (strategy) {
    QuitStrategy.coldTurkey => 'Quit all at once',
    QuitStrategy.dateBased => 'Quit on a target date',
    QuitStrategy.gradual => 'Reduce gradually',
    null => 'Not selected',
  };

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _PlanLoadingIndicator extends StatefulWidget {
  const _PlanLoadingIndicator();

  @override
  State<_PlanLoadingIndicator> createState() => _PlanLoadingIndicatorState();
}

class _PlanLoadingIndicatorState extends State<_PlanLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('weekly_plan_loading'),
    child: Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: .92, end: 1.08).animate(
              CurvedAnimation(parent: _animation, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.sageLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 38,
                color: AppColors.sageDark,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Preparing your quit plan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reviewing your progress and choosing your next steps…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ),
    ),
  );
}

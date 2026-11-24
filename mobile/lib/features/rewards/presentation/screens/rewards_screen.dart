import 'package:quit_companion/shared/widgets/responsive_grid.dart';
import 'package:material_ui/material_ui.dart' hide Badge;
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/rewards/models/badge.dart' as models;
import 'package:quit_companion/features/rewards/presentation/widgets/badge_celebration_listener.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// FR9 (Module 8 — Gamification & Rewards, Mehreen's module). Matches
/// docs/UI_Design/progress and rewards 9.png: a sage-green header banner
/// with a flat journal/chart/pen/paperclip illustration, "Your Progress"
/// title, a phase-appropriate streak card (flame icon + day count + a weekly
/// streak-dot row), and a 6-tile Badges Earned grid (unlocked = solid
/// sage circle + terracotta trophy, locked = grey circle + lock badge).
class RewardsScreen extends StatefulWidget {
  final String userId;
  final GamificationController controller;

  const RewardsScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() => widget.controller.loadRewards(widget.userId));
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
      backgroundColor: AppColors.background,
      // FR9 / UC7: celebrates badges awarded by this screen's own
      // loadRewards, or any still waiting from the Dashboard.
      body: BadgeCelebrationListener(
        controller: controller,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _RewardsHeaderBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Your Progress',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildBody(controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(GamificationController controller) {
    if (controller.status == GamificationStatus.loading ||
        controller.status == GamificationStatus.idle) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          key: Key('rewards_loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (controller.status == GamificationStatus.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            controller.errorMessage ?? 'Something went wrong.',
            key: const Key('rewards_error_text'),
            style: const TextStyle(color: AppColors.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${controller.totalPoints} reward points',
          key: const Key('rewards_total_points'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _StreakCard(
          streak: controller.nicotineFreeStreak ?? controller.engagementStreak,
          label: controller.nicotineFreeStreak != null
              ? 'Nicotine-Free Streak'
              : 'Engagement Streak',
        ),
        if (controller.isNicotineFreePhase) ...[
          const SizedBox(height: 24),
          const Text(
            'Badges Earned',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _BadgeGrid(
            earned: controller.earnedBadges.map((b) => b.badgeType).toSet(),
          ),
        ] else if (controller.reductionStreak != null) ...[
          const SizedBox(height: 24),
          _ReductionStreakCard(streak: controller.reductionStreak!),
        ] else ...[
          // Cold-turkey/date-based users still in the Countdown phase have
          // neither a reduction streak nor any badges yet (FR9 gates
          // badges to the Nicotine-Free phase) — previously this left
          // just the streak card with nothing explaining why, which reads
          // as an empty/broken screen rather than "not unlocked yet."
          const SizedBox(height: 24),
          Container(
            key: const Key('rewards_badges_locked_hint'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.textSecondary,
                  size: 26,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Badges unlock once you reach your Quit Day — keep going!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (controller.rewardsHistory.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Rewards History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _RewardsHistory(badges: controller.rewardsHistory),
        ],
      ],
    );
  }
}

class _RewardsHistory extends StatelessWidget {
  final List<models.Badge> badges;

  const _RewardsHistory({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('rewards_history_list'),
      children: [
        for (final badge in badges)
          Container(
            key: Key('rewards_history_${badge.badgeId}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.terracotta,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    badge.badgeType.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${badge.badgeType.points} points',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _formatEarnedDate(badge.dateEarned),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatEarnedDate(DateTime dateTime) {
  final date = dateTime.toLocal();
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Sage-green banner (docs/UI_Design/progress and rewards 9.png), built
/// from Flutter primitives rather than a cropped screenshot — same
/// hand-painted approach as DashboardBackground, for the same reason: a
/// screenshot crop bakes in whatever UI sits below it in the reference.
class _RewardsHeaderBanner extends StatelessWidget {
  const _RewardsHeaderBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
      child: Container(
        width: double.infinity,
        height: 190,
        color: AppColors.sage,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 12,
              left: 8,
              child: IconButton(
                key: const Key('rewards_back_button'),
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const _JournalIllustration(),
          ],
        ),
      ),
    );
  }
}

/// Flat, minimal journal-with-chart illustration — notes lines, a small
/// ascending bar chart, a paperclip, a pen, and a sparkle accent — echoing
/// the reference's "journal/notes with a chart, pen, and paperclip".
class _JournalIllustration extends StatelessWidget {
  const _JournalIllustration();

  Widget _bar(double height, Color color) {
    return Container(
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 128,
            height: 106,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 78,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _bar(10, AppColors.sageLight),
                    const SizedBox(width: 5),
                    _bar(18, AppColors.sage),
                    const SizedBox(width: 5),
                    _bar(13, AppColors.terracottaLight),
                    const SizedBox(width: 5),
                    _bar(24, AppColors.terracotta),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(
            top: -8,
            left: 4,
            child: Icon(
              Icons.attach_file_rounded,
              color: AppColors.textPrimary,
              size: 26,
            ),
          ),
          Positioned(
            bottom: -8,
            right: -4,
            child: Transform.rotate(
              angle: -0.6,
              child: const Icon(
                Icons.edit_rounded,
                color: AppColors.terracottaDark,
                size: 26,
              ),
            ),
          ),
          const Positioned(
            top: -18,
            right: 22,
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final String label;

  const _StreakCard({required this.streak, required this.label});

  // The weekly dot row reads position within the current 7-day cycle from
  // the streak total rather than aligning to weekdays without a calendar.
  int get _filledDaysThisWeek => streak == 0 ? 0 : ((streak - 1) % 7) + 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -8,
            left: -4,
            child: Icon(
              Icons.auto_awesome,
              size: 18,
              color: AppColors.terracotta.withValues(alpha: 0.55),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.terracotta,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '$streak',
                      key: const Key('rewards_day_streak_value'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                key: const Key('rewards_weekly_streak_row'),
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _StreakDot(filled: i < _filledDaysThisWeek),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakDot extends StatelessWidget {
  final bool filled;

  const _StreakDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.sage : Colors.transparent,
        border: filled ? null : Border.all(color: AppColors.border, width: 1.5),
      ),
    );
  }
}

class _ReductionStreakCard extends StatelessWidget {
  final int streak;

  const _ReductionStreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('rewards_reduction_streak'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.trending_down_rounded,
            color: AppColors.sageDark,
            size: 26,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '$streak-day Reduction Streak',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final Set<models.BadgeType> earned;

  const _BadgeGrid({required this.earned});

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: models.BadgeType.values.length,
      fixedExtent: 84,
      textLines: 3,
      itemBuilder: (context, index) {
        final type = models.BadgeType.values[index];
        final isEarned = earned.contains(type);
        return Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isEarned ? AppColors.sage : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: isEarned
                        ? AppColors.terracotta
                        : AppColors.textSecondary,
                    size: 30,
                  ),
                ),
                if (!isEarned)
                  Positioned(
                    key: Key('badge_locked_${type.name}'),
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              type.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEarned
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

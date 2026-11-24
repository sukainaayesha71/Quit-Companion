import 'package:quit_companion/shared/widgets/responsive_grid.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

class _QuickAccessItem {
  final String label;
  final IconData icon;

  const _QuickAccessItem(this.label, this.icon);
}

/// Quick Access grid (docs/UI_Design/dashboard 5.png). Module 3 (Habit &
/// Trigger Tracking) enabled "Log Craving"; Module 4 (Personalized
/// Quit Plan) enabled "My Quit Plan"; Module 5 (Relapse Prevention &
/// Reflection) enables "Journal" (always) and "Relapse Log" (Nicotine-Free
/// phase only — FR12's precondition, SDD §8); Module 6 (Health-Bot, FR8)
/// enables "Health-Bot" (always — no phase gate, see Module 6 plan);
/// Module 7 (Alternatives & Habit Replacement, FR7) enables "Alternatives",
/// opening HighRiskScreen directly rather than only via a high-risk craving
/// log. Every other feature belongs to a module that isn't built yet, so
/// those tiles stay visually present but disabled — no fake screens/routes
/// are wired up for them, per instructions.
const _quickAccessItems = [
  _QuickAccessItem('Log Craving', Icons.local_fire_department_rounded),
  _QuickAccessItem('Alternatives', Icons.volunteer_activism_rounded),
  _QuickAccessItem('Health-Bot', Icons.smart_toy_rounded),
  _QuickAccessItem('Rewards', Icons.emoji_events_rounded),
  _QuickAccessItem('Community', Icons.groups_rounded),
  _QuickAccessItem('Journal', Icons.menu_book_rounded),
  _QuickAccessItem('Relapse Log', Icons.smoke_free_rounded),
  _QuickAccessItem('Knowledge Hub', Icons.auto_stories_rounded),
  _QuickAccessItem('My Quit Plan', Icons.outlined_flag_rounded),
];

class QuickAccessGrid extends StatelessWidget {
  final VoidCallback onLogCravingTap;
  final VoidCallback onAlternativesTap;
  final VoidCallback onMyQuitPlanTap;
  final VoidCallback onJournalTap;
  final VoidCallback onRelapseLogTap;
  final VoidCallback onHealthBotTap;
  final VoidCallback onRewardsTap;
  final VoidCallback onCommunityTap;
  final VoidCallback onKnowledgeHubTap;
  final bool isNicotineFreePhase;
  final bool loggedCravingToday;

  const QuickAccessGrid({
    super.key,
    required this.onLogCravingTap,
    required this.onAlternativesTap,
    required this.onMyQuitPlanTap,
    required this.onJournalTap,
    required this.onRelapseLogTap,
    required this.onHealthBotTap,
    required this.onRewardsTap,
    required this.onCommunityTap,
    required this.onKnowledgeHubTap,
    required this.isNicotineFreePhase,
    required this.loggedCravingToday,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      key: const Key('dashboard_quick_access_grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _quickAccessItems.length,
      fixedExtent: 76,
      textLines: 3,
      itemBuilder: (context, index) {
        final item = _quickAccessItems[index];
        final isGreen = index.isEven;
        final isLogCraving = index == 0;
        final isAlternatives = index == 1;
        final isHealthBot = index == 2;
        final isRewards = index == 3;
        final isCommunity = index == 4;
        final isJournal = index == 5;
        final isRelapseLog = index == 6;
        final isKnowledgeHub = index == 7;
        final isMyQuitPlan = index == _quickAccessItems.length - 1;
        final tile = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isGreen ? AppColors.sageLight : AppColors.terracottaLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: isGreen ? AppColors.sageDark : AppColors.terracottaDark,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );

        if (isLogCraving) {
          final tileWithBadge = Stack(
            clipBehavior: Clip.none,
            children: [
              tile,
              if (loggedCravingToday)
                Positioned(
                  key: const Key(
                    'dashboard_quick_access_log_craving_done_badge',
                  ),
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.sage,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          );
          return InkWell(
            key: const Key('dashboard_quick_access_log_craving'),
            borderRadius: BorderRadius.circular(18),
            onTap: onLogCravingTap,
            child: tileWithBadge,
          );
        }
        if (isAlternatives) {
          return InkWell(
            key: const Key('dashboard_quick_access_alternatives'),
            borderRadius: BorderRadius.circular(18),
            onTap: onAlternativesTap,
            child: tile,
          );
        }
        if (isHealthBot) {
          return InkWell(
            key: const Key('dashboard_quick_access_health_bot'),
            borderRadius: BorderRadius.circular(18),
            onTap: onHealthBotTap,
            child: tile,
          );
        }
        if (isRewards) {
          return InkWell(
            key: const Key('dashboard_quick_access_rewards'),
            borderRadius: BorderRadius.circular(18),
            onTap: onRewardsTap,
            child: tile,
          );
        }
        if (isCommunity) {
          return InkWell(
            key: const Key('dashboard_quick_access_community'),
            borderRadius: BorderRadius.circular(18),
            onTap: onCommunityTap,
            child: tile,
          );
        }
        if (isKnowledgeHub) {
          return InkWell(
            key: const Key('dashboard_quick_access_knowledge_hub'),
            borderRadius: BorderRadius.circular(18),
            onTap: onKnowledgeHubTap,
            child: tile,
          );
        }
        if (isMyQuitPlan) {
          return InkWell(
            key: const Key('dashboard_quick_access_my_quit_plan'),
            borderRadius: BorderRadius.circular(18),
            onTap: onMyQuitPlanTap,
            child: tile,
          );
        }
        if (isJournal) {
          return InkWell(
            key: const Key('dashboard_quick_access_journal'),
            borderRadius: BorderRadius.circular(18),
            onTap: onJournalTap,
            child: tile,
          );
        }
        if (isRelapseLog && isNicotineFreePhase) {
          return InkWell(
            key: const Key('dashboard_quick_access_relapse_log'),
            borderRadius: BorderRadius.circular(18),
            onTap: onRelapseLogTap,
            child: tile,
          );
        }
        if (isRelapseLog) {
          // FR12 (SDD §8) gates relapse logging to the Nicotine-Free
          // phase — previously this silently fell through to the generic
          // disabled tile below with no indication why, which is easy to
          // mistake for a broken feature rather than a not-yet-unlocked one.
          return Opacity(
            opacity: 0.6,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGreen
                    ? AppColors.sageLight
                    : AppColors.terracottaLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: isGreen
                        ? AppColors.sageDark
                        : AppColors.terracottaDark,
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Unlocks on Quit Day',
                    key: Key('dashboard_quick_access_relapse_log_locked_hint'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Opacity(opacity: 0.6, child: tile);
      },
    );
  }
}

import 'package:material_ui/material_ui.dart' hide Badge;
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/rewards/models/badge.dart' as models;

/// FR9 / UC7 "Congratulatory Pop-up" — shown once for newly-earned badges.
/// Uses the app's sage/terracotta palette and the Rewards trophy icon.
///
/// Step 2 fixes (2026-11-23):
/// - Badges earned together (e.g. several tiers reached at once after time
///   away) are celebrated in ONE dialog instead of a chain of modals.
/// - The action button is pinned below a scrollable body, so it is always
///   on screen — previously, on a small phone with large text, the only
///   button could sit below the visible area.
class BadgeCelebrationDialog extends StatefulWidget {
  final List<models.Badge> badges;

  BadgeCelebrationDialog({super.key, required this.badges})
    : assert(badges.isNotEmpty);

  /// Shows one dialog for [badges] and completes when it is dismissed.
  static Future<void> showAll(BuildContext context, List<models.Badge> badges) {
    if (badges.isEmpty) return Future.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss badge celebration',
      builder: (_) => BadgeCelebrationDialog(badges: badges),
    );
  }

  static Future<void> show(BuildContext context, models.Badge badge) =>
      showAll(context, [badge]);

  @override
  State<BadgeCelebrationDialog> createState() => _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<BadgeCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<models.Badge> get _badges => widget.badges;
  bool get _isSingle => _badges.length == 1;

  String _milestoneText(models.BadgeType type) {
    final days = type.thresholdDays;
    return switch (days) {
      1 => 'You made it through your first nicotine-free day.',
      180 => "Six months nicotine-free. That's a huge achievement.",
      365 => 'One full year nicotine-free. Amazing work.',
      _ => "You've been nicotine-free for $days days. Keep it up!",
    };
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = _badges.fold<int>(
      0,
      (sum, b) => sum + b.badgeType.points,
    );
    // Short screens (or very large text) get a smaller trophy.
    final compact = MediaQuery.sizeOf(context).height < 700;
    final trophyBox = compact ? 72.0 : 104.0;

    return Dialog(
      key: const Key('badge_celebration_dialog'),
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: const Key('badge_celebration_body'),
              padding: EdgeInsets.fromLTRB(24, compact ? 20 : 28, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scale,
                    child: _Trophy(size: trophyBox),
                  ),
                  SizedBox(height: compact ? 10 : 16),
                  const Text(
                    'Congratulations!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSingle
                        ? 'New badge unlocked'
                        : 'You unlocked ${_badges.length} new badges',
                    key: const Key('badge_celebration_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isSingle) ...[
                    Text(
                      _badges.single.badgeType.label,
                      key: const Key('badge_celebration_label'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sageDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _milestoneText(_badges.single.badgeType),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ] else
                    for (final badge in _badges)
                      Padding(
                        key: Key(
                          'badge_celebration_item_${badge.badgeType.name}',
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.terracotta,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                badge.badgeType.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sageDark,
                                ),
                              ),
                            ),
                            Text(
                              '+${badge.badgeType.points}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('badge_celebration_points'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.terracottaLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+$totalPoints reward points',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.terracottaDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pinned: always visible however tall the content above is.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('badge_celebration_continue'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Keep going'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Trophy extends StatelessWidget {
  final double size;
  const _Trophy({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 28,
      height: size + 16,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sageLight, width: 6),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.terracotta,
              size: size * 0.52,
            ),
          ),
          const Positioned(
            top: 0,
            right: 4,
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.terracotta,
              size: 24,
            ),
          ),
          const Positioned(
            bottom: 6,
            left: 2,
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.sageDark,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

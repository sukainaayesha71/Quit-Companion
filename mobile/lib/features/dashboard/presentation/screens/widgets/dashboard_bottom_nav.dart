import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

class DashboardBottomNav extends StatelessWidget {
  final VoidCallback onHealthBotTap;
  final VoidCallback onCommunityTap;
  final VoidCallback onTrackTap;
  final VoidCallback onProfileTap;

  const DashboardBottomNav({
    super.key,
    required this.onHealthBotTap,
    required this.onCommunityTap,
    required this.onTrackTap,
    required this.onProfileTap,
  });

  static const _labels = [
    'Home',
    'Track',
    'Health-Bot',
    'Community',
    'Profile',
  ];
  static const _icons = [
    Icons.home_rounded,
    Icons.favorite_border_rounded,
    Icons.smart_toy_rounded,
    Icons.groups_rounded,
    Icons.person_outline_rounded,
  ];
  static const _keys = ['home', 'track', 'health_bot', 'community', 'profile'];
  static const _labelStyle = TextStyle(
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScaler = MediaQuery.textScalerOf(context);
            final cellWidth = constraints.maxWidth / _labels.length;
            var labelHeight = textScaler.scale(11) * 1.25;
            for (final label in _labels) {
              final painter = TextPainter(
                text: TextSpan(text: label, style: _labelStyle),
                textScaler: textScaler,
                textDirection: Directionality.of(context),
                maxLines: 2,
              )..layout(maxWidth: math.max(1, cellWidth - 4));
              labelHeight = math.max(labelHeight, painter.height);
              painter.dispose();
            }
            final callbacks = <VoidCallback?>[
              null,
              onTrackTap,
              onHealthBotTap,
              onCommunityTap,
              onProfileTap,
            ];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < _labels.length; index++)
                  Expanded(
                    child: InkWell(
                      key: Key('dashboard_bottom_nav_${_keys[index]}'),
                      onTap: callbacks[index],
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 48,
                            child: Center(
                              child: index == 2
                                  ? Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        color: AppColors.terracotta,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.smart_toy_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    )
                                  : Icon(
                                      _icons[index],
                                      color: AppColors.terracotta,
                                      size: 24,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: labelHeight,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                _labels[index],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _labelStyle.copyWith(
                                  color: index == 2
                                      ? AppColors.textPrimary
                                      : AppColors.terracotta,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

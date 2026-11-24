import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Animated count-up stat tile (Total Cravings / Cravings Resisted /
/// Longest Streak). Counts from 0 to [value] once on first build.
class TrackStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;
  final String Function(int)? formatter;
  final Key? valueKey;

  const TrackStatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.formatter,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            key: valueKey,
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, animatedValue, _) => Text(
              formatter != null ? formatter!(animatedValue) : '$animatedValue',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

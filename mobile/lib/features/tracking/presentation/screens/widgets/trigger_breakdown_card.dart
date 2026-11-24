import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Horizontal bar breakdown of craving trigger categories. Renamed from
/// the mockup's "Nicotine Product Breakdown" — the rows are trigger
/// categories, not products (see design spec §3). Each bar animates its
/// width in on first build, staggered by index via differing durations.
class TriggerBreakdownCard extends StatelessWidget {
  final Map<TriggerCategory, int> counts;

  const TriggerBreakdownCard({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values
        .fold(0, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 30);
    final entries = TriggerCategory.values
        .map((t) => MapEntry(t, counts[t] ?? 0))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trigger Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          for (final (i, entry) in entries.indexed) ...[
            _BreakdownRow(
              label: entry.key.label,
              fraction: entry.value / maxCount,
              delayMs: 500 + i * 120,
            ),
            if (entry.key != entries.last.key) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double fraction;
  final int delayMs;

  const _BreakdownRow({
    required this.label,
    required this.fraction,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 14,
              color: AppColors.border,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: Duration(milliseconds: delayMs),
                curve: Curves.easeOut,
                builder: (context, width, _) => FractionallySizedBox(
                  widthFactor: width.clamp(0, 1),
                  child: Container(color: AppColors.terracotta),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

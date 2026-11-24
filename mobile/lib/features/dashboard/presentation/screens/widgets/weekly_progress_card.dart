import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/weekly_trend_chart_painter.dart';

/// The two ranges the Dashboard progress chart can show (FR4 / UC6).
enum ProgressRange { week, month }

/// Dashboard progress card (docs/UI_Design/dashboard 5.png): a daily
/// craving-log trend chart plus a comparison badge against the previous
/// period of the same length.
///
/// FR4 / UC6 additions:
/// - a 7-day / 30-day toggle. Both series come from DashboardController
///   (same craving-log data and bucketing); the selected range is purely a
///   view choice, so it lives here rather than in the controller.
/// - a first-craving empty state: when [hasAnyCravingLogs] is false, an
///   all-zero chart would look like a perfect record rather than "no data
///   yet", so it is replaced by a prompt to log the first craving.
///
/// A null comparison percentage means there's no earlier data to compare
/// against, so the badge is omitted rather than showing a fabricated
/// percentage.
class WeeklyProgressCard extends StatefulWidget {
  final List<int> trend;
  final double? pctBetterThanLastWeek;
  final List<int>? monthlyTrend;
  final double? pctBetterThanLastMonth;
  final bool hasAnyCravingLogs;
  final VoidCallback? onLogFirstCraving;

  const WeeklyProgressCard({
    super.key,
    required this.trend,
    required this.pctBetterThanLastWeek,
    this.monthlyTrend,
    this.pctBetterThanLastMonth,
    this.hasAnyCravingLogs = true,
    this.onLogFirstCraving,
  }) : assert(trend.length == 7),
       assert(monthlyTrend == null || monthlyTrend.length == 30);

  @override
  State<WeeklyProgressCard> createState() => _WeeklyProgressCardState();
}

class _WeeklyProgressCardState extends State<WeeklyProgressCard> {
  ProgressRange _range = ProgressRange.week;

  bool get _canShowMonth => widget.monthlyTrend != null;

  @override
  Widget build(BuildContext context) {
    final isMonth = _range == ProgressRange.month && _canShowMonth;
    final values = isMonth ? widget.monthlyTrend! : widget.trend;
    final pct = isMonth
        ? widget.pctBetterThanLastMonth
        : widget.pctBetterThanLastWeek;
    final periodName = isMonth ? 'previous 30 days' : 'last week';

    return Container(
      key: const Key('dashboard_weekly_progress_card'),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isMonth ? 'Last 30 Days' : 'This Week',
                key: const Key('dashboard_progress_title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (widget.hasAnyCravingLogs && pct != null)
                Container(
                  key: const Key('dashboard_weekly_comparison_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pct >= 0
                        ? AppColors.sageLight
                        : AppColors.terracottaLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pct >= 0
                        ? '${pct.round()}% better than $periodName'
                        : '${pct.abs().round()}% more than $periodName',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: pct >= 0
                          ? AppColors.sageDark
                          : AppColors.terracottaDark,
                    ),
                  ),
                ),
            ],
          ),
          if (!widget.hasAnyCravingLogs) ...[
            const SizedBox(height: 16),
            _FirstCravingPrompt(onLogFirstCraving: widget.onLogFirstCraving),
          ] else ...[
            if (_canShowMonth) ...[
              const SizedBox(height: 12),
              _RangeToggle(
                selected: _range,
                onChanged: (range) => setState(() => _range = range),
              ),
            ],
            const SizedBox(height: 16),
            Semantics(
              label:
                  'Cravings logged per day, ${isMonth ? 'last 30 days' : 'last 7 days'}',
              child: SizedBox(
                key: const Key('dashboard_weekly_trend_chart'),
                height: 120,
                width: double.infinity,
                child: CustomPaint(painter: WeeklyTrendChartPainter(values)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cravings logged per day',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final ProgressRange selected;
  final ValueChanged<ProgressRange> onChanged;

  const _RangeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(ProgressRange range, String label, Key key) {
      final isSelected = selected == range;
      return ChoiceChip(
        key: key,
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) => onChanged(range),
        selectedColor: AppColors.sage,
        backgroundColor: AppColors.background,
        side: BorderSide(color: isSelected ? AppColors.sage : AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          ProgressRange.week,
          '7 days',
          const Key('dashboard_progress_range_week'),
        ),
        chip(
          ProgressRange.month,
          '30 days',
          const Key('dashboard_progress_range_month'),
        ),
      ],
    );
  }
}

class _FirstCravingPrompt extends StatelessWidget {
  final VoidCallback? onLogFirstCraving;

  const _FirstCravingPrompt({required this.onLogFirstCraving});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard_first_craving_prompt'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.insights_rounded, color: AppColors.sageDark, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Log your first craving',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Next time you feel a craving, log it here. Your progress chart '
            'and relapse-risk insights build from what you record, so even '
            'small cravings help.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
          if (onLogFirstCraving != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('dashboard_first_craving_button'),
              onPressed: onLogFirstCraving,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Log a craving'),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_scaffold.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

class _GoalOption {
  final QuitStrategy strategy;
  final String label;
  final IconData icon;
  const _GoalOption(this.strategy, this.label, this.icon);
}

const _options = [
  _GoalOption(
    QuitStrategy.coldTurkey,
    'Quit Completely',
    Icons.shield_outlined,
  ),
  _GoalOption(QuitStrategy.gradual, 'Reduce Gradually', Icons.trending_down),
  _GoalOption(
    QuitStrategy.dateBased,
    'Quit by a Specific Date',
    Icons.event_outlined,
  ),
];

/// Step 3 of onboarding: docs/UI_Design 4a (right half) -- "What's your
/// goal?" with an inline date picker. The date section shows for BOTH
/// Reduce Gradually and Quit by a Specific Date (not just the latter):
/// QuitDateCalculator throws without a target date for GRADUAL too.
class GoalSelectionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const GoalSelectionScreen({
    super.key,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  QuitStrategy? _strategy;
  DateTime? _targetDate;
  late DateTime _visibleMonth;
  final _targetDateSectionKey = GlobalKey();

  // Mirrors the bounds the deleted quit_strategy_screen.dart enforced via
  // showDatePicker(firstDate: tomorrow, lastDate: +365 days): tomorrow
  // through +365 days. Date-only (no time-of-day) so day-level comparisons
  // against calendar cells are exact.
  final _firstSelectableDate = DateTime(
    DateTime.now().add(const Duration(days: 1)).year,
    DateTime.now().add(const Duration(days: 1)).month,
    DateTime.now().add(const Duration(days: 1)).day,
  );
  final _lastSelectableDate = DateTime(
    DateTime.now().add(const Duration(days: 365)).year,
    DateTime.now().add(const Duration(days: 365)).month,
    DateTime.now().add(const Duration(days: 365)).day,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  bool get _needsTargetDate =>
      _strategy != null && _strategy != QuitStrategy.coldTurkey;

  void _selectStrategy(QuitStrategy strategy) {
    setState(() => _strategy = strategy);
    if (strategy == QuitStrategy.coldTurkey) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _targetDateSectionKey.currentContext;
      if (!mounted || targetContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.12,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OnboardingController>();

    return OnboardingScaffold(
      headerAsset: 'assets/images/onboarding/goal_selection_header.png',
      headerAspectRatio: 318 / 345,
      step: 4,
      totalSteps: 5,
      onBack: widget.onBack,
      heading: "What's your goal?",
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in _options) ...[
            _GoalOptionRow(
              option: option,
              selected: _strategy == option.strategy,
              onTap: () => _selectStrategy(option.strategy),
            ),
            const SizedBox(height: 10),
          ],
          if (_needsTargetDate)
            Column(
              key: _targetDateSectionKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Choose your target quit date',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (_targetDate == null)
                  const Text(
                    'Select a future date below to enable plan generation.',
                    key: Key('goal_target_date_hint'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 10),
                _TargetDateSummary(date: _targetDate),
                const SizedBox(height: 12),
                _InlineCalendar(
                  visibleMonth: _visibleMonth,
                  selectedDate: _targetDate,
                  firstSelectableDate: _firstSelectableDate,
                  lastSelectableDate: _lastSelectableDate,
                  onMonthChanged: (m) => setState(() => _visibleMonth = m),
                  onDateSelected: (d) => setState(() => _targetDate = d),
                ),
              ],
            ),
          if (controller.status == OnboardingStatus.error &&
              controller.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              controller.errorMessage!,
              key: const Key('goal_error_text'),
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ],
        ],
      ),
      buttonLabel: 'Generate My Plan',
      buttonKey: const Key('goal_generate_plan_button'),
      onButtonPressed:
          (_strategy == null ||
              (_needsTargetDate && _targetDate == null) ||
              controller.status == OnboardingStatus.loading)
          ? null
          : () async {
              final success = await context
                  .read<OnboardingController>()
                  .submitQuitStrategy(
                    quitStrategy: _strategy!,
                    selectedTargetDate: _targetDate,
                  );
              if (success) widget.onComplete();
            },
    );
  }
}

class _GoalOptionRow extends StatelessWidget {
  final _GoalOption option;
  final bool selected;
  final VoidCallback onTap;

  const _GoalOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('goal_option_${option.strategy.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.terracotta : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              color: selected ? AppColors.terracotta : AppColors.sageDark,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetDateSummary extends StatelessWidget {
  final DateTime? date;
  const _TargetDateSummary({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: AppColors.sageDark,
            size: 18,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              date == null ? 'Pick a target date' : _formatDate(date!),
              key: const Key('goal_target_date_text'),
              style: TextStyle(
                color: date == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineCalendar extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime? selectedDate;
  final DateTime firstSelectableDate;
  final DateTime lastSelectableDate;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime) onDateSelected;

  const _InlineCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.firstSelectableDate,
    required this.lastSelectableDate,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  /// True if [month] (year+month only) has at least one day within
  /// [firstSelectableDate, lastSelectableDate] -- used to decide whether the
  /// prev/next month arrows should navigate there at all.
  bool _monthHasSelectableDay(DateTime month) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    return !monthEnd.isBefore(firstSelectableDate) &&
        !monthStart.isAfter(lastSelectableDate);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = firstOfMonth.weekday % 7;
    final prevMonth = DateTime(visibleMonth.year, visibleMonth.month - 1);
    final nextMonth = DateTime(visibleMonth.year, visibleMonth.month + 1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const Key('goal_calendar_prev_month'),
                icon: const Icon(Icons.chevron_left),
                onPressed: _monthHasSelectableDay(prevMonth)
                    ? () => onMonthChanged(prevMonth)
                    : null,
              ),
              Flexible(
                child: Text(
                  '${_monthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('goal_calendar_next_month'),
                icon: const Icon(Icons.chevron_right),
                onPressed: _monthHasSelectableDay(nextMonth)
                    ? () => onMonthChanged(nextMonth)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            mainAxisExtent: MediaQuery.textScalerOf(context).scale(16) + 24,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _DayCell(
                  date: DateTime(visibleMonth.year, visibleMonth.month, day),
                  isToday:
                      DateTime(visibleMonth.year, visibleMonth.month, day) ==
                      DateTime(today.year, today.month, today.day),
                  isSelected:
                      selectedDate != null &&
                      DateTime(visibleMonth.year, visibleMonth.month, day) ==
                          DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                          ),
                  enabled:
                      !DateTime(
                        visibleMonth.year,
                        visibleMonth.month,
                        day,
                      ).isBefore(firstSelectableDate) &&
                      !DateTime(
                        visibleMonth.year,
                        visibleMonth.month,
                        day,
                      ).isAfter(lastSelectableDate),
                  onTap: () => onDateSelected(
                    DateTime(visibleMonth.year, visibleMonth.month, day),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('goal_calendar_day_${date.year}_${date.month}_${date.day}'),
      onTap: enabled ? onTap : null,
      customBorder: const CircleBorder(),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.terracotta : Colors.transparent,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.sage, width: 1.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (enabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary.withValues(alpha: 0.4)),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

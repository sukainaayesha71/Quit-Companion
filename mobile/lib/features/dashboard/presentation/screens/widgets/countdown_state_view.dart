import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_stat_card.dart';

/// SDD §7.2 CountdownState display, plus §7.5's usage-logging entry point
/// (GRADUAL only — the reduction fields are null for COLD_TURKEY/DATE_BASED,
/// see CountdownState.isGradual).
class CountdownStateView extends StatefulWidget {
  final CountdownState state;
  final DashboardController controller;

  const CountdownStateView({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  State<CountdownStateView> createState() => _CountdownStateViewState();
}

class _CountdownStateViewState extends State<CountdownStateView> {
  final _usageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _usageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardStatCard(
          key: const Key('dashboard_days_until_quit'),
          icon: Icons.flag_outlined,
          title: 'Quit Day',
          value:
              '${state.daysUntilQuit} day${state.daysUntilQuit == 1 ? '' : 's'} to go',
        ),
        if (state.isGradual) ...[
          const SizedBox(height: 16),
          DashboardStatCard(
            key: const Key('dashboard_today_target'),
            icon: Icons.track_changes_outlined,
            title: "Today's Target",
            value: state.todayTarget != null
                ? state.todayTarget!.toStringAsFixed(1)
                : '—',
          ),
          const SizedBox(height: 16),
          DashboardStatCard(
            key: const Key('dashboard_reduction_streak'),
            icon: Icons.local_fire_department_outlined,
            title: 'Reduction Streak',
            value:
                '${state.reductionStreak} day${state.reductionStreak == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 16),
          DashboardStatCard(
            key: const Key('dashboard_money_saved_so_far'),
            icon: Icons.savings_outlined,
            title: 'Money Saved So Far',
            value: state.moneySavedSoFar!.toStringAsFixed(2),
          ),
          const SizedBox(height: 28),
          Text("Log Today's Usage", style: textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            key: const Key('dashboard_usage_field'),
            controller: _usageController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'e.g. 5'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('dashboard_log_usage_button'),
            onPressed: _submitting
                ? null
                : () async {
                    final value = double.tryParse(_usageController.text);
                    if (value == null) return;
                    setState(() => _submitting = true);
                    await widget.controller.logUsage(value);
                    if (mounted) setState(() => _submitting = false);
                  },
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Log Usage'),
          ),
        ],
      ],
    );
  }
}

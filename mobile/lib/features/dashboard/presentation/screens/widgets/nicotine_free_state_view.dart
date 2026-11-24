import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/dashboard_stats_row.dart';
import 'package:quit_companion/features/dashboard/presentation/screens/widgets/nicotine_free_hero_card.dart';

/// SDD §7.2 NicotineFreeState display, redesigned to match
/// docs/UI_Design/dashboard 5.png. Only the hero card + stats row live here
/// now — MilestoneProgressCard and HealthRecoveryCard moved up into
/// DashboardScreen so they can be reordered after the "This Week" chart,
/// matching the reference's bottom-of-scroll placement. All values are read
/// straight off [state] — none of DashboardController/DashboardStateCalculator
/// changed.
class NicotineFreeStateView extends StatelessWidget {
  final NicotineFreeState state;

  const NicotineFreeStateView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final sinceDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: state.nicotineFreeDays));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NicotineFreeHeroCard(
          nicotineFreeDays: state.nicotineFreeDays,
          sinceDate: sinceDate,
        ),
        const SizedBox(height: 16),
        DashboardStatsRow(
          moneySaved: state.moneySaved,
          cravingsResisted: state.cravingsResisted,
        ),
      ],
    );
  }
}

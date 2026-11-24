import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Formats a whole-currency amount with thousands separators (no decimal
/// package dependency in this project) e.g. 4200 -> "4,200".
String formatMoney(double amount) {
  final rounded = amount.round().abs();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer';
}

/// Money Saved / Cravings Resisted pair (docs/UI_Design/dashboard 5.png).
/// Values come straight from NicotineFreeState — nothing invented here.
class DashboardStatsRow extends StatelessWidget {
  final double moneySaved;
  final int cravingsResisted;

  const DashboardStatsRow({
    super.key,
    required this.moneySaved,
    required this.cravingsResisted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            key: const Key('dashboard_money_saved'),
            icon: Icons.savings_rounded,
            iconBackground: AppColors.terracottaLight,
            iconColor: AppColors.terracottaDark,
            value: 'Rs. ${formatMoney(moneySaved)}',
            label: 'Money Saved',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatChip(
            key: const Key('dashboard_cravings_resisted'),
            icon: Icons.shield_rounded,
            iconBackground: AppColors.sageLight,
            iconColor: AppColors.sageDark,
            value: '$cravingsResisted',
            label: 'Cravings Resisted',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String value;
  final String label;

  const _StatChip({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// Greeting header (docs/UI_Design/dashboard 5.png shows "Hi, [name] 👋").
/// [name] is NicotineUser.name (the Register screen's "Full Name" field,
/// persisted at registration) — falls back to the generic greeting when
/// null/empty (e.g. Google sign-in, which doesn't capture a name here).
/// The bell opens Module 11's Reminders settings (FR14) — it was
/// originally built as a non-functional visual placeholder in Module 2,
/// specifically anticipating a future notifications feature; this wires
/// it up rather than adding a new entry point elsewhere.
class DashboardHeader extends StatelessWidget {
  final String? name;
  final VoidCallback? onNotificationsTap;

  const DashboardHeader({super.key, this.name, this.onNotificationsTap});

  String get _greeting {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Hi there 👋';
    final firstName = trimmed.split(RegExp(r'\s+')).first;
    return 'Hi $firstName!';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _greeting,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        InkWell(
          key: const Key('dashboard_notifications_button'),
          onTap: onNotificationsTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
              Positioned(
                key: const Key('dashboard_notifications_dot'),
                top: 2,
                right: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.terracotta,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/shared/widgets/action_progress.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/core/theme/app_theme.dart';

/// FR14 (Module 11 — Notification & Reminder). No approved mockup exists
/// for this screen — neither the SDD nor the UI_Design reference set
/// shows a reminder-settings UI — same "no mockup, build plain"
/// precedent as every prior module's unreferenced settings/detail
/// screen. Reached from the Dashboard's bell icon (see
/// dashboard_header.dart), which was a non-functional placeholder built
/// in Module 2 specifically for a future notifications feature.
class ReminderSettingsScreen extends StatefulWidget {
  final ReminderController controller;

  const ReminderSettingsScreen({super.key, required this.controller});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    Future.microtask(() => widget.controller.loadSettings());
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AbsorbPointer(
            absorbing: controller.isUpdating,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.isUpdating) ...[
                    const ActionProgress('Saving…'),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily reminders',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Get daily check-ins on this phone, even when you're offline.",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: const Key('reminder_enabled_switch'),
                          value: settings.enabled,
                          onChanged: (value) => controller.setEnabled(value),
                        ),
                      ],
                    ),
                  ),
                  if (settings.enabled) ...[
                    const SizedBox(height: 12),
                    _DeliveryModeNote(mode: controller.deliveryMode),
                    const SizedBox(height: 20),
                    const Text(
                      'How many times a day?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      key: const Key('reminder_frequency_selector'),
                      children: [
                        for (final count in [3, 4, 5]) ...[
                          ChoiceChip(
                            key: Key('reminder_frequency_$count'),
                            label: Text('$count'),
                            selected: settings.dailyFrequency == count,
                            onSelected: (_) =>
                                controller.setDailyFrequency(count),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      key: const Key('habit_reminder_switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Habit reminders'),
                      subtitle: const Text(
                        'A daily nudge to try a healthy craving alternative.',
                      ),
                      value: settings.habitRemindersEnabled,
                      onChanged: controller.setHabitRemindersEnabled,
                    ),
                    SwitchListTile(
                      key: const Key('recovery_motivation_switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Recovery motivation'),
                      subtitle: const Text(
                        'A daily reminder to recognize your progress.',
                      ),
                      value: settings.recoveryMotivationEnabled,
                      onChanged: controller.setRecoveryMotivationEnabled,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SwitchListTile(
                    key: const Key('remote_delivery_switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Push notifications'),
                    subtitle: const Text(
                      'Reminders, milestones and recovery updates arrive as '
                      "push notifications. If push isn't available, "
                      'reminders come from your device instead.',
                    ),
                    value: settings.remoteDelivery,
                    onChanged: controller.setRemoteDelivery,
                  ),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      controller.errorMessage!,
                      key: const Key('reminder_error_text'),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 12: tells the user how daily check-ins are being delivered.
class _DeliveryModeNote extends StatelessWidget {
  final ReminderDeliveryMode mode;

  const _DeliveryModeNote({required this.mode});

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (mode) {
      ReminderDeliveryMode.push => (
        Icons.cloud_done_outlined,
        'Delivered as push notifications.',
      ),
      ReminderDeliveryMode.localFallback => (
        Icons.phone_android_rounded,
        "Push isn't available right now, so reminders come from your device.",
      ),
      ReminderDeliveryMode.local => (
        Icons.phone_android_rounded,
        'Delivered by your device (push is off).',
      ),
      ReminderDeliveryMode.off => (Icons.notifications_off_outlined, ''),
    };
    if (mode == ReminderDeliveryMode.off) return const SizedBox.shrink();
    return Row(
      key: Key('reminder_delivery_${mode.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

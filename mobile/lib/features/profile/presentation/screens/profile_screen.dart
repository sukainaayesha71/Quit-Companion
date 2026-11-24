import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';
import 'package:quit_companion/features/goals/controllers/ai_plan_controller.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/rewards/controllers/gamification_controller.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/auth/data/account_deletion_repository.dart';
import 'package:quit_companion/features/auth/data/biometric_lock_service.dart';
import 'package:quit_companion/features/reminders/controllers/reminder_controller.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/shared/widgets/staggered_entrance.dart';
import 'package:quit_companion/features/goals/presentation/screens/weekly_plan_screen.dart';
import 'package:quit_companion/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:quit_companion/features/reminders/presentation/screens/reminder_settings_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/about_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/help_support_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/privacy_security_screen.dart';
import 'package:quit_companion/features/profile/presentation/screens/widgets/profile_avatar.dart';
import 'package:quit_companion/features/profile/presentation/screens/widgets/profile_header_background.dart';
import 'package:quit_companion/features/rewards/models/badge.dart';

/// FR-Profile (Module 11/Track & Profile nav): Profile tab landing screen —
/// header (avatar/name/edit), stat chips, and the settings-row list linking
/// out to every account-level destination. Mirrors DashboardScreen's
/// controller-injection style: this screen doesn't own AiPlanController,
/// ReminderController, or GamificationController itself (those live with
/// Modules 4/11/8 respectively) — it only forwards the same shared
/// instances DashboardScreen already receives, so WeeklyPlanScreen/
/// ReminderSettingsScreen/RewardsScreen reached from Profile show the same
/// live state as when reached from Dashboard's Quick Access grid.
class ProfileScreen extends StatefulWidget {
  final String userId;
  final DashboardController dashboardController;
  final ProfileController profileController;
  final AiPlanController aiPlanController;
  final ReminderController reminderController;
  final GamificationController gamificationController;
  final VoidCallback onLogout;
  final Future<void> Function()? onAccountDeleted;
  final BiometricLockService biometricLockService;
  final AccountDeletionRepository accountDeletionRepository;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.dashboardController,
    required this.profileController,
    required this.aiPlanController,
    required this.reminderController,
    required this.gamificationController,
    required this.onLogout,
    this.onAccountDeleted,
    this.biometricLockService = const UnavailableBiometricLockService(),
    this.accountDeletionRepository =
        const UnconfiguredAccountDeletionRepository(),
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _openEditProfile() async {
    final user = widget.dashboardController.user;
    if (user == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          userId: widget.userId,
          dashboardController: widget.dashboardController,
          profileController: widget.profileController,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.dashboardController.user;
    final state = widget.dashboardController.state;
    final settingsRows = _settingsRows(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredEntrance(
                index: 0,
                parent: _entranceController,
                child: _ProfileHeader(
                  name: user?.name ?? 'there',
                  gender: user?.gender,
                  onEditTap: _openEditProfile,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaggeredEntrance(
                      index: 1,
                      parent: _entranceController,
                      child: _StatChipsRow(
                        quitDate: user?.quitDate,
                        productType: user?.productType,
                        thirdChip: state is NicotineFreeState
                            ? _StatChipData(
                                icon: Icons.local_fire_department_rounded,
                                label: 'Days Nicotine-Free',
                                value: '${state.nicotineFreeDays}',
                              )
                            : state is CountdownState
                            ? _StatChipData(
                                icon: Icons.hourglass_bottom_rounded,
                                label: 'Days Until Quit',
                                value: '${state.daysUntilQuit}',
                              )
                            : const _StatChipData(
                                icon: Icons.local_fire_department_rounded,
                                label: 'Days Nicotine-Free',
                                value: '-',
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: widget.gamificationController,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.gamificationController.totalPoints} reward points',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final badge
                                  in widget.gamificationController.earnedBadges)
                                Chip(
                                  label: Text(badge.badgeType.label),
                                  avatar: const Icon(
                                    Icons.emoji_events_outlined,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final (i, row) in settingsRows.indexed)
                      StaggeredEntrance(
                        index: 2 + i,
                        parent: _entranceController,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: row,
                        ),
                      ),
                    const SizedBox(height: 12),
                    StaggeredEntrance(
                      index: 2 + settingsRows.length,
                      parent: _entranceController,
                      child: Center(
                        child: TextButton.icon(
                          key: const Key('profile_log_out_button'),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                            widget.onLogout();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.terracotta,
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Log Out'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _settingsRows(BuildContext context) {
    final user = widget.dashboardController.user;
    return [
      _SettingsRow(
        key: const Key('profile_row_edit_profile'),
        icon: Icons.person_outline_rounded,
        label: 'Edit Profile',
        onTap: user == null ? null : _openEditProfile,
      ),
      _SettingsRow(
        key: const Key('profile_row_my_quit_plan'),
        icon: Icons.assignment_outlined,
        label: 'My Quit Plan',
        onTap: user == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WeeklyPlanScreen(
                    userId: widget.userId,
                    controller: widget.aiPlanController,
                  ),
                ),
              ),
      ),
      _SettingsRow(
        key: const Key('profile_row_notifications'),
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ReminderSettingsScreen(controller: widget.reminderController),
          ),
        ),
      ),
      _SettingsRow(
        key: const Key('profile_row_privacy_security'),
        icon: Icons.lock_outline_rounded,
        label: 'Privacy & Security',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrivacySecurityScreen(
              userId: widget.userId,
              biometricLockService: widget.biometricLockService,
              accountDeletionRepository: widget.accountDeletionRepository,
              onAccountDeleted: widget.onAccountDeleted,
            ),
          ),
        ),
      ),
      _SettingsRow(
        key: const Key('profile_row_achievements'),
        icon: Icons.emoji_events_outlined,
        label: 'Achievements',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RewardsScreen(
              userId: widget.userId,
              controller: widget.gamificationController,
            ),
          ),
        ),
      ),
      // SRDS 4.2 Mental Health Safeguards.
      _SettingsRow(
        key: const Key('profile_row_crisis_support'),
        icon: Icons.support_agent_rounded,
        label: 'Crisis Support',
        onTap: () => Navigator.of(context).push(CrisisSupportScreen.route()),
      ),
      _SettingsRow(
        key: const Key('profile_row_help_support'),
        icon: Icons.help_outline_rounded,
        label: 'Help & Support',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
      ),
      _SettingsRow(
        key: const Key('profile_row_about'),
        icon: Icons.info_outline_rounded,
        label: 'About Quit Companion',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
      ),
    ];
  }
}

class _StatChipData {
  final IconData icon;
  final String label;
  final String value;
  const _StatChipData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _StatChipsRow extends StatelessWidget {
  final DateTime? quitDate;
  final ProductType? productType;
  final _StatChipData thirdChip;

  const _StatChipsRow({
    required this.quitDate,
    required this.productType,
    required this.thirdChip,
  });

  static const _productLabels = {
    ProductType.vape: 'Vape',
    ProductType.cigarettes: 'Cigarettes',
    ProductType.pouches: 'Pouches',
    ProductType.hookah: 'Hookah',
  };

  String _formatDate(DateTime? date) =>
      date == null ? '-' : '${date.month}/${date.day}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final chips = [
      _StatChipData(
        icon: Icons.calendar_today_outlined,
        label: 'Quit Date',
        value: _formatDate(quitDate),
      ),
      _StatChipData(
        icon: Icons.smoking_rooms_outlined,
        label: 'Product Type',
        value: productType == null ? '-' : _productLabels[productType]!,
      ),
      thirdChip,
    ];
    return Row(
      children: [
        for (final chip in chips) ...[
          Expanded(child: _StatChip(data: chip)),
          if (chip != chips.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final _StatChipData data;
  const _StatChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(data.icon, color: AppColors.sageDark, size: 20),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.sageDark, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final Gender? gender;
  final VoidCallback onEditTap;
  final VoidCallback onBack;

  const _ProfileHeader({
    required this.name,
    required this.gender,
    required this.onEditTap,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
      child: SizedBox(
        height: 210 + (MediaQuery.textScalerOf(context).scale(22) - 22) * 3,
        child: Stack(
          children: [
            const Positioned.fill(child: ProfileHeaderBackground()),
            Positioned(
              top: 12,
              left: 8,
              child: IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: TextButton.icon(
                key: const Key('profile_edit_button'),
                onPressed: onEditTap,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Profile'),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  ProfileAvatar(gender: gender, size: 84),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/shared/widgets/action_progress.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/profile/presentation/screens/widgets/profile_avatar.dart';

const _productLabels = {
  ProductType.vape: 'Vape',
  ProductType.cigarettes: 'Cigarettes',
  ProductType.pouches: 'Pouches',
  ProductType.hookah: 'Hookah',
};

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final DashboardController dashboardController;
  final ProfileController profileController;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.dashboardController,
    required this.profileController,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usageController;
  late final TextEditingController _costController;
  late final TextEditingController _motivationController;
  late final TextEditingController _challengesController;
  late final TextEditingController _pastAttemptsController;
  late final TextEditingController _historyController;
  ProductType? _productType;
  Gender? _gender;
  String? _validationMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.dashboardController.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _usageController = TextEditingController(
      text: user?.baselineDailyUsage?.toString() ?? '',
    );
    _costController = TextEditingController(
      text: user?.costPerUnit?.toString() ?? '',
    );
    _motivationController = TextEditingController(
      text: user?.primaryMotivation ?? '',
    );
    _challengesController = TextEditingController(
      text: user?.personalChallenges ?? '',
    );
    _pastAttemptsController = TextEditingController(
      text: user?.pastQuitAttempts ?? '',
    );
    _productType = user?.productType;
    _historyController = TextEditingController(
      text: user?.nicotineHistory ?? '',
    );
    _gender = user?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usageController.dispose();
    _costController.dispose();
    _motivationController.dispose();
    _challengesController.dispose();
    _pastAttemptsController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  void _selectGender(Gender gender) {
    setState(() {
      _gender = gender;
      _validationMessage = null;
    });
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    final user = widget.dashboardController.user;
    if (user == null) return;
    final usageText = _usageController.text.trim();
    final costText = _costController.text.trim();
    final usage = usageText.isEmpty ? null : double.tryParse(usageText);
    final cost = costText.isEmpty ? null : double.tryParse(costText);
    if ((usageText.isNotEmpty && usage == null) ||
        (costText.isNotEmpty && cost == null)) {
      setState(
        () => _validationMessage =
            'Enter a valid number for daily consumption and cost.',
      );
      return;
    }

    setState(() {
      _validationMessage = null;
      _saving = true;
    });
    final success = await widget.profileController.updateProfile(
      user: user,
      name: _nameController.text,
      gender: _gender,
      productType: _productType,
      baselineDailyUsage: usage,
      costPerUnit: cost,
      primaryMotivation: _motivationController.text,
      personalChallenges: _challengesController.text,
      pastQuitAttempts: _pastAttemptsController.text,
      nicotineHistory: _historyController.text,
    );
    if (!mounted) return;
    if (success) {
      await widget.dashboardController.loadDashboard(widget.userId);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );
    } else {
      setState(() {
        _saving = false;
        _validationMessage = widget.profileController.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.dashboardController.user;
    final saving = _saving;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          key: const Key('edit_profile_avatar_female'),
                          onTap: saving
                              ? null
                              : () => _selectGender(Gender.female),
                          borderRadius: BorderRadius.circular(48),
                          child: Opacity(
                            opacity: _gender == Gender.male ? 0.4 : 1,
                            child: const ProfileAvatar(
                              gender: Gender.female,
                              size: 72,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          key: const Key('edit_profile_avatar_male'),
                          onTap: saving
                              ? null
                              : () => _selectGender(Gender.male),
                          borderRadius: BorderRadius.circular(48),
                          child: Opacity(
                            opacity: _gender == Gender.male ? 1 : 0.4,
                            child: const ProfileAvatar(
                              gender: Gender.male,
                              size: 72,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change your avatar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Basic information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('profile_name_field'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Email', value: user?.email ?? '-'),
              const SizedBox(height: 12),
              const Text(
                'Nicotine use',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductType>(
                isExpanded: true,
                key: const Key('profile_product_type_field'),
                initialValue: _productType,
                decoration: const InputDecoration(
                  labelText: 'Nicotine product',
                ),
                items: ProductType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_productLabels[type]!),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) => setState(() => _productType = value),
              ),
              const SizedBox(height: 12),
              const Text(
                'Quit journey',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('profile_daily_usage_field'),
                controller: _usageController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Daily use (units per day / sessions per week)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('profile_cost_per_unit_field'),
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cost per unit (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('profile_primary_motivation_field'),
                controller: _motivationController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What motivates you to quit? (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('profile_personal_challenges_field'),
                controller: _challengesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What challenges do you expect? (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('profile_past_quit_attempts_field'),
                controller: _pastAttemptsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Have you tried quitting before? (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('profile_nicotine_history_field'),
                controller: _historyController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Smoking / vaping history (optional)',
                ),
              ),
              if (user?.quitDate != null)
                _InfoRow(
                  label: 'Quit Date',
                  value:
                      '${user!.quitDate!.month}/${user.quitDate!.day}/${user.quitDate!.year}',
                ),
              if (user != null)
                SwitchListTile(
                  title: const Text('Contribute check-ins to model research'),
                  subtitle: const Text(
                    'Optional. You can withdraw permission for future exports here.',
                  ),
                  value: user.researchConsent,
                  onChanged: (value) async {
                    final saved = await widget.profileController
                        .setResearchConsent(user, value);
                    if (saved) {
                      await widget.dashboardController.loadDashboard(
                        widget.userId,
                      );
                      if (mounted) setState(() {});
                    }
                  },
                ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationMessage!,
                  key: const Key('profile_edit_error_text'),
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('profile_save_button'),
                onPressed: saving ? null : _saveProfile,
                child: saving
                    ? const ActionProgress('Saving…')
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

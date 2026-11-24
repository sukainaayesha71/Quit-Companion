import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/relapse/controllers/relapse_controller.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/relapse/presentation/screens/restart_plan_screen.dart';

const _productLabels = {
  ProductType.vape: 'Vape',
  ProductType.cigarettes: 'Cigarettes',
  ProductType.pouches: 'Pouches',
  ProductType.hookah: 'Hookah',
};

// docs/UI_Design/relapse 11.png shows only 4 trigger chips — Stress, Social
// Pressure, Boredom, Other — a subset of Module 3's 5-value TriggerCategory
// (omitting After Meal). Reused rather than a new enum; this list controls
// which chips render, not the underlying model.
const _triggerOrder = [
  TriggerCategory.stress,
  TriggerCategory.socialPressure,
  TriggerCategory.boredom,
  TriggerCategory.other,
];

const _triggerLabels = {
  TriggerCategory.stress: 'Stress',
  TriggerCategory.socialPressure: 'Social Pressure',
  TriggerCategory.boredom: 'Boredom',
  TriggerCategory.other: 'Other',
};

const _triggerIcons = {
  TriggerCategory.stress: Icons.psychology_outlined,
  TriggerCategory.socialPressure: Icons.groups_outlined,
  TriggerCategory.boredom: Icons.sentiment_neutral_outlined,
  TriggerCategory.other: Icons.more_horiz,
};

const _moodLabels = {
  RelapseMood.guilty: 'Guilty',
  RelapseMood.frustrated: 'Frustrated',
  RelapseMood.sad: 'Sad',
  RelapseMood.numb: 'Numb',
};

const _moodIcons = {
  RelapseMood.guilty: Icons.sentiment_dissatisfied_outlined,
  RelapseMood.frustrated: Icons.sentiment_very_dissatisfied_outlined,
  RelapseMood.sad: Icons.mood_bad_outlined,
  RelapseMood.numb: Icons.sentiment_neutral_outlined,
};

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
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

/// FR12 (Module 5): "Let's Log This Moment" — matches the approved
/// reference, docs/UI_Design/relapse 11.png, exactly: date field, product
/// dropdown, trigger chips, mood chips, optional notes, submit. On a
/// successful submission, hands off to Module 4's already-built
/// RestartPlanScreen — completing that module's deliberately-left-open
/// dependency.
class RelapseLogScreen extends StatefulWidget {
  final String userId;
  final RelapseController controller;

  const RelapseLogScreen({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<RelapseLogScreen> createState() => _RelapseLogScreenState();
}

class _RelapseLogScreenState extends State<RelapseLogScreen> {
  DateTime _relapseDate = DateTime.now();
  ProductType? _product;
  TriggerCategory? _trigger;
  RelapseMood? _mood;
  final _notesController = TextEditingController();
  bool _showValidationError = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _relapseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _relapseDate = picked);
  }

  Future<void> _handleSubmit() async {
    if (_trigger == null || _mood == null) {
      setState(() => _showValidationError = true);
      return;
    }
    setState(() => _showValidationError = false);
    final success = await widget.controller.submitRelapse(
      userId: widget.userId,
      relapseDate: _relapseDate,
      productUsed: _product,
      triggerCategory: _trigger!,
      mood: _mood!,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (!mounted || !success) return;
    // Replacing the form disposes its context. Keep the Navigator itself
    // for the result screen's callback, which runs after that disposal.
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => RestartPlanScreen(
          plan: widget.controller.restartPlan!,
          onBackToDashboard: () {
            navigator.popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.status;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onClose: () => Navigator.of(context).maybePop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'When did this happen?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      key: const Key('relapse_date_field'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.sageDark,
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                _formatDate(_relapseDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'What did you use?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ProductType>(
                      key: const Key('relapse_product_dropdown'),
                      initialValue: _product,
                      isExpanded: true,
                      hint: const Text('Select'),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: ProductType.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(_productLabels[p]!),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _product = value),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Trigger',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _triggerOrder
                          .map(
                            (trigger) => _Chip(
                              chipKey: Key('relapse_trigger_${trigger.name}'),
                              label: _triggerLabels[trigger]!,
                              icon: _triggerIcons[trigger]!,
                              selected: _trigger == trigger,
                              onTap: () => setState(() => _trigger = trigger),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Mood',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: RelapseMood.values
                          .map(
                            (mood) => _Chip(
                              chipKey: Key('relapse_mood_${mood.name}'),
                              label: _moodLabels[mood]!,
                              icon: _moodIcons[mood]!,
                              selected: _mood == mood,
                              onTap: () => setState(() => _mood = mood),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('relapse_notes_field'),
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Want to share more? (optional)',
                      ),
                    ),
                    if (_showValidationError) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Please select a trigger and a mood.',
                        key: Key('relapse_validation_error'),
                        style: TextStyle(color: AppColors.error, fontSize: 14),
                      ),
                    ],
                    if (status == RelapseStatus.error &&
                        widget.controller.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.controller.errorMessage!,
                        key: const Key('relapse_error_text'),
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      key: const Key('relapse_submit_button'),
                      onPressed: status == RelapseStatus.submitting
                          ? null
                          : _handleSubmit,
                      child: status == RelapseStatus.submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit'),
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
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('relapse_back_button'),
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.sageLight,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Let's Log This Moment",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Key chipKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.chipKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: chipKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.terracotta : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.terracotta : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.sageDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

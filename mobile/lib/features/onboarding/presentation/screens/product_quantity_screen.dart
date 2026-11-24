import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/product_quantity_config.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_scaffold.dart';

/// Step 2 of onboarding, conditional on the Step 1 product: docs/UI_Design
/// 4a (cigarettes), 4b (vape), 4c (pouches), 4d (hookah) -- all one shared
/// template, driven by [productQuantityConfigs].
class ProductQuantityScreen extends StatefulWidget {
  final ProductType productType;
  final VoidCallback onBack;
  final void Function(double value, String unitLabel) onContinue;

  const ProductQuantityScreen({
    super.key,
    required this.productType,
    required this.onBack,
    required this.onContinue,
  });

  @override
  State<ProductQuantityScreen> createState() => _ProductQuantityScreenState();
}

class _ProductQuantityScreenState extends State<ProductQuantityScreen> {
  late final ProductQuantityConfig _config;
  late double _value;
  int _unitModeIndex = 0;
  final _motivationController = TextEditingController();
  final _challengesController = TextEditingController();
  final _pastAttemptsController = TextEditingController();
  final _historyController = TextEditingController();
  final _costController = TextEditingController();
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _config = productQuantityConfigs[widget.productType]!;
    _value = _config.defaultValue;
  }

  SecondaryUnitOption? get _activeUnitMode =>
      _config.unitModes == null ? null : _config.unitModes![_unitModeIndex];

  double get _min => _config.min;
  double get _max => _activeUnitMode?.max ?? _config.max;
  String get _unitLabel => _activeUnitMode?.unitLabel ?? _config.unitLabel;

  void _setValue(double v) => setState(() => _value = v.clamp(_min, _max));

  @override
  void dispose() {
    _motivationController.dispose();
    _challengesController.dispose();
    _pastAttemptsController.dispose();
    _historyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _continue() {
    final text = _costController.text.trim();
    final cost = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (cost == null || !cost.isFinite || cost < 0)) {
      setState(
        () => _validationMessage = 'Enter a valid, non-negative cost per unit.',
      );
      return;
    }
    final controller = Provider.of<OnboardingController?>(
      context,
      listen: false,
    );
    controller?.recordProfile(
      productType: widget.productType,
      baselineDailyUsage: _value,
      primaryMotivation: _motivationController.text,
      personalChallenges: _challengesController.text,
      pastQuitAttempts: _pastAttemptsController.text,
      nicotineHistory: _historyController.text,
      costPerUnit: cost,
    );
    widget.onContinue(_value, _unitLabel);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      headerAsset: _config.headerAsset,
      headerAspectRatio: _config.headerAspectRatio,
      step: 3,
      totalSteps: 5,
      onBack: widget.onBack,
      heading: _config.question,
      content: Column(
        children: [
          if (_config.unitModes != null) ...[
            _UnitModeToggle(
              options: _config.unitModes!,
              selectedIndex: _unitModeIndex,
              onChanged: (i) => setState(() {
                _unitModeIndex = i;
                _value = _value.clamp(_min, _max);
              }),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CounterButton(
                icon: Icons.remove,
                onTap: () => _setValue(_value - 1),
                buttonKey: const Key('quantity_decrement_button'),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  _value.round().toString(),
                  key: const Key('quantity_value_text'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.terracotta,
                  ),
                ),
              ),
              _CounterButton(
                icon: Icons.add,
                onTap: () => _setValue(_value + 1),
                buttonKey: const Key('quantity_increment_button'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _unitLabel,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Slider(
            key: const Key('quantity_slider'),
            value: _value,
            min: _min,
            max: _max,
            activeColor: AppColors.terracotta,
            inactiveColor: AppColors.border,
            onChanged: _setValue,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: const Text(
                    '0',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                Flexible(
                  child: Text(
                    '${_max.round()}+',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This helps us personalize your plan.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Your quit journey (optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_nicotine_history_field'),
            controller: _historyController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'How long have you smoked / vaped?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_cost_per_unit_field'),
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cost per unit (for savings estimates)',
            ),
          ),
          if (_validationMessage != null)
            Text(
              _validationMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_primary_motivation_field'),
            controller: _motivationController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What motivates you to quit?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_personal_challenges_field'),
            controller: _challengesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What challenges do you expect?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('onboarding_past_quit_attempts_field'),
            controller: _pastAttemptsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Have you tried quitting before?',
            ),
          ),
        ],
      ),
      buttonLabel: 'Continue',
      buttonKey: const Key('quantity_continue_button'),
      onButtonPressed: _continue,
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Key buttonKey;
  const _CounterButton({
    required this.icon,
    required this.onTap,
    required this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.sageDark),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppColors.sage, width: 1.5),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _UnitModeToggle extends StatelessWidget {
  final List<SecondaryUnitOption> options;
  final int selectedIndex;
  final void Function(int) onChanged;

  const _UnitModeToggle({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sage),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            key: Key('quantity_unit_mode_$i'),
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.terracotta : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Text(
                options[i].label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

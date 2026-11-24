import 'package:quit_companion/shared/widgets/responsive_grid.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/core/theme/app_theme.dart';
import 'package:quit_companion/features/onboarding/presentation/screens/widgets/onboarding_scaffold.dart';

class _ProductOption {
  final ProductType type;
  final String label;
  final String iconAsset;
  const _ProductOption(this.type, this.label, this.iconAsset);
}

const _options = [
  _ProductOption(
    ProductType.vape,
    'Vape',
    'assets/images/onboarding/icons/product_icon_vape.png',
  ),
  _ProductOption(
    ProductType.cigarettes,
    'Cigarettes',
    'assets/images/onboarding/icons/product_icon_cigarettes.png',
  ),
  _ProductOption(
    ProductType.pouches,
    'Pouches',
    'assets/images/onboarding/icons/product_icon_pouches.png',
  ),
  _ProductOption(
    ProductType.hookah,
    'Hookah',
    'assets/images/onboarding/icons/product_icon_hookah.png',
  ),
];

/// Step 1 of onboarding: docs/UI_Design "user on boarding 4.png" --
/// "What do you use?" 2x2 product grid.
class ProductSelectionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(ProductType) onContinue;
  final ProductType? initialSelection;

  const ProductSelectionScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    this.initialSelection,
  });

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  ProductType? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      headerAsset: 'assets/images/onboarding/product_selection_header.png',
      headerAspectRatio: 630 / 367,
      step: 2,
      totalSteps: 5,
      onBack: widget.onBack,
      heading: 'What do you use?',
      content: ResponsiveGrid(
        maxColumns: 2,
        minItemWidth: 120,
        fixedExtent: 106,
        fontSize: 16,
        textLines: 2,
        spacing: 16,
        itemCount: _options.length,
        itemBuilder: (context, index) {
          final option = _options[index];
          return _ProductCard(
            option: option,
            selected: _selected == option.type,
            onTap: () => setState(() => _selected = option.type),
          );
        },
      ),
      buttonLabel: 'Continue',
      buttonKey: const Key('product_selection_continue_button'),
      onButtonPressed: _selected == null
          ? null
          : () => widget.onContinue(_selected!),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _ProductOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ProductCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('product_option_${option.type.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.terracottaLight : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.terracotta : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    option.iconAsset,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    option.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            if (selected)
              const Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.terracotta,
                  child: Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

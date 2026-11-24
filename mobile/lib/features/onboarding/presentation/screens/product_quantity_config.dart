import 'package:quit_companion/features/onboarding/models/product_type.dart';

class SecondaryUnitOption {
  final String label;
  final String unitLabel;
  final double max;
  const SecondaryUnitOption({
    required this.label,
    required this.unitLabel,
    required this.max,
  });
}

class ProductQuantityConfig {
  final String question;
  final String headerAsset;
  final double headerAspectRatio;
  final String unitLabel;
  final double min;
  final double max;
  final double defaultValue;
  final List<SecondaryUnitOption>? unitModes; // non-null only for vape

  const ProductQuantityConfig({
    required this.question,
    required this.headerAsset,
    required this.headerAspectRatio,
    required this.unitLabel,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.unitModes,
  });
}

const productQuantityConfigs = <ProductType, ProductQuantityConfig>{
  ProductType.cigarettes: ProductQuantityConfig(
    question: 'How many cigarettes do you use in a day?',
    headerAsset: 'assets/images/onboarding/cigarette_quantity_header.png',
    headerAspectRatio: 318 / 313,
    unitLabel: 'cigarettes',
    min: 1,
    max: 40,
    defaultValue: 10,
  ),
  ProductType.vape: ProductQuantityConfig(
    question: 'How many puffs or ml do you use in a day?',
    headerAsset: 'assets/images/onboarding/vape_quantity_header.png',
    headerAspectRatio: 575 / 360,
    unitLabel: 'puffs',
    min: 1,
    max: 400,
    defaultValue: 150,
    unitModes: [
      SecondaryUnitOption(label: 'Puffs', unitLabel: 'puffs', max: 400),
      SecondaryUnitOption(label: 'ml of E-liquid', unitLabel: 'ml', max: 10),
    ],
  ),
  ProductType.pouches: ProductQuantityConfig(
    question: 'How many pouches do you use in a day?',
    headerAsset: 'assets/images/onboarding/pouches_quantity_header.png',
    headerAspectRatio: 623 / 352,
    unitLabel: 'pouches',
    min: 1,
    max: 20,
    defaultValue: 6,
  ),
  ProductType.hookah: ProductQuantityConfig(
    question: 'How many sessions do you have in a week?',
    headerAsset: 'assets/images/onboarding/hookah_quantity_header.png',
    headerAspectRatio: 641 / 423,
    unitLabel: 'sessions per week',
    min: 1,
    max: 12,
    defaultValue: 4,
  ),
};

import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';

void main() {
  test('ProductType includes hookah alongside vape, cigarettes, pouches', () {
    expect(
      ProductType.values,
      containsAll([
        ProductType.vape,
        ProductType.cigarettes,
        ProductType.pouches,
        ProductType.hookah,
      ]),
    );
  });
}

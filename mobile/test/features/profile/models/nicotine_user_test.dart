import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';

void main() {
  test('NicotineUser starts with no consent and no strategy by default', () {
    const user = NicotineUser(userId: 'u1', email: 'a@b.com');

    expect(user.hasConsented, isFalse);
    expect(user.quitStrategy, isNull);
    expect(user.quitDate, isNull);
  });

  test('copyWith only overrides the given fields', () {
    const user = NicotineUser(userId: 'u1', email: 'a@b.com');

    final withProfile = user.copyWith(
      productType: ProductType.cigarettes,
      baselineDailyUsage: 10,
      costPerUnit: 25,
    );

    expect(withProfile.userId, 'u1');
    expect(withProfile.email, 'a@b.com');
    expect(withProfile.productType, ProductType.cigarettes);
    expect(withProfile.baselineDailyUsage, 10);
    expect(withProfile.costPerUnit, 25);
    expect(withProfile.hasConsented, isFalse);

    final withConsent = withProfile.copyWith(hasConsented: true);
    expect(withConsent.hasConsented, isTrue);
    expect(
      withConsent.productType,
      ProductType.cigarettes,
    ); // unrelated fields preserved

    final withStrategy = withConsent.copyWith(
      quitStrategy: QuitStrategy.gradual,
      quitDate: DateTime(2026, 9, 1),
      reductionSchedule: {DateTime(2026, 8, 20): 5.0},
    );
    expect(withStrategy.quitStrategy, QuitStrategy.gradual);
    expect(withStrategy.quitDate, DateTime(2026, 9, 1));
    expect(withStrategy.reductionSchedule, {DateTime(2026, 8, 20): 5.0});
  });

  test('copyWith can override name and gender', () {
    const user = NicotineUser(userId: 'u1', email: 'a@b.com', name: 'Mehreen');

    final renamed = user.copyWith(name: 'Sukaina', gender: Gender.male);

    expect(renamed.name, 'Sukaina');
    expect(renamed.gender, Gender.male);
    expect(renamed.userId, 'u1'); // unrelated fields preserved
  });
}

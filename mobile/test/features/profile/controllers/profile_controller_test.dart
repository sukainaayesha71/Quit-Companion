import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';

void main() {
  for (final baseline in [10.0, 20.0, 30.0]) {
    test(
      'editing daily usage to $baseline preserves past targets and updates future ones',
      () async {
        final repository = FakeUserRepository();
        final start = DateTime(2026, 11, 17);
        final today = DateTime(2026, 11, 18);
        final quitDate = DateTime(2026, 11, 30);
        final original = QuitDateCalculator(now: () => start)
            .determineQuitDate(
              quitStrategy: QuitStrategy.gradual,
              baselineDailyUsage: 10,
              selectedTargetDate: quitDate,
            )
            .reductionSchedule!;
        final user = NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          name: 'Name',
          productType: ProductType.cigarettes,
          baselineDailyUsage: baseline == 20 ? 20 : 10,
          quitStrategy: QuitStrategy.gradual,
          quitDate: quitDate,
          reductionSchedule: original,
          weeklyGoals: const ['Old goal'],
        );
        final controller = ProfileController(repository, now: () => today);
        expect(
          await controller.updateProfile(
            user: user,
            name: 'Name',
            gender: null,
            productType: user.productType,
            baselineDailyUsage: baseline,
            costPerUnit: null,
            primaryMotivation: null,
            personalChallenges: null,
            pastQuitAttempts: null,
          ),
          isTrue,
        );
        final saved = (await repository.getUser('u1'))!;
        expect(saved.baselineDailyUsage, baseline);
        expect(saved.quitDate, quitDate);
        expect(saved.reductionSchedule![start], original[start]);
        expect(
          saved.reductionSchedule![today],
          closeTo(baseline * 12 / 13, 0.0001),
        );
        expect(saved.reductionSchedule![quitDate], 0);
        expect(saved.weeklyGoals, baseline == 10 ? ['Old goal'] : isEmpty);
      },
    );
  }

  test('updateName saves the trimmed name and reports success', () async {
    final repository = FakeUserRepository();
    const user = NicotineUser(userId: 'u1', email: 'a@b.com', name: 'Old Name');
    final controller = ProfileController(repository);

    final result = await controller.updateName(user, '  New Name  ');

    expect(result, isTrue);
    expect(controller.status, ProfileEditStatus.success);
    final saved = await repository.getUser('u1');
    expect(saved!.name, 'New Name');
  });

  test('updateName rejects an empty name', () async {
    final repository = FakeUserRepository();
    const user = NicotineUser(userId: 'u1', email: 'a@b.com', name: 'Old Name');
    final controller = ProfileController(repository);

    final result = await controller.updateName(user, '   ');

    expect(result, isFalse);
    expect(controller.status, ProfileEditStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  test('updateGender saves the selected gender', () async {
    final repository = FakeUserRepository();
    const user = NicotineUser(userId: 'u1', email: 'a@b.com');
    final controller = ProfileController(repository);

    final result = await controller.updateGender(user, Gender.male);

    expect(result, isTrue);
    final saved = await repository.getUser('u1');
    expect(saved!.gender, Gender.male);
  });

  test(
    'updateProfile saves editable usage and optional quit-history fields, including clearing blanks',
    () async {
      final repository = FakeUserRepository();
      const user = NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        name: 'Old Name',
        productType: ProductType.vape,
        baselineDailyUsage: 120,
        costPerUnit: 3,
        primaryMotivation: 'old motivation',
        personalChallenges: 'old challenge',
        pastQuitAttempts: 'old attempt',
      );
      final controller = ProfileController(repository);

      final result = await controller.updateProfile(
        user: user,
        name: ' New Name ',
        gender: Gender.female,
        productType: ProductType.cigarettes,
        baselineDailyUsage: 8,
        costPerUnit: null,
        primaryMotivation: '  My family ',
        personalChallenges: '',
        pastQuitAttempts: '  ',
      );

      expect(result, isTrue);
      final saved = await repository.getUser('u1');
      expect(saved!.name, 'New Name');
      expect(saved.gender, Gender.female);
      expect(saved.productType, ProductType.cigarettes);
      expect(saved.baselineDailyUsage, 8);
      expect(saved.costPerUnit, isNull);
      expect(saved.primaryMotivation, 'My family');
      expect(saved.personalChallenges, isNull);
      expect(saved.pastQuitAttempts, isNull);
    },
  );

  test(
    'updateProfile rejects invalid daily use for a selected product',
    () async {
      final controller = ProfileController(FakeUserRepository());

      final result = await controller.updateProfile(
        user: const NicotineUser(userId: 'u1', email: 'a@b.com'),
        name: 'A User',
        gender: null,
        productType: ProductType.cigarettes,
        baselineDailyUsage: 0,
        costPerUnit: null,
        primaryMotivation: null,
        personalChallenges: null,
        pastQuitAttempts: null,
      );

      expect(result, isFalse);
      expect(controller.status, ProfileEditStatus.error);
      expect(controller.errorMessage, contains('Daily consumption'));
    },
  );
}

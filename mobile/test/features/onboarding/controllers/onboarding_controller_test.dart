import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/controllers/onboarding_controller.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';

/// Test-only repository that simulates a Firestore/network failure on save,
/// to verify submitQuitStrategy's failure handling without touching the
/// real FirestoreUserRepository or FakeUserRepository.
class _ThrowingUserRepository implements UserRepository {
  @override
  Future<void> saveUser(NicotineUser user) async {
    throw Exception('simulated network failure');
  }

  @override
  Future<NicotineUser?> getUser(String userId) async => null;
}

void main() {
  final fixedToday = DateTime(2026, 8, 11);

  OnboardingController buildController() {
    return OnboardingController(
      FakeUserRepository(),
      QuitDateCalculator(now: () => fixedToday),
    );
  }

  test('submitQuitStrategy fails without consent', () async {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com')
      ..recordProfile(
        productType: ProductType.cigarettes,
        baselineDailyUsage: 10,
        costPerUnit: 25,
      );

    final success = await controller.submitQuitStrategy(
      quitStrategy: QuitStrategy.coldTurkey,
    );

    expect(success, isFalse);
    expect(controller.status, OnboardingStatus.error);
    expect(controller.errorMessage, contains('Consent'));
  });

  test(
    'full flow: consent -> profile -> COLD_TURKEY strategy persists a NicotineUser',
    () async {
      final repo = FakeUserRepository();
      final controller =
          OnboardingController(repo, QuitDateCalculator(now: () => fixedToday))
            ..startOnboarding(userId: 'u1', email: 'a@b.com')
            ..recordConsent(true)
            ..recordProfile(
              productType: ProductType.vape,
              baselineDailyUsage: 15,
              costPerUnit: 2.5,
              primaryMotivation: 'health',
            );

      final success = await controller.submitQuitStrategy(
        quitStrategy: QuitStrategy.coldTurkey,
      );

      expect(success, isTrue);
      expect(controller.status, OnboardingStatus.success);
      expect(controller.workingUser!.quitDate, fixedToday);
      expect(controller.workingUser!.quitStrategy, QuitStrategy.coldTurkey);

      final saved = await repo.getUser('u1');
      expect(saved, isNotNull);
      expect(saved!.productType, ProductType.vape);
      expect(saved.hasConsented, isTrue);
    },
  );

  test(
    'GRADUAL strategy without a target date surfaces the calculator error',
    () async {
      final controller = buildController()
        ..startOnboarding(userId: 'u1', email: 'a@b.com')
        ..recordConsent(true)
        ..recordProfile(
          productType: ProductType.pouches,
          baselineDailyUsage: 8,
          costPerUnit: 1.2,
        );

      final success = await controller.submitQuitStrategy(
        quitStrategy: QuitStrategy.gradual,
      );

      expect(success, isFalse);
      expect(controller.status, OnboardingStatus.error);
    },
  );

  test('submitQuitStrategy throws if called before startOnboarding', () {
    final controller = buildController();

    expect(
      () =>
          controller.submitQuitStrategy(quitStrategy: QuitStrategy.coldTurkey),
      throwsStateError,
    );
  });

  test('recordGender stores gender on the working user', () {
    final controller = OnboardingController(
      FakeUserRepository(),
      QuitDateCalculator(),
    );
    controller.startOnboarding(userId: 'u1', email: 'a@b.com');

    controller.recordGender(Gender.female);

    expect(controller.workingUser!.gender, Gender.female);
  });

  test('recordProfile rejects a zero baselineDailyUsage', () {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com');

    final success = controller.recordProfile(
      productType: ProductType.cigarettes,
      baselineDailyUsage: 0,
      costPerUnit: 25,
    );

    expect(success, isFalse);
    expect(controller.status, OnboardingStatus.error);
    expect(controller.errorMessage, contains('Daily consumption'));
  });

  test('recordProfile rejects a negative baselineDailyUsage', () {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com');

    final success = controller.recordProfile(
      productType: ProductType.cigarettes,
      baselineDailyUsage: -5,
      costPerUnit: 25,
    );

    expect(success, isFalse);
    expect(controller.status, OnboardingStatus.error);
    expect(controller.errorMessage, contains('Daily consumption'));
  });

  test('recordProfile rejects an unparseable (null) baselineDailyUsage', () {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com');

    final success = controller.recordProfile(
      productType: ProductType.cigarettes,
      baselineDailyUsage: null,
      costPerUnit: 25,
    );

    expect(success, isFalse);
    expect(controller.status, OnboardingStatus.error);
  });

  test('recordProfile rejects a negative costPerUnit', () {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com');

    final success = controller.recordProfile(
      productType: ProductType.cigarettes,
      baselineDailyUsage: 10,
      costPerUnit: -1,
    );

    expect(success, isFalse);
    expect(controller.status, OnboardingStatus.error);
    expect(controller.errorMessage, contains('Cost per unit'));
  });

  test('recordProfile accepts a zero costPerUnit', () {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com');

    final success = controller.recordProfile(
      productType: ProductType.cigarettes,
      baselineDailyUsage: 10,
      costPerUnit: 0,
    );

    expect(success, isTrue);
    expect(controller.status, OnboardingStatus.idle);
    expect(controller.workingUser!.costPerUnit, 0);
  });

  test(
    'recordProfile succeeds and clears a previous validation error on retry',
    () {
      final controller = buildController()
        ..startOnboarding(userId: 'u1', email: 'a@b.com');

      final firstAttempt = controller.recordProfile(
        productType: ProductType.cigarettes,
        baselineDailyUsage: -5,
        costPerUnit: 25,
      );
      expect(firstAttempt, isFalse);
      expect(controller.status, OnboardingStatus.error);

      final secondAttempt = controller.recordProfile(
        productType: ProductType.cigarettes,
        baselineDailyUsage: 10,
        costPerUnit: 25,
      );

      expect(secondAttempt, isTrue);
      expect(controller.status, OnboardingStatus.idle);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'submitQuitStrategy surfaces an error and resets loading state when saveUser fails',
    () async {
      final controller =
          OnboardingController(
              _ThrowingUserRepository(),
              QuitDateCalculator(now: () => fixedToday),
            )
            ..startOnboarding(userId: 'u1', email: 'a@b.com')
            ..recordConsent(true)
            ..recordProfile(
              productType: ProductType.cigarettes,
              baselineDailyUsage: 10,
              costPerUnit: 25,
            );

      final success = await controller.submitQuitStrategy(
        quitStrategy: QuitStrategy.coldTurkey,
      );

      expect(success, isFalse);
      expect(controller.status, OnboardingStatus.error);
      expect(controller.errorMessage, isNotNull);
    },
  );

  test('recordProfile succeeds without a costPerUnit', () {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com');

    final success = controller.recordProfile(
      productType: ProductType.cigarettes,
      baselineDailyUsage: 10,
    );

    expect(success, isTrue);
    expect(controller.workingUser!.costPerUnit, isNull);
  });

  test(
    'recordProfile with ProductType.hookah stores weekly sessions as baselineDailyUsage',
    () {
      final controller = buildController()
        ..startOnboarding(userId: 'u1', email: 'a@b.com');

      final success = controller.recordProfile(
        productType: ProductType.hookah,
        baselineDailyUsage: 4,
      );

      expect(success, isTrue);
      expect(controller.workingUser!.productType, ProductType.hookah);
      expect(controller.workingUser!.baselineDailyUsage, 4);
    },
  );
}

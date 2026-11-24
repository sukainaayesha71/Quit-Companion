import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/controllers/dashboard_controller.dart';
import 'package:quit_companion/features/profile/controllers/profile_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/profile/data/fake_user_repository.dart';
import 'package:quit_companion/features/dashboard/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/profile/presentation/screens/edit_profile_screen.dart';

void main() {
  testWidgets(
    'shows profile details and saves the selected avatar with the full form',
    (tester) async {
      final userRepository = FakeUserRepository();
      await userRepository.saveUser(
        const NicotineUser(
          userId: 'u1',
          email: 'a@b.com',
          name: 'Old Name',
          productType: ProductType.vape,
        ),
      );
      final dashboardController = DashboardController(
        userRepository,
        FakeUsageLogRepository(),
        FakeCravingLogRepository(),
        DashboardStateCalculator(),
      );
      await dashboardController.loadDashboard('u1');
      final profileController = ProfileController(userRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            userId: 'u1',
            dashboardController: dashboardController,
            profileController: profileController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('a@b.com'), findsOneWidget);
      expect(find.text('Vape'), findsOneWidget);
      expect(
        find.byKey(const Key('profile_primary_motivation_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_personal_challenges_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_past_quit_attempts_field')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('edit_profile_avatar_male')));
      await tester.pumpAndSettle();

      final maleAvatarOpacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(const Key('edit_profile_avatar_male')),
          matching: find.byType(Opacity),
        ),
      );
      expect(maleAvatarOpacity.opacity, 1);
      expect((await userRepository.getUser('u1'))!.gender, isNull);
      await tester.enterText(
        find.byKey(const Key('profile_name_field')),
        'New Name',
      );
      await tester.ensureVisible(
        find.byKey(const Key('profile_daily_usage_field')),
      );
      await tester.enterText(
        find.byKey(const Key('profile_daily_usage_field')),
        '1',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('profile_save_button')));
      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      expect(
        profileController.status,
        ProfileEditStatus.success,
        reason: profileController.errorMessage,
      );
      final saved = await userRepository.getUser('u1');
      expect(saved!.name, 'New Name');
      expect(find.text('Profile saved successfully.'), findsOneWidget);
      expect(saved.gender, Gender.male);
    },
  );

  testWidgets('saves editable nicotine profile and quit-history values', (
    tester,
  ) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(
      const NicotineUser(
        userId: 'u1',
        email: 'a@b.com',
        name: 'Old Name',
        productType: ProductType.vape,
        baselineDailyUsage: 50,
      ),
    );
    final dashboardController = DashboardController(
      userRepository,
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      DashboardStateCalculator(),
    );
    await dashboardController.loadDashboard('u1');
    final profileController = ProfileController(userRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          userId: 'u1',
          dashboardController: dashboardController,
          profileController: profileController,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('profile_product_type_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cigarettes').last);
    await tester.enterText(
      find.byKey(const Key('profile_name_field')),
      'New Name',
    );
    await tester.enterText(
      find.byKey(const Key('profile_daily_usage_field')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('profile_cost_per_unit_field')),
      '2.5',
    );
    await tester.enterText(
      find.byKey(const Key('profile_primary_motivation_field')),
      'Family',
    );
    await tester.enterText(
      find.byKey(const Key('profile_personal_challenges_field')),
      'Stress',
    );
    await tester.enterText(
      find.byKey(const Key('profile_past_quit_attempts_field')),
      'One attempt',
    );
    await tester.ensureVisible(find.byKey(const Key('profile_save_button')));
    await tester.tap(find.byKey(const Key('profile_save_button')));
    await tester.pumpAndSettle();

    final saved = await userRepository.getUser('u1');
    expect(saved!.name, 'New Name');
    expect(saved.productType, ProductType.cigarettes);
    expect(saved.baselineDailyUsage, 12);
    expect(saved.costPerUnit, 2.5);
    expect(saved.primaryMotivation, 'Family');
    expect(saved.personalChallenges, 'Stress');
    expect(saved.pastQuitAttempts, 'One attempt');
  });
}

import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';

enum ProfileEditStatus { idle, saving, success, error }

/// Saves editable fields on the shared user object. The caller reloads the
/// dashboard after a successful update so all profile surfaces stay current.
class ProfileController extends ChangeNotifier {
  final UserRepository _userRepository;
  final DateTime Function() now;

  ProfileController(this._userRepository, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  ProfileEditStatus status = ProfileEditStatus.idle;
  String? errorMessage;

  Future<bool> updateName(NicotineUser user, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return _fail('Name cannot be empty.');
    status = ProfileEditStatus.saving;
    errorMessage = null;
    notifyListeners();
    try {
      await _userRepository.saveUser(user.copyWith(name: trimmed));
      status = ProfileEditStatus.success;
      notifyListeners();
      return true;
    } catch (_) {
      return _fail(
        'Could not save your name. Check your connection and try again.',
      );
    }
  }

  Future<bool> setResearchConsent(NicotineUser user, bool consent) async {
    try {
      await _userRepository.saveUser(user.copyWith(researchConsent: consent));
      return true;
    } catch (_) {
      return _fail('Could not update research consent. Please try again.');
    }
  }

  Future<bool> updateGender(NicotineUser user, Gender gender) async {
    status = ProfileEditStatus.saving;
    errorMessage = null;
    notifyListeners();
    try {
      await _userRepository.saveUser(user.copyWith(gender: gender));
      status = ProfileEditStatus.success;
      notifyListeners();
      return true;
    } catch (_) {
      return _fail(
        'Could not save your avatar. Check your connection and try again.',
      );
    }
  }

  Future<bool> updateProfile({
    required NicotineUser user,
    required String name,
    required Gender? gender,
    required ProductType? productType,
    required double? baselineDailyUsage,
    required double? costPerUnit,
    required String? primaryMotivation,
    required String? personalChallenges,
    required String? pastQuitAttempts,
    String? nicotineHistory,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return _fail('Name cannot be empty.');
    if (productType != null &&
        (baselineDailyUsage == null ||
            !baselineDailyUsage.isFinite ||
            baselineDailyUsage <= 0)) {
      return _fail('Daily consumption must be a number greater than 0.');
    }
    if (costPerUnit != null && (!costPerUnit.isFinite || costPerUnit < 0)) {
      return _fail(
        'Cost per unit must be a valid number and cannot be negative.',
      );
    }
    status = ProfileEditStatus.saving;
    errorMessage = null;
    notifyListeners();
    try {
      final motivation = _optionalText(primaryMotivation);
      final challenges = _optionalText(personalChallenges);
      final attempts = _optionalText(pastQuitAttempts);
      final history = _optionalText(nicotineHistory);
      final baselineChanged = baselineDailyUsage != user.baselineDailyUsage;
      var schedule = user.reductionSchedule;
      var scheduleChanged = false;
      final current = now();
      final today = DateTime(current.year, current.month, current.day);
      final quitDate = user.quitDate;
      if (baselineDailyUsage != null &&
          user.quitStrategy == QuitStrategy.gradual &&
          quitDate != null &&
          quitDate.isAfter(today)) {
        // Preserve the original plan duration and past targets. Correcting
        // the baseline updates only today's and future scheduled targets.
        final dates = schedule?.keys.toList() ?? <DateTime>[];
        dates.sort();
        final start = dates.isNotEmpty && dates.first.isBefore(today)
            ? dates.first
            : today;
        final recalculated = QuitDateCalculator(now: () => start)
            .determineQuitDate(
              quitStrategy: QuitStrategy.gradual,
              baselineDailyUsage: baselineDailyUsage,
              selectedTargetDate: quitDate,
            )
            .reductionSchedule!;
        scheduleChanged = recalculated.entries.any(
          (entry) =>
              !entry.key.isBefore(today) && schedule?[entry.key] != entry.value,
        );
        schedule = {
          ...?schedule,
          for (final entry in recalculated.entries)
            if (!entry.key.isBefore(today)) entry.key: entry.value,
        };
      }
      final updated = user.copyWith(
        name: trimmedName,
        gender: gender,
        productType: productType,
        baselineDailyUsage: baselineDailyUsage,
        reductionSchedule: schedule,
        weeklyGoals:
            baselineChanged ||
                scheduleChanged ||
                productType != user.productType
            ? const []
            : null,
        costPerUnit: costPerUnit,
        primaryMotivation: motivation,
        personalChallenges: challenges,
        pastQuitAttempts: attempts,
        nicotineHistory: history,
        clearNicotineHistory: nicotineHistory != null && history == null,
        clearBaselineDailyUsage: baselineDailyUsage == null,
        clearCostPerUnit: costPerUnit == null,
        clearPrimaryMotivation: motivation == null,
        clearPersonalChallenges: challenges == null,
        clearPastQuitAttempts: attempts == null,
      );
      await _userRepository.saveUser(updated);
      status = ProfileEditStatus.success;
      notifyListeners();
      return true;
    } catch (_) {
      return _fail(
        'Could not save your profile. Check your connection and try again.',
      );
    }
  }

  bool _fail(String message) {
    errorMessage = message;
    status = ProfileEditStatus.error;
    notifyListeners();
    return false;
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

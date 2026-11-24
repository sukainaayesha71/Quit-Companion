import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';

enum OnboardingStatus { idle, loading, success, error }

/// FR2 (profile), FR3 (quit strategy / Quit Day, via QuitDateCalculator),
/// FR15 (consent gate) for Module 1.
class OnboardingController extends ChangeNotifier {
  final UserRepository _userRepository;
  final QuitDateCalculator _quitDateCalculator;

  final CoachingClient? coachingClient;
  OnboardingController(
    this._userRepository,
    this._quitDateCalculator, {
    this.coachingClient,
  });

  NicotineUser? _workingUser;
  NicotineUser? get workingUser => _workingUser;

  OnboardingStatus status = OnboardingStatus.idle;
  String? errorMessage;

  void startOnboarding({
    required String userId,
    required String email,
    String? name,
  }) {
    _workingUser = NicotineUser(userId: userId, email: email, name: name);
  }

  void recordConsent(bool consented) {
    _workingUser = _requireWorkingUser().copyWith(hasConsented: consented);
  }

  void recordResearchConsent(bool consented) {
    _workingUser = _requireWorkingUser().copyWith(researchConsent: consented);
  }

  void recordGender(Gender gender) {
    _workingUser = _requireWorkingUser().copyWith(gender: gender);
  }

  /// FR2 profile validation: `baselineDailyUsage` must be a number > 0 (feeds
  /// QuitDateCalculator's GRADUAL taper and FR16's Money Saved — a zero/negative
  /// baseline produces a degenerate schedule, not just an unhelpful one).
  /// `costPerUnit` must be a number >= 0 (also feeds FR16; a free product is
  /// valid, a negative cost is not).
  bool recordProfile({
    required ProductType productType,
    required double? baselineDailyUsage,
    double? costPerUnit,
    String? primaryMotivation,
    String? personalChallenges,
    String? pastQuitAttempts,
    String? nicotineHistory,
  }) {
    final validationError = _validateProfile(baselineDailyUsage, costPerUnit);
    if (validationError != null) {
      errorMessage = validationError;
      status = OnboardingStatus.error;
      notifyListeners();
      return false;
    }
    _workingUser = _requireWorkingUser().copyWith(
      productType: productType,
      baselineDailyUsage: baselineDailyUsage,
      costPerUnit: costPerUnit,
      primaryMotivation: _optionalText(primaryMotivation),
      personalChallenges: _optionalText(personalChallenges),
      pastQuitAttempts: _optionalText(pastQuitAttempts),
      nicotineHistory: _optionalText(nicotineHistory),
    );
    status = OnboardingStatus.idle;
    errorMessage = null;
    notifyListeners();
    return true;
  }

  String? _validateProfile(double? baselineDailyUsage, double? costPerUnit) {
    if (baselineDailyUsage == null || baselineDailyUsage <= 0) {
      return 'Daily consumption must be a number greater than 0.';
    }
    if (costPerUnit != null && costPerUnit < 0) {
      return 'Cost per unit must be a valid number and cannot be negative.';
    }
    return null;
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<bool> submitQuitStrategy({
    required QuitStrategy quitStrategy,
    DateTime? selectedTargetDate,
  }) async {
    final user = _requireWorkingUser();
    if (!user.hasConsented) {
      errorMessage = 'Consent is required before onboarding can be completed.';
      status = OnboardingStatus.error;
      notifyListeners();
      return false;
    }
    status = OnboardingStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final result = _quitDateCalculator.determineQuitDate(
        quitStrategy: quitStrategy,
        baselineDailyUsage: user.baselineDailyUsage ?? 0,
        selectedTargetDate: selectedTargetDate,
      );
      _workingUser = user.copyWith(
        quitStrategy: quitStrategy,
        quitDate: result.quitDate,
        reductionSchedule: result.reductionSchedule,
      );
      await _userRepository.saveUser(_workingUser!);
      if (coachingClient != null) {
        try {
          final generated = await coachingClient!.plan('initial');
          _workingUser = _workingUser!.copyWith(
            weeklyGoals: generated.steps,
            weeklyPlanSource: generated.source,
            weeklyGoalsUpdatedAt: DateTime.now(),
          );
          await _userRepository.saveUser(_workingUser!);
        } catch (_) {
          /* Initial setup remains usable without the backend. */
        }
      }
      status = OnboardingStatus.success;
      notifyListeners();
      return true;
    } on ArgumentError catch (e) {
      errorMessage = e.message.toString();
      status = OnboardingStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      // Covers saveUser failures (e.g. Firestore/network errors), which are
      // not wrapped in a domain exception type — without this, a save
      // failure would leave status stuck at `loading` indefinitely.
      errorMessage =
          'Could not save your quit plan. Check your connection and try again.';
      status = OnboardingStatus.error;
      notifyListeners();
      return false;
    }
  }

  NicotineUser _requireWorkingUser() {
    final user = _workingUser;
    if (user == null) {
      throw StateError(
        'startOnboarding must be called before using OnboardingController.',
      );
    }
    return user;
  }
}

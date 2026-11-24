import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';

/// Canonical entity name per SDD §6 (resolves SRDS's User/NicotineUser naming conflict).
class NicotineUser {
  final String userId;
  final String email;
  final String? name;
  final Gender? gender;
  final ProductType? productType;
  final double? baselineDailyUsage;
  final double? costPerUnit;
  final String? primaryMotivation;
  final String? personalChallenges;
  final String? pastQuitAttempts;
  final String? nicotineHistory;
  final bool hasConsented;
  final bool researchConsent;
  final QuitStrategy? quitStrategy;
  final DateTime? quitDate;
  final Map<DateTime, double>? reductionSchedule;
  final DateTime? lastRelapseDate;
  // FR17 (Module 4, §7.7): "SAVE UpdatedGoals to User.Profile" — fields on
  // this document rather than a new entity/collection (confirmed decision,
  // Module 4 plan Open Decision 2). Null until the first weekly plan runs.
  final List<String>? weeklyGoals;
  final DateTime? weeklyGoalsUpdatedAt;
  final String? weeklyPlanSource;

  const NicotineUser({
    required this.userId,
    required this.email,
    this.name,
    this.gender,
    this.productType,
    this.baselineDailyUsage,
    this.costPerUnit,
    this.primaryMotivation,
    this.personalChallenges,
    this.pastQuitAttempts,
    this.nicotineHistory,
    this.hasConsented = false,
    this.researchConsent = false,
    this.quitStrategy,
    this.quitDate,
    this.reductionSchedule,
    this.lastRelapseDate,
    this.weeklyGoals,
    this.weeklyGoalsUpdatedAt,
    this.weeklyPlanSource,
  });

  NicotineUser copyWith({
    String? name,
    Gender? gender,
    ProductType? productType,
    double? baselineDailyUsage,
    double? costPerUnit,
    String? primaryMotivation,
    String? personalChallenges,
    String? pastQuitAttempts,
    String? nicotineHistory,
    bool clearNicotineHistory = false,
    bool clearBaselineDailyUsage = false,
    bool clearCostPerUnit = false,
    bool clearPrimaryMotivation = false,
    bool clearPersonalChallenges = false,
    bool clearPastQuitAttempts = false,
    bool? hasConsented,
    bool? researchConsent,
    QuitStrategy? quitStrategy,
    DateTime? quitDate,
    Map<DateTime, double>? reductionSchedule,
    DateTime? lastRelapseDate,
    List<String>? weeklyGoals,
    DateTime? weeklyGoalsUpdatedAt,
    String? weeklyPlanSource,
  }) {
    return NicotineUser(
      userId: userId,
      email: email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      productType: productType ?? this.productType,
      baselineDailyUsage: clearBaselineDailyUsage
          ? null
          : baselineDailyUsage ?? this.baselineDailyUsage,
      costPerUnit: clearCostPerUnit ? null : costPerUnit ?? this.costPerUnit,
      primaryMotivation: clearPrimaryMotivation
          ? null
          : primaryMotivation ?? this.primaryMotivation,
      personalChallenges: clearPersonalChallenges
          ? null
          : personalChallenges ?? this.personalChallenges,
      pastQuitAttempts: clearPastQuitAttempts
          ? null
          : pastQuitAttempts ?? this.pastQuitAttempts,
      nicotineHistory: clearNicotineHistory
          ? null
          : nicotineHistory ?? this.nicotineHistory,
      hasConsented: hasConsented ?? this.hasConsented,
      researchConsent: researchConsent ?? this.researchConsent,
      quitStrategy: quitStrategy ?? this.quitStrategy,
      quitDate: quitDate ?? this.quitDate,
      reductionSchedule: reductionSchedule ?? this.reductionSchedule,
      lastRelapseDate: lastRelapseDate ?? this.lastRelapseDate,
      weeklyGoals: weeklyGoals ?? this.weeklyGoals,
      weeklyGoalsUpdatedAt: weeklyGoalsUpdatedAt ?? this.weeklyGoalsUpdatedAt,
      weeklyPlanSource: weeklyPlanSource ?? this.weeklyPlanSource,
    );
  }
}

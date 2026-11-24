import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quit_companion/features/onboarding/models/gender.dart';
import 'package:quit_companion/features/profile/models/nicotine_user.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';
import 'package:quit_companion/features/profile/data/user_repository.dart';

/// Real Firestore implementation of UserRepository, persisting the
/// NicotineUser entity (SDD §6). Requires a configured Firebase project
/// before use — not wired into main.dart until that exists.
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('nicotineUsers');

  @override
  Future<void> saveUser(NicotineUser user) async {
    await _users.doc(user.userId).set({
      'email': user.email,
      'name': user.name,
      'gender': user.gender?.name,
      'productType': user.productType?.name,
      'baselineDailyUsage': user.baselineDailyUsage,
      'costPerUnit': user.costPerUnit,
      'primaryMotivation': user.primaryMotivation,
      'personalChallenges': user.personalChallenges,
      'pastQuitAttempts': user.pastQuitAttempts,
      'nicotineHistory': user.nicotineHistory,
      'hasConsented': user.hasConsented,
      'researchConsent': user.researchConsent,
      'quitStrategy': user.quitStrategy?.name,
      'quitDate': user.quitDate?.toIso8601String(),
      'reductionSchedule': user.reductionSchedule?.map(
        (date, target) => MapEntry(date.toIso8601String(), target),
      ),
      'lastRelapseDate': user.lastRelapseDate?.toIso8601String(),
      'weeklyGoals': user.weeklyGoals,
      'weeklyPlanSource': user.weeklyPlanSource,
      'weeklyGoalsUpdatedAt': user.weeklyGoalsUpdatedAt?.toIso8601String(),
    });
  }

  @override
  Future<NicotineUser?> getUser(String userId) async {
    final doc = await _users.doc(userId).get();
    final data = doc.data();
    if (data == null) return null;

    return NicotineUser(
      userId: userId,
      email: data['email'] as String,
      name: data['name'] as String?,
      gender: _parseGender(data['gender'] as String?),
      productType: _parseProductType(data['productType'] as String?),
      baselineDailyUsage: (data['baselineDailyUsage'] as num?)?.toDouble(),
      costPerUnit: (data['costPerUnit'] as num?)?.toDouble(),
      primaryMotivation: data['primaryMotivation'] as String?,
      personalChallenges: data['personalChallenges'] as String?,
      pastQuitAttempts: data['pastQuitAttempts'] as String?,
      nicotineHistory: data['nicotineHistory'] as String?,
      hasConsented: data['hasConsented'] as bool? ?? false,
      researchConsent: data['researchConsent'] as bool? ?? false,
      quitStrategy: _parseQuitStrategy(data['quitStrategy'] as String?),
      quitDate: (data['quitDate'] as String?) != null
          ? DateTime.parse(data['quitDate'] as String)
          : null,
      reductionSchedule: (data['reductionSchedule'] as Map<String, dynamic>?)
          ?.map(
            (dateStr, target) =>
                MapEntry(DateTime.parse(dateStr), (target as num).toDouble()),
          ),
      lastRelapseDate: (data['lastRelapseDate'] as String?) != null
          ? DateTime.parse(data['lastRelapseDate'] as String)
          : null,
      weeklyGoals: (data['weeklyGoals'] as List<dynamic>?)?.cast<String>(),
      weeklyPlanSource: data['weeklyPlanSource'] as String?,
      weeklyGoalsUpdatedAt: (data['weeklyGoalsUpdatedAt'] as String?) != null
          ? DateTime.parse(data['weeklyGoalsUpdatedAt'] as String)
          : null,
    );
  }

  Gender? _parseGender(String? name) =>
      name == null ? null : Gender.values.firstWhere((v) => v.name == name);

  ProductType? _parseProductType(String? name) => name == null
      ? null
      : ProductType.values.firstWhere((v) => v.name == name);

  QuitStrategy? _parseQuitStrategy(String? name) => name == null
      ? null
      : QuitStrategy.values.firstWhere((v) => v.name == name);
}

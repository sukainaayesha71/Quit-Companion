import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/relapse/data/relapse_prediction_client.dart';

/// Real implementation — calls the FastAPI backend's POST /predict/relapse.
///
/// The endpoint requires a Firebase ID token (it rejects anonymous
/// requests — see backend/app/firebase_auth_dependency.py and the backend
/// AI/ML plan's Decision 3). [getIdToken] defaults to reading it from
/// whichever FirebaseAuth session is already active — email/password,
/// phone/OTP, or Google all populate `currentUser` identically, so this
/// needs no per-sign-in-method handling and no new auth flow.
class HttpRelapsePredictionClient implements RelapsePredictionClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() _getIdToken;

  HttpRelapsePredictionClient({
    required this.baseUrl,
    http.Client? httpClient,
    Future<String?> Function()? getIdToken,
  }) : _httpClient = httpClient ?? http.Client(),
       _getIdToken = getIdToken ?? _defaultGetIdToken;

  static Future<String?> _defaultGetIdToken() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  static const _defaultError =
      'Could not assess this craving. Please try again.';

  @override
  Future<RelapsePrediction> predictDetailed({
    required int intensity,
    required Mood mood,
    required TriggerCategory triggerCategory,
    required int last24hCount,
    double? moodHappy,
    double? moodExcited,
    double? moodEnthusiastic,
    double? moodContented,
    double? moodCalm,
    double? moodIrritable,
    double? moodAnxious,
    double? moodStressed,
    double? moodSad,
    double? moodBored,
    Map<String, double>? recoveryContext,
  }) async {
    final http.Response response;
    try {
      final idToken = await _getIdToken();
      response = await _httpClient.post(
        Uri.parse('$baseUrl/predict/relapse'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'intensity': intensity,
          'mood': mood.name,
          'trigger_category': triggerCategory.name,
          'last_24h_count': last24hCount,
          'mood_happy': ?moodHappy,
          'mood_excited': ?moodExcited,
          'mood_enthusiastic': ?moodEnthusiastic,
          'mood_contented': ?moodContented,
          'mood_calm': ?moodCalm,
          'mood_irritable': ?moodIrritable,
          'mood_anxious': ?moodAnxious,
          'mood_stressed': ?moodStressed,
          'mood_sad': ?moodSad,
          'mood_bored': ?moodBored,
          if (recoveryContext != null && recoveryContext.isNotEmpty)
            'recovery_context': recoveryContext,
        }),
      );
    } catch (_) {
      throw RelapsePredictionException(
        'Could not reach the relapse-risk service. Check your connection.',
      );
    }
    if (response.statusCode != 200) {
      throw RelapsePredictionException(
        _extractDetail(response) ?? _defaultError,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final riskLevel = _parseRiskLevel(data['risk_level'] as String?);
    if (riskLevel == null) {
      throw RelapsePredictionException(_defaultError);
    }
    final imputed = data['imputed_features'];
    return RelapsePrediction(
      riskLevel: riskLevel,
      // Older backends omit these fields: handled as unknown / empty.
      source: parsePredictionSource(data['assessment_source']),
      modelVersion: data['model_version'] as String?,
      imputedFeatures: imputed is List
          ? [
              for (final f in imputed)
                if (f is String) f,
            ]
          : const [],
    );
  }

  @override
  Future<RelapseRiskLevel> predict({
    required int intensity,
    required Mood mood,
    required TriggerCategory triggerCategory,
    required int last24hCount,
    double? moodHappy,
    double? moodExcited,
    double? moodEnthusiastic,
    double? moodContented,
    double? moodCalm,
    double? moodIrritable,
    double? moodAnxious,
    double? moodStressed,
    double? moodSad,
    double? moodBored,
    Map<String, double>? recoveryContext,
  }) async => (await predictDetailed(
    intensity: intensity,
    mood: mood,
    triggerCategory: triggerCategory,
    last24hCount: last24hCount,
    moodHappy: moodHappy,
    moodExcited: moodExcited,
    moodEnthusiastic: moodEnthusiastic,
    moodContented: moodContented,
    moodCalm: moodCalm,
    moodIrritable: moodIrritable,
    moodAnxious: moodAnxious,
    moodStressed: moodStressed,
    moodSad: moodSad,
    moodBored: moodBored,
    recoveryContext: recoveryContext,
  )).riskLevel;

  RelapseRiskLevel? _parseRiskLevel(String? value) {
    for (final level in RelapseRiskLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }

  String? _extractDetail(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = data['detail'];
      return detail is String ? detail : null;
    } catch (_) {
      return null;
    }
  }
}

import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

/// FR8: answers on the device when the Health-Bot backend is unreachable or
/// slower than HttpHealthBotClient.requestTimeout, so the user always gets
/// a curated reply instead of an error.
///
/// Safety first: crisis/emergency phrases are checked locally with the SAME
/// keyword list and the SAME referral text as the backend
/// (backend/app/healthbot/service.py EMERGENCY_KEYWORDS /
/// EMERGENCY_RESPONSE_TEXT). backend/tests/test_healthbot_mobile_parity.py
/// fails if the two lists drift apart.
///
/// Everything else gets one general, non-diagnostic message (taken from the
/// backend's curated "is_this_normal" entry) with general sources. No
/// symptom-specific advice is attempted offline.
class LocalHealthBotFallback {
  const LocalHealthBotFallback();

  static const emergencyKeywords = [
    'severe anxiety',
    'chest pain',
    "can't breathe",
    'cannot breathe',
    'difficulty breathing',
    'heart racing',
    'heart is racing',
    'heart attack',
    'hurt myself',
    'end my life',
    'ending my life',
    'suicidal',
  ];

  static const emergencyResponseText =
      'This sounds like it could be a medical emergency. '
      'Please seek emergency medical care immediately.';

  static const generalGuidance =
      'Most withdrawal symptoms (headaches, irritability, trouble sleeping, '
      'anxiety, cravings) are temporary and normal in the first few weeks '
      "after quitting. If a symptom is severe, doesn't improve, or worries "
      "you, it's always okay to check with a doctor.";

  static const generalSources = [
    HealthBotSource(
      title: 'Tips for Quitting (CDC)',
      url:
          'https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/tips-for-quitting/index.html',
    ),
    HealthBotSource(
      title:
          'Handling Nicotine Withdrawal and Triggers (National Cancer Institute)',
      url:
          'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
    ),
  ];

  bool isEmergency(String query) {
    final lowered = query.toLowerCase();
    return emergencyKeywords.any(lowered.contains);
  }

  /// The text is clean guidance with no technical prefix. Why the backend
  /// couldn't answer is shown separately as a note (HealthBotController),
  /// and the answer is marked [HealthBotAnswerSource.offline] so it is
  /// never presented as AI-generated. An emergency reply stays exactly as
  /// the backend would send it.
  HealthBotAnswer answer(String query) {
    if (isEmergency(query)) {
      return const HealthBotAnswer(
        type: HealthBotAnswerType.emergency,
        responseText: emergencyResponseText,
        isLocalFallback: true,
        source: HealthBotAnswerSource.safety,
      );
    }
    return const HealthBotAnswer(
      type: HealthBotAnswerType.matched,
      responseText: generalGuidance,
      sources: generalSources,
      isLocalFallback: true,
      source: HealthBotAnswerSource.offline,
    );
  }
}

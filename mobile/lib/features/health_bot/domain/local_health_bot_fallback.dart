import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

/// FR8: what the app says when the Health-Bot backend can't answer (no
/// connection, slower than HttpHealthBotClient.requestTimeout, or a server
/// error).
///
/// Safety first: crisis/emergency phrases are still detected on the device,
/// with the SAME keyword list and the SAME referral text as the backend
/// (backend/app/healthbot/service.py EMERGENCY_KEYWORDS /
/// EMERGENCY_RESPONSE_TEXT). backend/tests/test_healthbot_mobile_parity.py
/// fails if the two lists drift apart.
///
/// Any other question gets an honest "couldn't get an answer" reply with
/// "Try again" (added by HealthBotController). The app deliberately gives
/// no generic health paragraph here: the same text for every question read
/// as repetitive and unrelated to what was asked.
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
    'kill myself',
    'want to die',
  ];

  static const emergencyResponseText =
      'This sounds like it could be a medical emergency. '
      'Please seek emergency medical care immediately.';

  /// Reply when no real answer could be fetched. Shown with "Try again".
  static const unavailableText =
      "Sorry, I couldn't get an answer to that just now.";

  bool isEmergency(String query) {
    final lowered = query.toLowerCase();
    return emergencyKeywords.any(lowered.contains);
  }

  /// Marked [HealthBotAnswerSource.offline] so it is never presented as
  /// AI-generated. An emergency reply stays exactly as the backend would
  /// send it.
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
      type: HealthBotAnswerType.unmatched,
      responseText: unavailableText,
      isLocalFallback: true,
      source: HealthBotAnswerSource.offline,
    );
  }
}

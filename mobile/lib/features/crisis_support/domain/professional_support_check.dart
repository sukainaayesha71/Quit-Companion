import 'package:quit_companion/features/craving/models/craving_log.dart';

/// SRDS 4.2 Mental Health Safeguards: decides when to gently suggest
/// talking to a professional, based on the user's own 0–10 "Anxious" and
/// "Sad" ratings from the Log Craving form.
///
/// This is a prompt to offer support, NOT a screening tool or diagnosis.
/// It only counts how often the user rated themselves strongly anxious or
/// sad recently; it never labels the user or infers a condition.
///
/// Rule: at least [minHighRatedLogs] craving logs within the last
/// [window] where `moodAnxious` or `moodSad` is >= [highRatingThreshold].
/// Older logs without slider ratings (null) are ignored.
class ProfessionalSupportCheck {
  static const highRatingThreshold = 8.0;
  static const minHighRatedLogs = 3;
  static const window = Duration(days: 14);

  /// Minimum gap between two prompts, so it doesn't feel like nagging.
  static const promptCooldown = Duration(days: 7);

  const ProfessionalSupportCheck();

  bool shouldSuggest(List<CravingLog> logs, {required DateTime now}) {
    final since = now.subtract(window);
    final highRated = logs.where((log) {
      if (log.timestamp.isBefore(since)) return false;
      return _isHigh(log.moodAnxious) || _isHigh(log.moodSad);
    });
    return highRated.length >= minHighRatedLogs;
  }

  bool _isHigh(double? rating) =>
      rating != null && rating >= highRatingThreshold;
}

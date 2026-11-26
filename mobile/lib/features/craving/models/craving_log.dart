import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

/// SDD §6 / SRDS §5.2: CravingLog { logId, userId, cravingIntensity, mood,
/// triggerCategory, locationContext, activity, timestamp, relapseRiskScore
/// }, plus `notes` (approved Module 3 plan Open Decision 2 — present in
/// SRDS Use Case #3 and the approved UI screenshot, absent only from the
/// SRDS class diagram's attribute list).
///
/// `locationContext` and `activity` are stored separately as strings so
/// the UI can collect distinct place and activity values while remaining
/// compatible with existing Firestore records.
///
/// The ten `mood*` fields (backend AI/ML plan, Open Decision 6, 2026-08-17)
/// are 0-10 continuous self-ratings — one per EMASENS_ML affect dimension
/// (see backend/ml/pipeline/feature_mapping.py) — added *alongside* the
/// existing categorical [mood] pick, not replacing it. All nullable: older
/// Firestore records predate these fields and must keep loading correctly
/// (see FirestoreCravingLogRepository._fromDoc).
class CravingLog {
  final String logId;
  final String userId;
  final int cravingIntensity;
  final Mood mood;
  final TriggerCategory triggerCategory;
  final String locationContext;
  final String activity;
  final String? notes;
  final DateTime timestamp;
  final RelapseRiskLevel relapseRiskScore;
  final bool riskAssessmentPending;

  /// Which method actually produced [relapseRiskScore], as the backend
  /// reported it ('machine_learning', 'rule_based', 'rule_based_fallback');
  /// read with parsePredictionSource. Stored under `assessmentSource`, the
  /// field the backend worker already writes when it re-scores a pending
  /// craving. Null for a still-pending assessment and for records saved
  /// before the app stored it, which then show no "Scored by" label.
  final String? assessmentSource;
  final Map<String, double> recoveryContext;
  final bool? nicotineUsedSinceLastCheckin;

  // Mood-slider ratings (0-10), added for the full_ema relapse-risk model —
  // see backend/ml/pipeline/feature_mapping.py for the exact EMASENS_ML
  // column each one maps to.
  final double? moodHappy;
  final double? moodExcited;
  final double? moodEnthusiastic;
  final double? moodContented;
  final double? moodCalm;
  final double? moodIrritable;
  final double? moodAnxious;
  final double? moodStressed;
  final double? moodSad;
  final double? moodBored;

  const CravingLog({
    required this.logId,
    required this.userId,
    required this.cravingIntensity,
    required this.mood,
    required this.triggerCategory,
    required this.locationContext,
    required this.activity,
    this.notes,
    required this.timestamp,
    required this.relapseRiskScore,
    this.riskAssessmentPending = false,
    this.assessmentSource,
    this.recoveryContext = const {},
    this.nicotineUsedSinceLastCheckin,
    this.moodHappy,
    this.moodExcited,
    this.moodEnthusiastic,
    this.moodContented,
    this.moodCalm,
    this.moodIrritable,
    this.moodAnxious,
    this.moodStressed,
    this.moodSad,
    this.moodBored,
  });
}

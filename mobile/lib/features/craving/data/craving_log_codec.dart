import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/journal/models/mood.dart';

Map<String, dynamic> encodeCraving(CravingLog log) => {
  'logId': log.logId,
  'userId': log.userId,
  'cravingIntensity': log.cravingIntensity,
  'mood': log.mood.name,
  'triggerCategory': log.triggerCategory.name,
  'locationContext': log.locationContext,
  'activity': log.activity,
  'notes': log.notes,
  'timestamp': log.timestamp.toIso8601String(),
  'relapseRiskScore': log.relapseRiskScore.name,
  'riskAssessmentPending': log.riskAssessmentPending,
  'assessmentSource': log.assessmentSource,
  'recoveryContext': log.recoveryContext,
  'nicotineUsedSinceLastCheckin': log.nicotineUsedSinceLastCheckin,
  'moodHappy': log.moodHappy,
  'moodExcited': log.moodExcited,
  'moodEnthusiastic': log.moodEnthusiastic,
  'moodContented': log.moodContented,
  'moodCalm': log.moodCalm,
  'moodIrritable': log.moodIrritable,
  'moodAnxious': log.moodAnxious,
  'moodStressed': log.moodStressed,
  'moodSad': log.moodSad,
  'moodBored': log.moodBored,
};

CravingLog decodeCraving(Map<String, dynamic> data) => CravingLog(
  logId: data['logId'] as String,
  userId: data['userId'] as String,
  cravingIntensity: (data['cravingIntensity'] as num).toInt(),
  mood: Mood.values.byName(data['mood'] as String),
  triggerCategory: TriggerCategory.values.byName(
    data['triggerCategory'] as String,
  ),
  locationContext: data['locationContext'] as String,
  activity: data['activity'] as String,
  notes: data['notes'] as String?,
  timestamp: DateTime.parse(data['timestamp'] as String),
  relapseRiskScore: RelapseRiskLevel.values.byName(
    data['relapseRiskScore'] as String,
  ),
  riskAssessmentPending: data['riskAssessmentPending'] as bool? ?? false,
  assessmentSource: data['assessmentSource'] as String?,
  recoveryContext:
      (data['recoveryContext'] as Map?)?.map(
        (k, v) => MapEntry(k as String, (v as num).toDouble()),
      ) ??
      {},
  nicotineUsedSinceLastCheckin: data['nicotineUsedSinceLastCheckin'] as bool?,
  moodHappy: (data['moodHappy'] as num?)?.toDouble(),
  moodExcited: (data['moodExcited'] as num?)?.toDouble(),
  moodEnthusiastic: (data['moodEnthusiastic'] as num?)?.toDouble(),
  moodContented: (data['moodContented'] as num?)?.toDouble(),
  moodCalm: (data['moodCalm'] as num?)?.toDouble(),
  moodIrritable: (data['moodIrritable'] as num?)?.toDouble(),
  moodAnxious: (data['moodAnxious'] as num?)?.toDouble(),
  moodStressed: (data['moodStressed'] as num?)?.toDouble(),
  moodSad: (data['moodSad'] as num?)?.toDouble(),
  moodBored: (data['moodBored'] as num?)?.toDouble(),
);

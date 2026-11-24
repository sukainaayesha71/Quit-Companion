import 'package:quit_companion/features/onboarding/models/product_type.dart';
import 'package:quit_companion/features/craving/models/relapse_mood.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';

/// SDD §6 / SRDS §5.2: JournalEntry { entryId, userId, entryText, entryDate,
/// relapseFlag }, extended with relapse-specific fields (productUsed,
/// triggerCategory, mood) per the approved Module 5 plan's Open Decision 1
/// — the SDD/SRDS never define a separate RelapseEvent entity, and the
/// approved UI (docs/UI_Design/journal reflection 13.png) shows relapse
/// entries surfacing inside the same Journal list (flagged), not a
/// separate view, confirming one unified entity rather than two.
///
/// The extra fields are null for plain reflections and populated only
/// when [relapseFlag] is true. [entryText] is left null/empty verbatim
/// when the relapse form's optional Notes field is blank — never an
/// auto-composed summary (Module 5 plan Open Decision 3).
class JournalEntry {
  final String entryId;
  final String userId;
  final String? entryText;
  final DateTime entryDate;
  final bool relapseFlag;
  final ProductType? productUsed;
  final TriggerCategory? triggerCategory;
  final RelapseMood? mood;

  const JournalEntry({
    required this.entryId,
    required this.userId,
    this.entryText,
    required this.entryDate,
    this.relapseFlag = false,
    this.productUsed,
    this.triggerCategory,
    this.mood,
  });
}

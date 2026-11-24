/// SRDS Use Case #3 / docs/UI_Design/log craving 6.png's trigger chips.
enum TriggerCategory { stress, afterMeal, socialPressure, boredom, other }

extension TriggerCategoryLabel on TriggerCategory {
  /// Display label for this trigger category (Track tab's Trigger
  /// Breakdown card / recent-activity subtitle).
  String get label => switch (this) {
    TriggerCategory.stress => 'Stress',
    TriggerCategory.afterMeal => 'After Meal',
    TriggerCategory.socialPressure => 'Social Pressure',
    TriggerCategory.boredom => 'Boredom',
    TriggerCategory.other => 'Other',
  };
}

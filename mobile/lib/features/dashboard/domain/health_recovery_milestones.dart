import 'package:quit_companion/features/onboarding/models/product_type.dart';

class HealthRecoveryMilestone {
  final String timeframe;
  final String description;
  final String sourceTitle;
  final String sourceNote;
  final String sourceUrl;

  const HealthRecoveryMilestone({
    required this.timeframe,
    required this.description,
    required this.sourceTitle,
    required this.sourceNote,
    required this.sourceUrl,
  });
}

const _nicotineWithdrawalMilestones = <HealthRecoveryMilestone>[
  HealthRecoveryMilestone(
    timeframe: 'Within 1-2 hours',
    description:
        'If you are nicotine-dependent, cravings may begin after your last use.',
    sourceTitle: 'National Cancer Institute: Nicotine Withdrawal',
    sourceNote:
        'The NCI notes this guidance is relevant to people quitting tobacco products.',
    sourceUrl:
        'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
  ),
  HealthRecoveryMilestone(
    timeframe: 'First 3 days',
    description:
        'Withdrawal symptoms are usually strongest during the first week and often peak in the first 3 days.',
    sourceTitle: 'National Cancer Institute: Nicotine Withdrawal',
    sourceNote:
        'General nicotine-withdrawal guidance; individual experiences vary.',
    sourceUrl:
        'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
  ),
  HealthRecoveryMilestone(
    timeframe: 'First month',
    description:
        'Withdrawal symptoms usually become less intense over the first month; some people experience them longer.',
    sourceTitle: 'National Cancer Institute: Nicotine Withdrawal',
    sourceNote:
        'General nicotine-withdrawal guidance; individual experiences vary.',
    sourceUrl:
        'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
  ),
  HealthRecoveryMilestone(
    timeframe: 'Months or later',
    description:
        'Occasional cravings can return months or years later, often around familiar triggers.',
    sourceTitle: 'National Cancer Institute: Nicotine Withdrawal',
    sourceNote:
        'General nicotine-withdrawal guidance; individual experiences vary.',
    sourceUrl:
        'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
  ),
];

const _cigaretteRecoveryMilestones = <HealthRecoveryMilestone>[
  HealthRecoveryMilestone(
    timeframe: 'Minutes',
    description: 'Heart rate drops after the last cigarette.',
    sourceTitle: 'CDC: Benefits of Quitting Smoking',
    sourceNote: 'CDC cessation timeline for cigarette smoking.',
    sourceUrl: 'https://www.cdc.gov/tobacco/about/benefits-of-quitting.html',
  ),
  HealthRecoveryMilestone(
    timeframe: '24 hours',
    description: 'Nicotine in the blood drops to zero.',
    sourceTitle: 'CDC: Benefits of Quitting Smoking',
    sourceNote: 'CDC cessation timeline for cigarette smoking.',
    sourceUrl: 'https://www.cdc.gov/tobacco/about/benefits-of-quitting.html',
  ),
  HealthRecoveryMilestone(
    timeframe: 'Several days',
    description:
        'Carbon monoxide in the blood falls to the level of someone who does not smoke.',
    sourceTitle: 'CDC: Benefits of Quitting Smoking',
    sourceNote: 'CDC cessation timeline for cigarette smoking.',
    sourceUrl: 'https://www.cdc.gov/tobacco/about/benefits-of-quitting.html',
  ),
  HealthRecoveryMilestone(
    timeframe: '1-12 months',
    description: 'Coughing and shortness of breath decrease.',
    sourceTitle: 'CDC: Benefits of Quitting Smoking',
    sourceNote: 'CDC cessation timeline for cigarette smoking.',
    sourceUrl: 'https://www.cdc.gov/tobacco/about/benefits-of-quitting.html',
  ),
  HealthRecoveryMilestone(
    timeframe: '1-2 years',
    description: 'The risk of heart attack drops sharply.',
    sourceTitle: 'CDC: Benefits of Quitting Smoking',
    sourceNote: 'CDC cessation timeline for cigarette smoking.',
    sourceUrl: 'https://www.cdc.gov/tobacco/about/benefits-of-quitting.html',
  ),
];

const _vapingEvidenceMilestone = HealthRecoveryMilestone(
  timeframe: 'Vaping-specific recovery',
  description:
      'A reliable health-recovery timetable after quitting vaping has not been established; scientists are still studying its short- and long-term effects.',
  sourceTitle: 'CDC: Health Effects of Vaping',
  sourceNote: 'CDC says more research is needed on vaping health effects.',
  sourceUrl: 'https://www.cdc.gov/tobacco/e-cigarettes/health-effects.html',
);

const _pouchEvidenceMilestone = HealthRecoveryMilestone(
  timeframe: 'Pouch-specific recovery',
  description:
      'A reliable recovery timetable after quitting nicotine pouches has not been established; more research is needed on their short- and long-term health effects.',
  sourceTitle: 'CDC: Nicotine Pouches',
  sourceNote: 'CDC says more research is needed on pouch health effects.',
  sourceUrl: 'https://www.cdc.gov/tobacco/nicotine-pouches/index.html',
);

const _hookahEvidenceMilestone = HealthRecoveryMilestone(
  timeframe: 'Hookah-specific recovery',
  description:
      'CDC describes health risks from hookah smoke but does not provide a hookah-specific recovery timetable.',
  sourceTitle: 'CDC: Hookahs',
  sourceNote:
      'CDC reports hookah smoke contains nicotine and other harmful substances.',
  sourceUrl: 'https://www.cdc.gov/tobacco/other-tobacco-products/hookahs.html',
);

const _unknownProductMilestone = HealthRecoveryMilestone(
  timeframe: 'Product-specific recovery',
  description:
      'Choose your nicotine source in your profile to see source-specific information. The withdrawal guidance above is general.',
  sourceTitle: 'National Cancer Institute: Nicotine Withdrawal',
  sourceNote: 'General withdrawal guidance; individual experiences vary.',
  sourceUrl:
      'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
);

List<HealthRecoveryMilestone> healthRecoveryMilestonesFor(
  ProductType? productType,
) => [
  ..._nicotineWithdrawalMilestones,
  ...switch (productType) {
    ProductType.cigarettes => _cigaretteRecoveryMilestones,
    ProductType.vape => [_vapingEvidenceMilestone],
    ProductType.pouches => [_pouchEvidenceMilestone],
    ProductType.hookah => [_hookahEvidenceMilestone],
    null => [_unknownProductMilestone],
  },
];

import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';

/// Trusted external pages used by Knowledge Hub articles and the
/// "Resources" view. Every URL below was requested on 2026-11-23 and
/// returned HTTP 200 directly (no redirect) with a page title matching the
/// topic; pages that 404'd or redirected were left out rather than
/// guessed. Titles are the pages' own titles, lightly shortened.
class KnowledgeResources {
  KnowledgeResources._();

  // ---- World Health Organization ----
  static const whoTobacco = KnowledgeResource(
    title: 'Tobacco and nicotine (fact sheet)',
    organization: ResourceOrganization.who,
    url: 'https://www.who.int/news-room/fact-sheets/detail/tobacco',
  );
  static const whoCessationBenefits = KnowledgeResource(
    title: 'Health benefits of smoking cessation',
    organization: ResourceOrganization.who,
    url:
        'https://www.who.int/news-room/questions-and-answers/item/tobacco-health-benefits-of-smoking-cessation',
  );
  static const whoECigarettes = KnowledgeResource(
    title: 'Tobacco: E-cigarettes',
    organization: ResourceOrganization.who,
    url:
        'https://www.who.int/news-room/questions-and-answers/item/tobacco-e-cigarettes',
  );

  // ---- CDC ----
  static const cdcBenefits = KnowledgeResource(
    title: 'Benefits of Quitting Smoking',
    organization: ResourceOrganization.cdc,
    url: 'https://www.cdc.gov/tobacco/about/benefits-of-quitting.html',
  );
  static const cdcTipsForQuitting = KnowledgeResource(
    title: 'Tips for Quitting',
    organization: ResourceOrganization.cdc,
    url:
        'https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/tips-for-quitting/index.html',
  );
  static const cdcWithdrawalSymptoms = KnowledgeResource(
    title: '7 Common Withdrawal Symptoms',
    organization: ResourceOrganization.cdc,
    url:
        'https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/7-common-withdrawal-symptoms/index.html',
  );
  static const cdcHeartDisease = KnowledgeResource(
    title: 'Smoking and Heart Disease, Stroke, and Peripheral Artery Disease',
    organization: ResourceOrganization.cdc,
    url:
        'https://www.cdc.gov/tobacco/campaign/tips/diseases/heart-disease-stroke.html',
  );
  static const cdcCopd = KnowledgeResource(
    title: 'Smoking and COPD',
    organization: ResourceOrganization.cdc,
    url: 'https://www.cdc.gov/tobacco/campaign/tips/diseases/copd.html',
  );
  static const cdcDepressionAnxiety = KnowledgeResource(
    title: 'Mental Health Conditions: Depression and Anxiety',
    organization: ResourceOrganization.cdc,
    url:
        'https://www.cdc.gov/tobacco/campaign/tips/diseases/depression-anxiety.html',
  );
  static const cdcVapingHealthEffects = KnowledgeResource(
    title: 'Health Effects of Vaping',
    organization: ResourceOrganization.cdc,
    url: 'https://www.cdc.gov/tobacco/e-cigarettes/health-effects.html',
  );
  static const cdcVapingQuitting = KnowledgeResource(
    title: 'Vaping and Quitting',
    organization: ResourceOrganization.cdc,
    url: 'https://www.cdc.gov/tobacco/e-cigarettes/quitting.html',
  );
  static const cdcQuitMedicines = KnowledgeResource(
    title: 'Learn About Quit Smoking Medicines',
    organization: ResourceOrganization.cdc,
    url:
        'https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/quit-smoking-medications/index.html',
  );
  static const cdcSecondhandSmoke = KnowledgeResource(
    title: 'Health Problems Caused by Secondhand Smoke',
    organization: ResourceOrganization.cdc,
    url: 'https://www.cdc.gov/tobacco/secondhand-smoke/health.html',
  );

  // ---- NHS ----
  static const nhsWhatHappens = KnowledgeResource(
    title: 'What could happen when you quit smoking',
    organization: ResourceOrganization.nhs,
    url:
        'https://www.nhs.uk/better-health/quit-smoking/ready-to-quit-smoking/what-could-happen-when-you-quit-smoking/',
  );
  static const nhsMentalHealth = KnowledgeResource(
    title: 'Stopping smoking for your mental health',
    organization: ResourceOrganization.nhs,
    url:
        'https://www.nhs.uk/live-well/quit-smoking/stopping-smoking-mental-health-benefits/',
  );
  static const nhsQuitSmoking = KnowledgeResource(
    title: 'Quit smoking — Better Health',
    organization: ResourceOrganization.nhs,
    url: 'https://www.nhs.uk/better-health/quit-smoking/',
  );
  static const nhsECigarettes = KnowledgeResource(
    title: 'Using e-cigarettes to stop smoking',
    organization: ResourceOrganization.nhs,
    url:
        'https://www.nhs.uk/live-well/quit-smoking/using-e-cigarettes-to-stop-smoking/',
  );
  static const nhsGetActive = KnowledgeResource(
    title: 'Get active — Better Health',
    organization: ResourceOrganization.nhs,
    url: 'https://www.nhs.uk/better-health/get-active/',
  );

  // ---- Smokefree.gov (National Cancer Institute) ----
  static const sfBenefits = KnowledgeResource(
    title: 'Benefits of Quitting Smoking',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-smoking/why-you-should-quit/benefits-of-quitting',
  );
  static const sfReasonsToQuit = KnowledgeResource(
    title: 'Reasons to Quit Smoking',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-smoking/why-you-should-quit/reasons-to-quit',
  );
  static const sfWhyQuit = KnowledgeResource(
    title: 'Why Do You Want to Quit Smoking?',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-smoking/why-you-should-quit/why-do-you-want-to-quit',
  );
  static const sfHealthEffects = KnowledgeResource(
    title: 'Smoking Health Risks',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-smoking/why-you-should-quit/health-effects',
  );
  static const sfSavings = KnowledgeResource(
    title: 'Quit Smoking Savings Calculator',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-smoking/why-you-should-quit/how-much-will-you-save',
  );
  static const sfWorkout = KnowledgeResource(
    title: 'How Smoking Affects Your Workout',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-smoking/why-you-should-quit/how-smoking-affects-your-workout',
  );
  static const sfQuitPlan = KnowledgeResource(
    title: 'Build a Plan to Quit Smoking or Vaping',
    organization: ResourceOrganization.smokefree,
    url: 'https://smokefree.gov/build-your-quit-plan',
  );
  static const sfGettingStarted = KnowledgeResource(
    title: 'How to Quit Smoking',
    organization: ResourceOrganization.smokefree,
    url: 'https://smokefree.gov/quit-smoking/getting-started',
  );
  static const sfManageWithdrawal = KnowledgeResource(
    title: 'Managing Nicotine Withdrawal',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/withdrawal/managing-nicotine-withdrawal',
  );
  static const sfVapingWithdrawal = KnowledgeResource(
    title: 'Nicotine Withdrawal and Vaping',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-vaping-resources/nicotine-withdrawal-vaping',
  );
  static const sfManageCravings = KnowledgeResource(
    title: 'How to Manage Cravings',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/cravings-triggers/how-manage-cravings',
  );
  static const sfVapeCravings = KnowledgeResource(
    title: 'Dealing With Vape Cravings',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/quit-vaping-resources/dealing-with-vape-cravings',
  );
  static const sfTriggers = KnowledgeResource(
    title: 'Know Your Smoking Triggers',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/cravings-triggers/know-your-triggers',
  );
  static const sfExerciseCravings = KnowledgeResource(
    title: 'Fight Smoking Cravings with Exercise',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/cravings-triggers/fight-cravings-exercise',
  );
  static const sfAnxiety = KnowledgeResource(
    title: 'Anxiety & Smoking',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/cravings-triggers/anxiety-smoking',
  );
  static const sfGetBackOnTrack = KnowledgeResource(
    title: 'Smoking Relapse: Get Back on Track',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/stick-with-it/get-back-on-track',
  );
  static const sfStayQuit = KnowledgeResource(
    title: 'How to Stay Quit',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/stick-with-it/how-to-stay-smokefree',
  );
  static const sfStressSmoking = KnowledgeResource(
    title: 'Smoking and Stress',
    organization: ResourceOrganization.smokefree,
    url: 'https://smokefree.gov/challenges-when-quitting/stress/stress-smoking',
  );
  static const sfCopingStress = KnowledgeResource(
    title: 'Coping With Stress Without Smoking',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/stress/coping-with-stress',
  );
  static const sfMindfulness = KnowledgeResource(
    title: 'Mindfulness and Quitting Smoking',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/stress/practice-mindfulness',
  );
  static const sfVapingStress = KnowledgeResource(
    title: 'Stress, Anxiety, and Vaping',
    organization: ResourceOrganization.smokefree,
    url: 'https://smokefree.gov/quit-vaping-resources/stress-anxiety-vaping',
  );
  static const sfBoostMood = KnowledgeResource(
    title: 'Boost Your Mood',
    organization: ResourceOrganization.smokefree,
    url: 'https://smokefree.gov/challenges-when-quitting/mood/boost-your-mood',
  );
  static const sfDepression = KnowledgeResource(
    title: 'Smoking & Depression',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/mood/smoking-depression',
  );
  static const sfNutrition = KnowledgeResource(
    title: 'Nutrition & Appetite While Quitting',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/weight-gain-appetite/nutrition-appetite-while-quitting',
  );
  static const sfWeightGain = KnowledgeResource(
    title: 'Manage Weight Gain After Quitting',
    organization: ResourceOrganization.smokefree,
    url:
        'https://smokefree.gov/challenges-when-quitting/weight-gain-appetite/manage-weight-gain',
  );

  // ---- National Cancer Institute ----
  static const nciWithdrawal = KnowledgeResource(
    title: 'Tips for Coping with Nicotine Withdrawal and Triggers',
    organization: ResourceOrganization.nci,
    url:
        'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet',
  );
  static const nciCessation = KnowledgeResource(
    title: 'Harms of Cigarette Smoking and Health Benefits of Quitting',
    organization: ResourceOrganization.nci,
    url:
        'https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/cessation-fact-sheet',
  );
}

/// The "Resources" view in the Knowledge Hub: a short, organisation-
/// grouped list of the most useful general pages.
const knowledgeResourceLibrary = <KnowledgeResource>[
  KnowledgeResources.whoTobacco,
  KnowledgeResources.whoCessationBenefits,
  KnowledgeResources.whoECigarettes,
  KnowledgeResources.cdcBenefits,
  KnowledgeResources.cdcTipsForQuitting,
  KnowledgeResources.cdcWithdrawalSymptoms,
  KnowledgeResources.cdcVapingQuitting,
  KnowledgeResources.nhsQuitSmoking,
  KnowledgeResources.nhsWhatHappens,
  KnowledgeResources.nhsMentalHealth,
  KnowledgeResources.sfQuitPlan,
  KnowledgeResources.sfManageCravings,
  KnowledgeResources.sfTriggers,
  KnowledgeResources.sfCopingStress,
  KnowledgeResources.sfGetBackOnTrack,
  KnowledgeResources.nciWithdrawal,
  KnowledgeResources.nciCessation,
];

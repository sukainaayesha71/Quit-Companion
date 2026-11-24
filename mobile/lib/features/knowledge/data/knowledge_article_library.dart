import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_article_library_expanded.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_resource_library.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';

/// FR13's fixed, pre-vetted content library. The original six articles
/// (matching docs/UI_Design/knowledge hub 14.png's six cards) are kept
/// unchanged; ten more were added covering health effects of continued
/// use, withdrawal, the science of addiction, and quitting methods —
/// each fact-checked against a named WHO/CDC/NIH/peer-reviewed source
/// (cited per article below), per FR13's "sourced from WHO, CDC, and
/// peer-reviewed medical research" requirement.
///
/// Images: bundled only where a specific picture could be verified as a
/// U.S. federal government work (public domain under 17 U.S.C. § 105) —
/// CDC/NIH/NIDA-hosted diagrams and infographics, never a photo of an
/// identifiable real person (no "before/after" patient photos exist in
/// this library — see the project handoff notes for why). Every other
/// article uses a specific, topic-relevant icon instead of a generic
/// per-category one.
const knowledgeArticleLibrary = <KnowledgeArticle>[
  // ---- Original six (unchanged text) ----
  KnowledgeArticle(
    articleId: 'lungs_day_3',
    title: 'Lungs at Day 3',
    category: KnowledgeCategory.healthWellness,
    summary: 'How breathing starts to ease in the first days after quitting.',
    resources: [
      KnowledgeResources.nhsWhatHappens,
      KnowledgeResources.sfBenefits,
    ],
    icon: Icons.air_rounded,
    body:
        'By 72 hours after your last nicotine use, bronchial tubes begin to relax and breathing '
        'starts to feel easier for many people. Lung function continues to improve gradually over '
        'the following weeks and months as cilia — tiny hair-like structures that clear mucus and '
        'debris — start to regrow and work more effectively. Early breathlessness during light '
        'activity is common in the first days and typically eases as this recovery continues.',
  ),
  KnowledgeArticle(
    articleId: 'health_benefits',
    title: 'Health Benefits',
    category: KnowledgeCategory.addictionRecovery,
    summary:
        'The health gains that begin within a day of quitting and keep growing.',
    resources: [
      KnowledgeResources.whoCessationBenefits,
      KnowledgeResources.cdcBenefits,
    ],
    icon: Icons.favorite_rounded,
    body:
        'Quitting nicotine brings measurable health benefits on a predictable timeline: heart rate '
        'and blood pressure begin to drop within the first day, carbon monoxide levels in the blood '
        'normalize within 12 hours, circulation and lung function improve within weeks to months, '
        'and longer-term risk of heart disease and several cancers continues to fall the longer you '
        'stay nicotine-free. Every smoke-free or vape-free day contributes to this recovery.',
  ),
  KnowledgeArticle(
    articleId: 'why_anxious',
    title: 'Why Do I Feel Anxious?',
    category: KnowledgeCategory.healthWellness,
    summary: 'Why anxiety is common early in quitting, and what helps.',
    resources: [KnowledgeResources.nciWithdrawal, KnowledgeResources.sfAnxiety],
    icon: Icons.self_improvement_rounded,
    body:
        'Anxiety during the first weeks after quitting is a well-documented withdrawal symptom, not '
        'a sign that something is wrong. Nicotine affects the same brain chemistry involved in mood '
        'regulation, so your nervous system needs time to recalibrate once it is removed. This '
        'usually peaks in the first few days and eases over the following weeks. Slow breathing, '
        'light exercise, and staying hydrated can help in the moment.',
  ),
  KnowledgeArticle(
    articleId: 'brain_on_cravings',
    title: 'Your Brain on Cravings',
    category: KnowledgeCategory.cravingsRelapse,
    summary: 'What a craving is, and why it passes in minutes.',
    resources: [
      KnowledgeResources.sfManageCravings,
      KnowledgeResources.nciWithdrawal,
    ],
    icon: Icons.bolt_rounded,
    body:
        'A craving is your brain\'s learned response to nicotine withdrawal and to cues it has '
        'associated with past use — a place, a feeling, a time of day. Most cravings peak within a '
        'few minutes and pass whether or not you act on them, typically lasting 3-5 minutes. '
        'Recognizing a craving as a temporary brain signal, rather than a command you must obey, is '
        'one of the most effective tools for riding it out.',
  ),
  KnowledgeArticle(
    articleId: 'heart_day_7',
    title: 'Your Heart at Day 7',
    category: KnowledgeCategory.healthWellness,
    summary: 'What one nicotine-free week means for your heart.',
    resources: [
      KnowledgeResources.cdcHeartDisease,
      KnowledgeResources.sfBenefits,
    ],
    icon: Icons.monitor_heart_rounded,
    body:
        'One week after your last nicotine use, heart rate and blood pressure are typically much '
        'closer to a healthy baseline than when you were using nicotine regularly, and circulation '
        'continues to improve. Some people notice they can be more physically active with less '
        'effort. This is an early milestone in a longer-term reduction in cardiovascular risk that '
        'continues the longer you stay nicotine-free.',
  ),
  KnowledgeArticle(
    articleId: 'science_of_addiction',
    title: 'The Science of Addiction',
    category: KnowledgeCategory.addictionRecovery,
    summary:
        'How nicotine creates dependence, and why quitting is hard but possible.',
    resources: [
      KnowledgeResources.whoTobacco,
      KnowledgeResources.sfManageWithdrawal,
    ],
    icon: Icons.psychology_rounded,
    body:
        'Nicotine addiction develops because nicotine triggers the release of dopamine, a brain '
        'chemical associated with pleasure and reward, reinforcing the urge to use it again. Over '
        'time, the brain adapts to expect nicotine, which is why stopping causes withdrawal '
        'symptoms. This is a well-studied biological process, not a matter of willpower alone — '
        'understanding it is often the first step toward managing cravings more effectively.',
  ),

  // ---- New: Health Effects (harms of continued use) ----
  // Sources: CDC "Tobacco and Cancer" (cdc.gov/cancer/risk-factors/tobacco.html),
  // CDC Fast Facts (cdc.gov/tobacco/data_statistics/fact_sheets/fast_facts),
  // NIH/NCBI Bookshelf "How Tobacco Smoke Causes Disease" (NBK53021),
  // CDC EVALI outbreak page (archive.cdc.gov).
  // Image: NIH/NHLBI "Normal Lungs and Lungs With COPD" diagram
  // (nhlbi.nih.gov/health/copd/causes) — U.S. government work, public domain.
  KnowledgeArticle(
    articleId: 'lungs_on_smoke',
    title: 'Your Lungs on Smoke',
    category: KnowledgeCategory.healthRisks,
    summary: 'How smoke damages the airways and lungs over time.',
    resources: [KnowledgeResources.cdcCopd, KnowledgeResources.sfHealthEffects],
    imageAssetPath: 'assets/images/knowledge/lungs_copd.jpg',
    body:
        'Cigarette smoke contains thousands of chemicals, at least 69 of which are known to cause '
        'cancer. Inhaling them triggers ongoing inflammation in the lungs\' airways and air sacs '
        '(alveoli). Over years, that inflammation can thicken and narrow the airways — chronic '
        'bronchitis — or break down the walls of the alveoli — emphysema. Together these are known '
        'as chronic obstructive pulmonary disease (COPD), and smokers are 12 to 13 times more likely '
        'to die from it than non-smokers. The same chemicals can damage the DNA inside lung cells, a '
        'major reason smoking causes most lung cancer cases. Vaping introduces its own inhaled '
        'chemicals and has been linked to cases of acute lung injury. The lungs can repair themselves '
        'once smoke exposure stops — quitting, at any age, slows ongoing damage.',
  ),
  KnowledgeArticle(
    articleId: 'smoke_and_heart',
    title: 'Smoke and the Heart',
    category: KnowledgeCategory.healthRisks,
    summary: 'How smoking strains the heart and blood vessels.',
    resources: [
      KnowledgeResources.cdcHeartDisease,
      KnowledgeResources.sfHealthEffects,
    ],
    imageAssetPath: 'assets/images/knowledge/heart_cad.jpg',
    body:
        'Smoking is a leading cause of cardiovascular disease, responsible for about one in three '
        'deaths from heart and blood vessel disease in the United States. Each puff exposes blood '
        'vessels to chemicals and nicotine that raise heart rate and blood pressure and make blood '
        'more likely to clot. Over time this contributes to atherosclerosis — fatty plaque building '
        'up inside artery walls — which can trigger heart attacks or strokes. Smokers face two to '
        'four times the risk of coronary heart disease and stroke compared with non-smokers. The '
        'cardiovascular system also responds quickly to quitting: heart rate and blood pressure begin '
        'dropping within minutes, and by one year smoke-free, the added risk of heart attack drops '
        'sharply. Blood vessels respond to the absence of smoke almost immediately.',
  ),
  KnowledgeArticle(
    articleId: 'tobacco_and_cancer',
    title: 'How Tobacco Fuels Cancer',
    category: KnowledgeCategory.healthRisks,
    summary: 'How tobacco smoke damages cells and raises cancer risk.',
    resources: [
      KnowledgeResources.nciCessation,
      KnowledgeResources.sfHealthEffects,
    ],
    imageAssetPath: 'assets/images/knowledge/cancer_body.png',
    body:
        'Tobacco use is linked to more than a dozen cancers beyond lung cancer, including cancers of '
        'the mouth, throat, esophagus, bladder, kidney, liver, stomach, pancreas, and cervix, as well '
        'as acute myeloid leukemia. Cigarette smoke contains at least 69 known carcinogens, which '
        'travel through the bloodstream and can damage DNA anywhere in the body, not just the lungs. '
        'Damaged DNA that isn\'t repaired correctly can cause cells to grow abnormally — how cancer '
        'begins. The encouraging counterpart is that this risk is reversible: people who quit '
        'gradually lower their risk for a dozen cancer types over the years that follow, even after '
        'decades of use.',
  ),
  KnowledgeArticle(
    articleId: 'vaping_beyond_vapor',
    title: 'Vaping: Beyond the Vapor',
    category: KnowledgeCategory.healthRisks,
    summary: 'What is known about the health effects of vaping.',
    resources: [
      KnowledgeResources.cdcVapingHealthEffects,
      KnowledgeResources.whoECigarettes,
    ],
    imageAssetPath: 'assets/images/knowledge/vape_devices.jpg',
    body:
        'E-cigarettes heat a liquid — usually containing nicotine, flavorings, and other chemicals — '
        'into an aerosol that gets inhaled. Vaping is newer than smoking, so long-term research is '
        'still developing, but real risks are already documented. Most e-cigarettes contain nicotine, '
        'which is addictive and, in people under 25, can affect brain areas still developing, '
        'including attention and impulse control. Vaping aerosol is not simply water vapor — it can '
        'carry ultrafine particles, heavy metals, and volatile organic compounds. In 2019-2020, a '
        'nationwide outbreak of severe vaping-related lung injury (EVALI) hospitalized thousands of '
        'people in the US, strongly linked to vitamin E acetate, an additive found mainly in illicit '
        'THC vaping products. Less harmful than cigarettes is not the same as harmless.',
  ),
  KnowledgeArticle(
    articleId: 'secondhand_smoke',
    title: 'The Smoke You Didn\'t Choose',
    category: KnowledgeCategory.healthRisks,
    summary: 'How secondhand smoke affects the people around you.',
    resources: [
      KnowledgeResources.cdcSecondhandSmoke,
      KnowledgeResources.whoTobacco,
    ],
    icon: Icons.groups_rounded,
    body:
        'Smoke and vapor exhaled by someone else don\'t stay contained to that person. Secondhand '
        'tobacco smoke contains many of the same chemicals as inhaled smoke, and there is no '
        'risk-free level of exposure. In non-smoking adults, it causes coronary heart disease, '
        'stroke, and lung cancer, and contributes to tens of thousands of early heart disease deaths '
        'in the US each year among non-smokers. Children are especially vulnerable — exposure is '
        'linked to sudden infant death syndrome, more ear infections, and more severe asthma attacks. '
        'Vaping produces secondhand aerosol rather than smoke; it is chemically different, but health '
        'agencies have concluded it is not harmless either, since bystanders can still breathe in '
        'nicotine and other chemicals. Smoke-free and vape-free indoor spaces remain one of the most '
        'effective ways to protect non-smokers.',
  ),

  // ---- New: Science of Addiction ----
  // Sources: NIDA "Is Nicotine Addictive?" and "Drugs, Brains, and Behavior"
  // (nida.nih.gov). No safe verified image found that specifically
  // illustrates nicotine (the only available NIDA reward-pathway diagram
  // uses cocaine as its example drug, which would misleadingly suggest
  // nicotine and cocaine work identically) — icon fallback used instead.
  KnowledgeArticle(
    articleId: 'brain_on_nicotine',
    title: 'Your Brain on Nicotine',
    category: KnowledgeCategory.addictionRecovery,
    summary: "How nicotine acts on the brain's reward system.",
    resources: [
      KnowledgeResources.whoTobacco,
      KnowledgeResources.sfVapingWithdrawal,
    ],
    icon: Icons.electric_bolt_rounded,
    body:
        'Nicotine reaches the brain within about ten seconds of inhaling — faster than drugs taken '
        'by almost any other route. It binds to nicotinic receptors in the brain\'s reward pathway, '
        'triggering a surge of dopamine that produces a brief sense of pleasure or calm. Because that '
        'effect fades within minutes, the brain is left wanting another dose. With continued exposure, '
        'the brain adapts by growing more nicotinic receptors and becoming less sensitive to dopamine '
        '— tolerance. These changes also reach circuits governing learning, stress, and self-control, '
        'part of why cravings can feel automatic. When nicotine is removed, the brain needs time to '
        'recalibrate — that recalibration is what produces withdrawal. Understanding addiction as a '
        'brain-based process, not a personal failing, is one reason evidence-based support improves '
        'the odds of quitting for good.',
  ),

  // ---- New: Withdrawal ----
  // Sources: CDC "7 Common Withdrawal Symptoms", NIDA "Is Nicotine
  // Addictive?" (withdrawal peak/duration), NCI "Tips for Coping with
  // Nicotine Withdrawal and Triggers". No direct-image-file candidate
  // found on an approved .gov domain — icon fallback used.
  KnowledgeArticle(
    articleId: 'withdrawal_timeline',
    title: 'The Withdrawal Timeline',
    category: KnowledgeCategory.addictionRecovery,
    summary: 'When withdrawal symptoms peak and when they fade.',
    resources: [
      KnowledgeResources.cdcWithdrawalSymptoms,
      KnowledgeResources.nciWithdrawal,
    ],
    icon: Icons.timeline_rounded,
    body:
        'Nicotine withdrawal follows a fairly predictable pattern. Symptoms can begin within a few '
        'hours of the last cigarette or vape, as nicotine levels in the blood start to fall. They '
        'typically peak around day two or three, when cravings, irritability, restlessness, and '
        'disrupted sleep are often strongest — this early window is also when the chance of returning '
        'to nicotine is highest. Over the following one to four weeks, most physical symptoms '
        'gradually ease as the body adjusts. Mood-related symptoms tend to fade on a similar timeline '
        'for most people, though some notice lingering effects for a few months. Occasional, brief '
        'cravings can resurface even months or years later, often triggered by familiar routines or '
        'stress, but are generally shorter and milder than early withdrawal. Knowing the general '
        'timeline in advance can make the hardest days easier to get through.',
  ),

  // ---- New: Quitting Methods & Benefits ----
  // Sources: CDC "Benefits of Quitting Smoking", HHS/CDC 2020 Surgeon
  // General's Report on Smoking Cessation, NIH/NCBI Bookshelf (NBK555590),
  // CDC Vital Signs "Cancer and Tobacco Use", PubMed randomized trial on
  // gradual vs. abrupt cessation, CDC quitline resources.
  // Image (20 Minutes to 15 Years): no safe direct-image-file candidate
  // found — icon fallback. Image (Long-Term Payoff): CDC 2020 Surgeon
  // General's Report partner-toolkit graphic (archive.cdc.gov) — U.S.
  // government work, public domain.
  KnowledgeArticle(
    articleId: 'quitting_20min_15yr',
    title: '20 Minutes to 15 Years',
    category: KnowledgeCategory.addictionRecovery,
    summary: "Your body's recovery timeline, from 20 minutes to 15 years.",
    resources: [
      KnowledgeResources.whoCessationBenefits,
      KnowledgeResources.sfReasonsToQuit,
    ],
    icon: Icons.hourglass_bottom_rounded,
    body:
        'Quitting nicotine brings health benefits on a remarkably fast and predictable timeline. '
        'Within 20 minutes of the last cigarette, heart rate and blood pressure begin to drop. By 12 '
        'hours, carbon monoxide levels in the blood fall back to normal, part of why breathing often '
        'feels easier within days. These changes keep building: within a year smoke-free, added heart '
        'attack risk drops sharply, and coronary heart disease risk is roughly half that of someone '
        'who still smokes. By five years, added risk of several cancers is cut by half, and stroke '
        'risk can fall to about that of someone who never smoked. By fifteen years, coronary heart '
        'disease risk approaches that of a non-smoker. None of this requires quitting perfectly — '
        'every smoke-free day contributes to this recovery curve.',
  ),
  KnowledgeArticle(
    articleId: 'long_term_payoff',
    title: 'The Long-Term Payoff',
    category: KnowledgeCategory.addictionRecovery,
    summary: 'The long-term health gains of staying nicotine-free.',
    resources: [
      KnowledgeResources.cdcBenefits,
      KnowledgeResources.nciCessation,
    ],
    imageAssetPath: 'assets/images/knowledge/quit_benefits.png',
    body:
        'For people who successfully quit, the long-term health trajectory increasingly resembles '
        'that of someone who never smoked. Quitting can add as much as ten years back to life '
        'expectancy, and the earlier it happens, the larger the gain — people who quit by age 40 '
        'avoid most of the excess lung cancer risk long-term smokers face later in life. Risk for '
        'heart disease, stroke, and COPD all decline over time; research following former smokers for '
        'fifteen years or more finds their risk of heart failure converges with that of people who '
        'never smoked. Cancer risk follows a similar downward curve, with the benefit growing the '
        'longer someone stays smoke-free. Population data collected over decades already shows '
        'tobacco-related cancer death rates falling as smoking rates decline — a trend expected to '
        'continue.',
  ),
  KnowledgeArticle(
    articleId: 'what_actually_works',
    title: 'What Actually Works',
    category: KnowledgeCategory.cravingsRelapse,
    summary: 'Evidence-based support that improves your chances of quitting.',
    resources: [
      KnowledgeResources.cdcQuitMedicines,
      KnowledgeResources.nhsECigarettes,
      KnowledgeResources.cdcVapingQuitting,
      KnowledgeResources.sfGettingStarted,
    ],
    icon: Icons.checklist_rounded,
    body:
        'Research on quitting points to a few consistent findings. Trials comparing gradually cutting '
        'down with quitting abruptly on a set date have generally found abrupt quitting leads to '
        'higher long-term success, though both beat not trying at all. What matters most across '
        'studies is support: behavioral counseling — from a doctor, a text-based program, or a free '
        'quitline — measurably improves the odds of quitting for good, and combining counseling with '
        'cessation medication works better than either alone. Practical strategies that show up '
        'repeatedly in the research include setting a specific quit date, identifying personal '
        'triggers in advance, planning for the first difficult week, and lining up social support '
        'before quitting rather than after. There\'s no single method that works for everyone, but the '
        'evidence is consistent that quitting is a skill supported by preparation and outside help, '
        'not just willpower.',
  ),
  // ---- Expansion (2026-11-23): 21 sourced articles ----
  ...expandedKnowledgeArticles,
];

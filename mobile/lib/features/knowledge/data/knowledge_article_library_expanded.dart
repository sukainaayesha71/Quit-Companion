import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/knowledge/data/knowledge_resource_library.dart';
import 'package:quit_companion/features/knowledge/models/knowledge_article.dart';

/// Knowledge Hub expansion (2026-11-23): 21 original articles covering
/// addiction and recovery, cravings and relapse prevention, health and
/// wellness, and motivation and lifestyle.
///
/// Every factual statement comes from a trusted page that was fetched and
/// read on 2026-11-23 (the per-article "Sources" comments list them; each
/// is also linked in the article's `resources`). Nothing is copied
/// verbatim; there are no diagnoses or medicine dosages. Where the sources
/// give no figure (for example, exactly how long nicotine stays in the
/// body) the article says so instead of guessing.
const expandedKnowledgeArticles = <KnowledgeArticle>[
  // ======================= Addiction & Recovery =======================

  // Sources: WHO "Tobacco and nicotine" fact sheet; Smokefree.gov
  // "Nicotine Withdrawal and Vaping", "How Smoking Affects Your Workout",
  // "Benefits of Quitting Smoking".
  KnowledgeArticle(
    articleId: 'nicotine_brain_body',
    title: 'How Nicotine Affects Your Brain and Body',
    category: KnowledgeCategory.addictionRecovery,
    icon: Icons.psychology_rounded,
    summary:
        'Why nicotine is so addictive, what it does to your heart and blood, '
        'and how that starts to reverse.',
    resources: [
      KnowledgeResources.whoTobacco,
      KnowledgeResources.sfVapingWithdrawal,
      KnowledgeResources.sfWorkout,
    ],
    body:
        "Nicotine is what makes cigarettes, vapes, nicotine pouches and other "
        "tobacco products addictive. The World Health Organization describes "
        "nicotine as highly addictive and harmful, particularly for children, "
        "teenagers and young adults, whose brains are still developing.\n\n"
        "With regular use, your brain and body get used to having nicotine. "
        "When the level in your bloodstream drops between uses, you can feel "
        "restless, irritable or anxious and have strong urges to use again. "
        "That is why stopping feels uncomfortable at first: it is your body "
        "readjusting, not a sign that something is wrong.\n\n"
        "Nicotine affects more than the brain. Smokefree.gov explains that "
        "the nicotine and carbon monoxide from smoking can make your blood "
        "\"sticky\" and narrow your arteries, so less blood reaches your "
        "heart, muscles and other organs. Smoking also raises your resting "
        "heart rate because your heart has to work harder. This is part of "
        "why exercise can feel harder for people who smoke.\n\n"
        "These effects begin to reverse when you stop. Heart rate and blood "
        "pressure start to come down almost immediately, and the large "
        "number of nicotine receptors in your brain returns to normal levels "
        "after about a month without smoking (Smokefree.gov). Each "
        "nicotine-free day helps your brain and body reset.",
  ),

  // Sources: NHS "What could happen when you quit smoking"; Smokefree.gov
  // "Benefits of Quitting Smoking"; NCI withdrawal fact sheet; WHO
  // "Health benefits of smoking cessation".
  KnowledgeArticle(
    articleId: 'quit_milestones_24h_1y',
    title: 'Quitting Milestones: 24 Hours to 1 Year',
    category: KnowledgeCategory.addictionRecovery,
    icon: Icons.timeline_rounded,
    summary:
        'What happens in your body after one day, one week, one month and '
        'one year without smoking.',
    resources: [
      KnowledgeResources.nhsWhatHappens,
      KnowledgeResources.whoCessationBenefits,
      KnowledgeResources.sfBenefits,
    ],
    body:
        "Your body starts to recover from the first day without smoking. "
        "These are the milestones that trusted health services describe. "
        "They come from studies of people who stopped smoking, and everyone "
        "is different, so treat them as typical patterns rather than exact "
        "deadlines.\n\n"
        "After 24 hours: within 20 minutes your pulse starts returning to "
        "normal, and after 8 hours the carbon monoxide in your blood has "
        "halved while oxygen levels recover (NHS). Smokefree.gov notes that "
        "your risk of a heart attack begins to decline within 24 hours.\n\n"
        "After 1 week: by 48 hours, carbon monoxide is down to non-smoker "
        "levels, your lungs are clearing out mucus, and your senses of taste "
        "and smell are improving. By 72 hours, breathing can feel easier as "
        "your bronchial tubes relax, and your energy increases (NHS). "
        "Withdrawal is usually strongest in this first week, peaking in the "
        "first 3 days, and then eases (NCI).\n\n"
        "After 1 month: within about two weeks you may find stairs easier "
        "because you are less short of breath, and after about a month the "
        "nicotine receptors in your brain return to normal levels "
        "(Smokefree.gov). Between 2 and 12 weeks, your circulation improves "
        "(NHS, WHO).\n\n"
        "After 1 year: between 3 and 9 months, coughs, wheezing and breathing "
        "problems improve as lung function increases by up to 10% (NHS). "
        "After a year, your risk of a heart attack is about half that of a "
        "smoker (NHS), and WHO describes your risk of coronary heart disease "
        "as about half a smoker's.",
  ),

  // Sources: NCI "Tips for Coping with Nicotine Withdrawal and Triggers";
  // CDC "7 Common Withdrawal Symptoms"; Smokefree.gov "Managing Nicotine
  // Withdrawal" and "Nicotine Withdrawal and Vaping".
  KnowledgeArticle(
    articleId: 'understanding_withdrawal',
    title: 'Understanding Nicotine Withdrawal Symptoms',
    category: KnowledgeCategory.addictionRecovery,
    icon: Icons.waves_rounded,
    summary:
        'The common symptoms of withdrawal, when they peak, and simple ways '
        'to cope.',
    resources: [
      KnowledgeResources.nciWithdrawal,
      KnowledgeResources.cdcWithdrawalSymptoms,
      KnowledgeResources.sfVapingWithdrawal,
    ],
    body:
        "When you stop using nicotine, your body has to get used to being "
        "without it. That adjustment causes withdrawal symptoms. They can be "
        "uncomfortable, but they are temporary and a normal part of "
        "quitting, whether you smoked, vaped or used another nicotine "
        "product.\n\n"
        "The National Cancer Institute lists the most common symptoms as "
        "nicotine cravings; anger, frustration and irritability; difficulty "
        "concentrating; trouble sleeping; restlessness; anxiety; feeling "
        "down; and increased hunger. Less common ones include headaches, "
        "tiredness, dizziness, coughing, mouth ulcers and constipation.\n\n"
        "Symptoms are usually worst during the first week, peaking in the "
        "first 3 days, and then become less intense over the following "
        "weeks. Cravings can start within an hour or two of your last use "
        "and may come often for the first few days or weeks before getting "
        "further apart. Occasional mild cravings can still appear months or "
        "years later, so keep your coping plan handy (NCI).\n\n"
        "What helps: remind yourself that each symptom will pass; stay "
        "active; drink plenty of water, which can ease hunger and tiredness "
        "(Smokefree.gov); cut back on caffeine if you feel tense; and plan "
        "ahead for difficult moments.\n\n"
        "If a symptom is severe, doesn't improve, or worries you, talk to a "
        "doctor or pharmacist. They can explain support and treatment "
        "options that suit you.",
  ),

  // Sources: NCI withdrawal fact sheet; NHS "What could happen when you
  // quit smoking"; Smokefree.gov "Benefits of Quitting Smoking", "How to
  // Stay Quit" and "Nicotine Withdrawal and Vaping". None of the verified
  // sources gives a single clearance time, so none is stated.
  KnowledgeArticle(
    articleId: 'nicotine_after_quitting',
    title: 'How Long Nicotine Affects You After Quitting',
    category: KnowledgeCategory.addictionRecovery,
    icon: Icons.hourglass_bottom_rounded,
    summary:
        'What changes in the hours, days and weeks after your last use, and '
        'why the odd craving can return later.',
    resources: [
      KnowledgeResources.nciWithdrawal,
      KnowledgeResources.nhsWhatHappens,
      KnowledgeResources.sfBenefits,
    ],
    body:
        "A common question is how long nicotine \"stays\" in your body. The "
        "trusted sources used in this app don't give a single figure for "
        "this, and it can vary from person to person, so rather than guess, "
        "here is what they do describe.\n\n"
        "Within hours: the nicotine level in your bloodstream drops when you "
        "stop using it (Smokefree.gov), which is why cravings can start "
        "within an hour or two of your last use (NCI). If you smoked, the "
        "carbon monoxide in your blood halves after 8 hours and reaches "
        "non-smoker levels after 48 hours (NHS).\n\n"
        "Within days: withdrawal symptoms are usually strongest in the first "
        "3 days and through the first week, and then ease (NCI).\n\n"
        "Within about a month: the large number of nicotine receptors that "
        "built up in your brain returns to normal levels after about a month "
        "without smoking (Smokefree.gov).\n\n"
        "Months and years later: occasional mild cravings can still happen, "
        "often set off by triggers such as places, moods or routines linked "
        "with past use. The NCI notes this can happen long after your body is "
        "no longer addicted to nicotine; it is a learned, psychological urge, "
        "and it fades the longer you stay nicotine-free.\n\n"
        "If you need to know about nicotine testing for a medical or work "
        "reason, ask a healthcare professional.",
  ),

  // ===================== Cravings & Relapse Prevention ====================

  // Sources: Smokefree.gov "How to Manage Cravings" and "Dealing With Vape
  // Cravings"; NHS "What could happen when you quit smoking"; NCI
  // withdrawal fact sheet.
  KnowledgeArticle(
    articleId: 'sudden_cravings',
    title: 'How to Manage a Sudden Craving',
    category: KnowledgeCategory.cravingsRelapse,
    icon: Icons.flash_on_rounded,
    summary:
        'A craving always passes. A simple plan for getting through it '
        'without using.',
    resources: [
      KnowledgeResources.sfManageCravings,
      KnowledgeResources.sfVapeCravings,
      KnowledgeResources.nhsWhatHappens,
    ],
    body:
        "Cravings are strong urges to use nicotine, and they're a normal "
        "part of quitting. The most important thing to remember is that a "
        "craving passes. NHS guidance says cravings last up to 15 minutes, "
        "and the National Cancer Institute notes they get further apart the "
        "longer you stay quit.\n\n"
        "When a craving hits, have a plan ready (Smokefree.gov):\n"
        "• Stop what you're doing and switch to something different. Simply "
        "changing your routine can help you shake off the urge.\n"
        "• Keep your mouth busy with sugar-free gum, a hard sweet or a glass "
        "of water.\n"
        "• Take slow, deep breaths: in through your nose, out through your "
        "mouth, 10 times.\n"
        "• Move: a short walk, or up and down the stairs a few times.\n"
        "• Go somewhere you can't smoke or vape, such as a shop or another "
        "public place.\n"
        "• Remind yourself why you're quitting, or add up the money you've "
        "saved so far.\n"
        "• Reach out to someone who supports you.\n\n"
        "For the moment, the only goal is not to use, not even once. The "
        "urge will pass and you keep all the progress you've made. "
        "Afterwards, log the craving in Quit Companion so you can spot "
        "patterns over time.\n\n"
        "If cravings are hard to manage even with these steps, a doctor, "
        "pharmacist or quitline can talk you through support options.",
  ),

  // Sources: Smokefree.gov "How to Manage Cravings", "Mindfulness and
  // Quitting Smoking", "Fight Smoking Cravings with Exercise", "Know Your
  // Smoking Triggers"; NHS "What could happen when you quit smoking"; NCI
  // withdrawal fact sheet.
  KnowledgeArticle(
    articleId: 'five_minute_techniques',
    title: '5-Minute Techniques to Beat a Craving',
    category: KnowledgeCategory.cravingsRelapse,
    icon: Icons.timer_rounded,
    summary:
        'Quick things you can do right now to ride out an urge until it '
        'passes.',
    resources: [
      KnowledgeResources.sfMindfulness,
      KnowledgeResources.sfExerciseCravings,
      KnowledgeResources.sfManageCravings,
    ],
    body:
        "Most cravings are short (NHS guidance says they last up to 15 "
        "minutes), so a few minutes of focused distraction can carry you "
        "through. Try one of these:\n\n"
        "1. Ten slow breaths. Breathe in through your nose and out through "
        "your mouth, ten times, or until you feel calmer.\n\n"
        "2. Ride the wave. Picture the craving as an ocean wave: it builds, "
        "peaks and then gets smaller. Notice how your body feels without "
        "acting on it (Smokefree.gov).\n\n"
        "3. Move for a few minutes. Walk briskly or climb the stairs. "
        "Smokefree.gov reports that cravings and withdrawal symptoms "
        "decrease during exercise and for up to 50 minutes afterwards.\n\n"
        "4. Keep your hands and mouth busy. Chew gum, sip water, crunch on a "
        "carrot or apple, or squeeze a small ball.\n\n"
        "5. Picture a calm place. Close your eyes and imagine somewhere you "
        "feel relaxed, such as a beach or a garden, and what you'd see, hear "
        "and smell there.\n\n"
        "6. Help someone. Doing something kind for a friend, family member "
        "or co-worker takes your focus off the urge.\n\n"
        "7. Read your reasons. Look at your list of reasons for quitting.\n\n"
        "Pick two or three favourites and keep them ready. Quit Companion's "
        "Alternatives screen also suggests activities you can try straight "
        "away.",
  ),

  // Sources: Smokefree.gov "Know Your Smoking Triggers" and "How to Stay
  // Quit"; NCI withdrawal fact sheet.
  KnowledgeArticle(
    articleId: 'personal_triggers',
    title: 'Identifying Your Personal Triggers',
    category: KnowledgeCategory.cravingsRelapse,
    icon: Icons.track_changes_rounded,
    summary: 'The four kinds of triggers, and how to plan for each of yours.',
    resources: [
      KnowledgeResources.sfTriggers,
      KnowledgeResources.nciWithdrawal,
      KnowledgeResources.sfQuitPlan,
    ],
    body:
        "A trigger is anything that sets off the urge to use nicotine: a "
        "stressful moment, a cup of coffee, a party, or the smell of smoke. "
        "Triggers differ from person to person, and knowing yours is one of "
        "the most useful things you can do. Smokefree.gov and the National "
        "Cancer Institute describe four kinds.\n\n"
        "Emotional triggers: strong feelings, good or bad, such as stress, "
        "anxiety, boredom, loneliness, sadness or excitement. Try talking to "
        "someone, slow deep breathing, exercise or calming music.\n\n"
        "Pattern triggers: activities you linked with smoking or vaping, "
        "like starting the day, driving, drinking coffee or tea, finishing a "
        "meal or having an alcoholic drink. Break the link by changing your "
        "routine, for example having coffee at a different time or brushing "
        "your teeth straight after eating, and by keeping your hands busy.\n\n"
        "Social triggers: being around others who smoke or vape, or parties "
        "and social events. Early on, it helps to avoid places where people "
        "smoke, tell friends and family you've quit, and ask for their "
        "support.\n\n"
        "Withdrawal triggers: your body missing nicotine, such as feeling "
        "restless or needing something to do with your hands or mouth. "
        "Distraction and support help here.\n\n"
        "Triggers can appear even years after quitting, so it's worth "
        "writing yours down (Smokefree.gov). Each time you log a craving in "
        "Quit Companion you record its trigger, which helps you see your own "
        "patterns.",
  ),

  // Sources: Smokefree.gov "Smoking Relapse: Get Back on Track" and "How to
  // Stay Quit".
  KnowledgeArticle(
    articleId: 'avoid_relapse',
    title: 'Slips, Relapse and Getting Back on Track',
    category: KnowledgeCategory.cravingsRelapse,
    icon: Icons.replay_rounded,
    summary:
        'Why a slip is not a failure, and practical ways to avoid a full '
        'relapse.',
    resources: [
      KnowledgeResources.sfGetBackOnTrack,
      KnowledgeResources.sfStayQuit,
    ],
    body:
        "Many people try to quit several times before they quit for good, so "
        "setbacks are a normal part of the process, not a sign of "
        "failure.\n\n"
        "If you slip and use nicotine once, Smokefree.gov's advice is to "
        "treat it as a temporary setback and a chance to learn. You haven't "
        "failed and you're not back to square one; be proud of every time "
        "you didn't use. Ask yourself what led to the slip (a place, a "
        "feeling, a person?) and decide what you'll do differently next "
        "time.\n\n"
        "If a slip has turned into using again, restart your quit as soon as "
        "possible: today, or tomorrow at the latest. Think about what helped "
        "while you were nicotine-free, and what pulled you back.\n\n"
        "To lower the risk of relapse:\n"
        "• Know your triggers and have a plan for each.\n"
        "• Keep a short list of things to do when a craving hits.\n"
        "• Stay in touch with people who support you, and tell them how they "
        "can help.\n"
        "• Take it one day at a time, and notice what has improved since you "
        "quit.\n"
        "• Remember that urges fade the longer you go without using.\n\n"
        "If you do relapse, you can record it honestly in Quit Companion; "
        "your history is kept and the app helps you restart your plan.",
  ),

  // Sources: Smokefree.gov "Smoking and Stress", "Coping With Stress
  // Without Smoking", "Stress, Anxiety, and Vaping"; NHS "Stopping
  // smoking for your mental health".
  KnowledgeArticle(
    articleId: 'stress_without_nicotine',
    title: 'Managing Stress Without Nicotine',
    category: KnowledgeCategory.cravingsRelapse,
    icon: Icons.spa_rounded,
    summary:
        'Why nicotine is not a real stress reliever, and healthier ways to '
        'cope.',
    resources: [
      KnowledgeResources.sfStressSmoking,
      KnowledgeResources.sfCopingStress,
      KnowledgeResources.nhsMentalHealth,
    ],
    body:
        "Many people use smoking or vaping to cope with stress, which makes "
        "stress one of the hardest parts of quitting. But nicotine isn't a "
        "real stress reliever. Smokefree.gov points out that it doesn't "
        "solve whatever is causing the stress, and that nicotine addiction "
        "itself causes stress: cravings feel stressful because your body is "
        "going into withdrawal. The NHS explains that the relief people feel "
        "when they smoke mostly comes from easing the craving; smoking "
        "actually increases anxiety and tension.\n\n"
        "Healthier ways to handle stress (Smokefree.gov):\n"
        "• Breathe: a few slow, deep breaths in through your nose and out "
        "through your mouth.\n"
        "• Release tension with a warm bath, stretching or a massage.\n"
        "• Move: a short walk can relieve stress, and walking is free.\n"
        "• Picture a calm, safe place for a few minutes.\n"
        "• Focus on what's happening now, not everything that might come "
        "later.\n"
        "• Look after the basics: balanced meals, plenty of water and enough "
        "sleep.\n"
        "• Cut back on caffeine, which can make you feel tense and "
        "jittery.\n"
        "• Talk to friends or family, or do something kind for someone "
        "else.\n\n"
        "Some of these take practice, so try a few and keep the ones that "
        "work for you. If stress feels overwhelming or constant, talk to a "
        "healthcare professional.",
  ),

  // Sources: Smokefree.gov "Know Your Smoking Triggers", "Build a Plan to
  // Quit Smoking or Vaping", "Fight Smoking Cravings with Exercise"; NCI
  // withdrawal fact sheet; NHS "Get active".
  KnowledgeArticle(
    articleId: 'healthy_habits_alternatives',
    title: 'Building Healthy Habits and Alternatives',
    category: KnowledgeCategory.cravingsRelapse,
    icon: Icons.eco_rounded,
    summary:
        'Swap old nicotine routines for new habits that make quitting '
        'easier to stick with.',
    resources: [
      KnowledgeResources.sfTriggers,
      KnowledgeResources.sfQuitPlan,
      KnowledgeResources.nhsGetActive,
    ],
    body:
        "Quitting isn't only about stopping something. It's about putting "
        "something better in its place. Much nicotine use is tied to "
        "routines, so new habits make the change easier to stick to.\n\n"
        "Replace the ritual. For the moments you used to smoke or vape, such "
        "as after meals, with coffee or on breaks, choose a substitute: chew "
        "sugar-free gum, eat something crunchy like carrots, apples or "
        "celery, or sip water.\n\n"
        "Keep your hands busy. Hold something, squeeze a small ball, or take "
        "up a hobby that uses your hands, such as drawing, beading or "
        "needlework.\n\n"
        "Change the routine. Have your coffee at a different time or in a "
        "different place, brush your teeth right after eating, or take a "
        "short walk during breaks instead.\n\n"
        "Build in activity. Walking, cycling, swimming and dancing help with "
        "cravings, mood and stress. NHS guidance for adults is at least 150 "
        "minutes of moderate activity a week, around 20 to 30 minutes a day, "
        "and some activity is better than none.\n\n"
        "Look after yourself. Regular meals, plenty of water and enough "
        "sleep make cravings easier to handle.\n\n"
        "Quit Companion's Alternatives screen suggests replacement "
        "activities you can try whenever a craving hits.",
  ),

  // ========================== Health & Wellness ==========================

  // Sources: NHS "What could happen when you quit smoking"; Smokefree.gov
  // "Benefits of Quitting Smoking"; CDC "Smoking and COPD" and "Benefits
  // of Quitting Smoking".
  KnowledgeArticle(
    articleId: 'lung_health_recovery',
    title: 'How Quitting Improves Lung Health',
    category: KnowledgeCategory.healthWellness,
    icon: Icons.air_rounded,
    summary:
        'How your lungs clear and recover after quitting, and why a cough '
        'can briefly get worse.',
    resources: [
      KnowledgeResources.nhsWhatHappens,
      KnowledgeResources.sfBenefits,
      KnowledgeResources.cdcCopd,
    ],
    body:
        "Your lungs are one of the first places you can feel the benefit of "
        "quitting.\n\n"
        "In the first days: after 48 hours your lungs start clearing out "
        "mucus, and by 72 hours breathing can feel easier as your bronchial "
        "tubes relax (NHS). The tiny hair-like cilia that sweep mucus and "
        "dirt out of your airways start to regrow and work properly again; "
        "they're one of the first things in the body to heal "
        "(Smokefree.gov).\n\n"
        "A cough can get worse before it gets better. Many people cough more "
        "or notice extra phlegm soon after quitting. It's a sign your lungs "
        "are clearing out, and it is temporary (NHS).\n\n"
        "In the following weeks and months: within about two weeks, walking "
        "up stairs may feel easier because you're less short of breath "
        "(Smokefree.gov). Between 3 and 9 months, coughs, wheezing and "
        "breathing problems improve as lung function increases by up to 10% "
        "(NHS).\n\n"
        "Longer term: quitting slows the progression of COPD and reduces the "
        "loss of lung function over time (CDC). Some damage, such as "
        "scarring, can't be reversed, which is why quitting sooner protects "
        "your lungs more. Healthy cilia also help your body fight off colds "
        "and infections (Smokefree.gov).\n\n"
        "If a cough doesn't improve, or breathing problems worry you, see a "
        "doctor.",
  ),

  // Sources: CDC "Smoking and Heart Disease, Stroke, and Peripheral Artery
  // Disease" and "Benefits of Quitting Smoking"; Smokefree.gov "Benefits
  // of Quitting Smoking"; NHS "What could happen when you quit smoking".
  KnowledgeArticle(
    articleId: 'heart_circulation',
    title: 'Benefits for Your Heart and Circulation',
    category: KnowledgeCategory.healthWellness,
    icon: Icons.favorite_border_rounded,
    summary:
        'How quitting lowers the strain on your heart and improves blood '
        'flow.',
    resources: [
      KnowledgeResources.cdcHeartDisease,
      KnowledgeResources.cdcBenefits,
      KnowledgeResources.sfBenefits,
    ],
    body:
        "Smoking is a major cause of heart disease and stroke. According to "
        "the CDC, it makes blood sticky and more likely to clot, and it "
        "increases the buildup of plaque (fat, cholesterol and other "
        "substances) in your blood vessels. Quitting reverses much of this "
        "strain.\n\n"
        "Almost straight away: within 20 minutes your pulse starts returning "
        "to normal (NHS). Blood pressure and heart rate come down, and your "
        "risk of a heart attack starts to decline within 24 hours "
        "(Smokefree.gov).\n\n"
        "In the following weeks: between 2 and 12 weeks, your circulation "
        "improves, so blood pumps through to your heart and muscles much "
        "better (NHS). Your blood also becomes thinner and less likely to "
        "form dangerous clots, so your heart has less work to do "
        "(Smokefree.gov).\n\n"
        "Over the following years: quitting lowers the cholesterol and fats "
        "circulating in your blood, which slows the buildup of new fatty "
        "deposits in your arteries, although it doesn't remove deposits that "
        "are already there (Smokefree.gov). After a year, your risk of a "
        "heart attack is about half that of a smoker (NHS), and the CDC notes "
        "that the risk of coronary heart disease falls sharply in the first 1 "
        "to 2 years after quitting. People who already have heart disease "
        "also benefit from stopping (CDC).\n\n"
        "If you ever have chest pain or sudden breathlessness, get medical "
        "help immediately.",
  ),

  // Sources: CDC "7 Common Withdrawal Symptoms"; NCI withdrawal fact
  // sheet; Smokefree.gov "Managing Nicotine Withdrawal" and "Nicotine
  // Withdrawal and Vaping".
  KnowledgeArticle(
    articleId: 'sleep_after_quitting',
    title: 'Improving Your Sleep After Quitting',
    category: KnowledgeCategory.healthWellness,
    icon: Icons.bedtime_rounded,
    summary:
        'Why sleep can be disrupted after quitting, and habits that help it '
        'return.',
    resources: [
      KnowledgeResources.cdcWithdrawalSymptoms,
      KnowledgeResources.sfManageWithdrawal,
      KnowledgeResources.sfVapingWithdrawal,
    ],
    body:
        "Trouble sleeping is a common withdrawal symptom when you first quit "
        "(CDC, NCI). It does get better. In the meantime, sleep matters: "
        "Smokefree.gov notes that when you're tired you're less resilient "
        "and may be more likely to slip, so it's worth making sleep a "
        "priority.\n\n"
        "Habits that help:\n"
        "• Go to sleep and wake up around the same time every day, even at "
        "weekends (CDC).\n"
        "• Limit caffeine, alcohol and big meals close to bedtime "
        "(Smokefree.gov).\n"
        "• Turn off screens at least an hour before bed, and keep your phone "
        "out of the bedroom if you can (Smokefree.gov).\n"
        "• Be active during the day; activity helps with mood and stress.\n"
        "• If a craving keeps you awake, try slow, deep breathing until it "
        "passes.\n\n"
        "If sleep problems are really bothering you, or you're exhausted, "
        "talk to your healthcare provider (CDC). If you use a quit-smoking "
        "medicine and think it is affecting your sleep, ask your healthcare "
        "provider or pharmacist for advice rather than changing how you use "
        "it on your own.",
  ),

  // Sources: NHS "Stopping smoking for your mental health"; NCI withdrawal
  // fact sheet; Smokefree.gov "Boost Your Mood" and "Smoking & Depression";
  // CDC "Mental Health Conditions: Depression and Anxiety".
  KnowledgeArticle(
    articleId: 'mental_health_recovery',
    title: 'Mental Health and Nicotine Recovery',
    category: KnowledgeCategory.healthWellness,
    icon: Icons.sentiment_satisfied_alt_rounded,
    summary:
        'Quitting can improve mood and anxiety. What to expect, and when to '
        'seek help.',
    resources: [
      KnowledgeResources.nhsMentalHealth,
      KnowledgeResources.cdcDepressionAnxiety,
      KnowledgeResources.sfBoostMood,
      KnowledgeResources.sfDepression,
    ],
    body:
        "It's a common belief that smoking helps people relax. In fact, the "
        "NHS explains that smoking increases anxiety and tension: when you "
        "haven't had nicotine for a while, the craving makes you feel "
        "irritable and anxious, and using again only relieves that feeling "
        "for a short time.\n\n"
        "Stopping can be good for your mental health. According to the NHS, "
        "quitting can improve mood and help relieve stress, anxiety and "
        "depression, and people with mental health conditions are likely to "
        "feel calmer and more positive, with a better quality of life, after "
        "stopping. The NHS adds that evidence suggests the benefit of "
        "stopping on anxiety and depression can equal that of taking "
        "antidepressants.\n\n"
        "The first weeks can be bumpy. It's common to feel sad for a while "
        "soon after quitting. If mild low mood happens, the National Cancer "
        "Institute says it usually starts within the first day, continues "
        "for a couple of weeks and goes away within a month. People with a "
        "history of depression can have stronger withdrawal symptoms, so plan "
        "extra support.\n\n"
        "What helps: regular physical activity, staying in touch with "
        "people, doing things you enjoy, and rewarding yourself for progress "
        "(Smokefree.gov).\n\n"
        "If you take medicine for a mental health condition, tell your doctor "
        "or pharmacist that you're quitting; the NHS notes that smoking "
        "affects how some of these medicines work, so your treatment may "
        "need reviewing. If low mood lasts or you have thoughts of harming "
        "yourself, contact a healthcare professional straight away. Quit "
        "Companion's Crisis Support screen lists helplines.",
  ),

  // Sources: Smokefree.gov "Fight Smoking Cravings with Exercise", "How
  // Smoking Affects Your Workout", "Nutrition & Appetite While Quitting",
  // "Manage Weight Gain After Quitting"; NHS "Get active" and "What could
  // happen when you quit smoking"; NCI withdrawal fact sheet.
  KnowledgeArticle(
    articleId: 'exercise_nutrition',
    title: 'Exercise and Nutrition During Recovery',
    category: KnowledgeCategory.healthWellness,
    icon: Icons.directions_run_rounded,
    summary:
        'How activity eases cravings, and how to handle a bigger appetite '
        'after quitting.',
    resources: [
      KnowledgeResources.sfExerciseCravings,
      KnowledgeResources.sfNutrition,
      KnowledgeResources.sfWeightGain,
      KnowledgeResources.nhsGetActive,
    ],
    body:
        "Physical activity and good food are two of the most useful tools "
        "while you quit.\n\n"
        "Exercise. Even short periods of activity, especially aerobic "
        "exercise that makes you breathe harder, reduce the urge to smoke, "
        "and cravings and withdrawal symptoms decrease during exercise and "
        "for up to 50 minutes afterwards (Smokefree.gov). Exercise also "
        "lifts your mood and helps limit weight gain. Aim for 30 minutes on "
        "most days, or three 10-minute sessions, which give the same benefit "
        "(Smokefree.gov). NHS guidance for adults is at least 150 minutes of "
        "moderate activity a week. Walking, cycling, swimming, dancing, "
        "yoga, gardening and housework all count. As your circulation and "
        "lungs recover, you may find activity gets easier.\n\n"
        "Nutrition. A bigger appetite is a common withdrawal symptom and "
        "tends to last longer than others. Your senses of taste and smell "
        "also improve, so food becomes more enjoyable, and many people want "
        "more sweet and fatty foods (Smokefree.gov). Some weight gain is "
        "common; the National Cancer Institute notes it is usually less than "
        "10 pounds (about 4.5 kg), and the health benefits of quitting far "
        "outweigh the risks of a small amount of extra weight.\n\n"
        "To stay in control: eat balanced meals with fruit, vegetables and "
        "wholegrains (NHS); watch portion sizes; drink plenty of water; keep "
        "healthy snacks to hand; and check whether you're really hungry or "
        "eating out of stress or boredom (Smokefree.gov).\n\n"
        "If you have a health condition, check with a healthcare "
        "professional before starting a new exercise plan.",
  ),

  // Sources: NCI withdrawal fact sheet; Smokefree.gov "Anxiety & Smoking"
  // and "Know Your Smoking Triggers".
  KnowledgeArticle(
    articleId: 'anxiety_irritability',
    title: 'Managing Anxiety and Irritability During Withdrawal',
    category: KnowledgeCategory.healthWellness,
    icon: Icons.self_improvement_rounded,
    summary:
        'Why you may feel tense or short-tempered after quitting, and what '
        'helps.',
    resources: [KnowledgeResources.nciWithdrawal, KnowledgeResources.sfAnxiety],
    body:
        "Feeling edgy, short-tempered or anxious is very common after "
        "quitting. The National Cancer Institute reports that anger, "
        "frustration and irritability are the most common negative feelings "
        "linked to quitting; they usually peak within the first week and may "
        "last 2 to 4 weeks. Anxiety can start within 24 hours: you may feel "
        "tense, with tight muscles around your neck and shoulders.\n\n"
        "These feelings are part of withdrawal, not a permanent change in "
        "who you are, and they pass with time.\n\n"
        "What helps (NCI):\n"
        "• Remind yourself that the feelings are temporary.\n"
        "• Do something active that you enjoy, such as going for a walk.\n"
        "• Cut down on caffeine from coffee, tea and fizzy drinks.\n"
        "• Set aside some quiet time each morning and evening.\n"
        "• Try relaxation: breathe in through your nose and out through your "
        "mouth for 10 breaths, have a warm bath, or try meditation.\n"
        "• Tell the people around you that you've quit and ask for their "
        "support, so they understand if you're on edge (Smokefree.gov).\n\n"
        "If anxiety is severe, keeps getting worse, or stops you doing "
        "everyday things, talk to a healthcare professional. Support and "
        "treatment are available.",
  ),

  // ======================== Motivation & Lifestyle ========================

  // Sources: Smokefree.gov "Why Do You Want to Quit Smoking?", "How to Stay
  // Quit", "Reasons to Quit Smoking".
  KnowledgeArticle(
    articleId: 'stay_motivated',
    title: 'How to Stay Motivated',
    category: KnowledgeCategory.motivationLifestyle,
    icon: Icons.local_fire_department_rounded,
    summary:
        'Keep your motivation going with clear reasons, support and '
        'visible progress.',
    resources: [
      KnowledgeResources.sfWhyQuit,
      KnowledgeResources.sfStayQuit,
      KnowledgeResources.sfReasonsToQuit,
    ],
    body:
        "Motivation naturally rises and falls, especially when cravings hit. "
        "A few habits help keep it going.\n\n"
        "Know your reasons, and look at them often. Smokefree.gov suggests "
        "writing down why you're quitting and reminding yourself every day. "
        "Common reasons include better health, saving money, protecting "
        "family and friends from secondhand smoke, setting a good example, "
        "and no longer having to plan your day around when you can next "
        "smoke or vape.\n\n"
        "Take it one day at a time. The first hours, days and weeks are the "
        "hardest, so focus on getting through today without nicotine.\n\n"
        "Notice what's better. Reflect on what has improved since you quit: "
        "easier breathing, better taste and smell, more energy, more money, "
        "or more time with people you care about.\n\n"
        "Remember the health timeline. Your body starts recovering within "
        "minutes of your last cigarette, and the benefits keep building for "
        "years.\n\n"
        "Lean on support. Friends and family can make a big difference, so "
        "tell them how they can help.\n\n"
        "Reward yourself for progress with things you enjoy.\n\n"
        "In Quit Companion, your dashboard shows your progress, savings and "
        "rewards. A quick look can be a powerful reminder of how far you've "
        "come.",
  ),

  // Sources: Smokefree.gov "Build a Plan to Quit Smoking or Vaping" and
  // "Smoking Relapse: Get Back on Track".
  KnowledgeArticle(
    articleId: 'quit_goals',
    title: 'Setting Achievable Quitting Goals',
    category: KnowledgeCategory.motivationLifestyle,
    icon: Icons.flag_rounded,
    summary:
        'Turn quitting into clear, realistic steps, starting with your quit '
        'day.',
    resources: [
      KnowledgeResources.sfQuitPlan,
      KnowledgeResources.sfGettingStarted,
    ],
    body:
        "Clear, realistic goals make quitting feel manageable.\n\n"
        "Pick a quit date. Smokefree.gov suggests choosing a day within the "
        "next two weeks, which gives you time to prepare, and avoiding a date "
        "that's likely to be stressful.\n\n"
        "Write down your reasons. Knowing why you want to quit keeps you on "
        "track in difficult moments.\n\n"
        "Plan for your triggers. List the places, situations and feelings "
        "that make you want to use nicotine, and choose a strategy for "
        "each.\n\n"
        "Choose your support. Decide who you'll turn to, how you'll get "
        "expert help (for example from a doctor, pharmacist or quitline), and "
        "how you'll distract yourself when cravings hit.\n\n"
        "Keep each day's goal simple. On your quit day, the most important "
        "thing is not to smoke or vape, not even once. After that, take it "
        "one day at a time.\n\n"
        "Set milestone goals. Think in steps (your first day, first week, "
        "first month) and recognise each one.\n\n"
        "Be kind to yourself. If you slip, learn from it and return to your "
        "goal as soon as possible; most people need more than one try.\n\n"
        "Quit Companion's plan and dashboard track your progress from your "
        "quit date, so you can see each milestone as you reach it.",
  ),

  // Sources: Smokefree.gov "Build a Plan to Quit Smoking or Vaping", "How
  // to Stay Quit", "Nutrition & Appetite While Quitting".
  KnowledgeArticle(
    articleId: 'celebrate_milestones',
    title: 'Celebrating Recovery Milestones',
    category: KnowledgeCategory.motivationLifestyle,
    icon: Icons.celebration_rounded,
    summary:
        'Why rewarding your progress matters, and ideas for celebrating '
        'without nicotine.',
    resources: [KnowledgeResources.sfQuitPlan, KnowledgeResources.sfStayQuit],
    body:
        "Quitting is hard work, so celebrate your progress along the way. "
        "Smokefree.gov points out that bad moods, poor sleep and strong "
        "cravings are part of quitting, which is why it's important to "
        "celebrate your successes, big or small. Rewarding yourself with "
        "something positive helps keep you motivated.\n\n"
        "Ideas for celebrating:\n"
        "• Mark your first day, first week and first month nicotine-free, "
        "then your monthly and yearly anniversaries, and include the people "
        "who supported you.\n"
        "• Use the money you would have spent on cigarettes or vapes to "
        "treat yourself to something you enjoy.\n"
        "• Do something your body can now do more easily, like a hike or a "
        "longer walk.\n"
        "• Plan a fun evening with friends, such as a movie night.\n"
        "• Write down what has improved since you quit, and read it back on "
        "hard days.\n\n"
        "Choose rewards that don't involve nicotine. Many people find food "
        "becomes a way to reward themselves after quitting (Smokefree.gov), "
        "so try to mix in other treats too.\n\n"
        "Quit Companion awards badges at nicotine-free milestones, from your "
        "first day up to one year, and shows your points on the Rewards "
        "screen.",
  ),

  // Sources: Smokefree.gov "Quit Smoking Savings Calculator", "How to
  // Manage Cravings", "How to Stay Quit"; WHO "Tobacco and nicotine" fact
  // sheet. No price or savings figures are stated: they vary by country
  // and by person, and the app calculates the user's own.
  KnowledgeArticle(
    articleId: 'financial_benefits',
    title: 'The Financial Benefits of Quitting',
    category: KnowledgeCategory.motivationLifestyle,
    icon: Icons.savings_rounded,
    summary:
        'See how much you save by quitting, and make that money work as '
        'motivation.',
    resources: [KnowledgeResources.sfSavings, KnowledgeResources.whoTobacco],
    body:
        "Nicotine products are expensive, and the cost adds up quickly. When "
        "you quit, that money stays with you.\n\n"
        "How much you save depends on how much you used and what you paid, "
        "so the most accurate figure is your own. Quit Companion works out "
        "your savings from the usage and cost you entered when you set up "
        "your plan, and shows the total on your dashboard. Smokefree.gov "
        "also has a savings calculator that estimates savings over days, "
        "weeks, months and years.\n\n"
        "Make the savings work for you:\n"
        "• Decide what the money is for: a treat, a trip, a gift or a "
        "savings goal.\n"
        "• Check your savings when a craving hits. Adding up the money you've "
        "kept is a good way to pass a few minutes until the urge goes "
        "(Smokefree.gov).\n"
        "• Use part of your savings to reward yourself at milestones.\n\n"
        "The benefit can reach the whole household. The World Health "
        "Organization notes that tobacco use diverts household spending away "
        "from basic needs such as food and shelter, so quitting frees up "
        "money for the things that matter to you and your family.",
  ),

  // Sources: Smokefree.gov "How to Stay Quit" and "How to Manage Cravings";
  // NCI withdrawal fact sheet; WHO "Tobacco and nicotine" fact sheet; NHS
  // "Using e-cigarettes to stop smoking"; CDC "Health Problems Caused by
  // Secondhand Smoke".
  KnowledgeArticle(
    articleId: 'nicotine_free_lifestyle',
    title: 'Creating a Nicotine-Free Lifestyle',
    category: KnowledgeCategory.motivationLifestyle,
    icon: Icons.wb_sunny_rounded,
    summary: 'Long-term habits that help you stay nicotine-free for good.',
    resources: [
      KnowledgeResources.sfStayQuit,
      KnowledgeResources.whoTobacco,
      KnowledgeResources.nhsECigarettes,
    ],
    body:
        "Staying nicotine-free for the long term is about building a life "
        "where nicotine no longer has a role.\n\n"
        "Expect triggers to fade, not vanish. Certain people, places and "
        "situations can trigger an urge even years after quitting "
        "(Smokefree.gov). Keep your plan for cravings handy, even when you "
        "feel confident.\n\n"
        "Keep your surroundings nicotine-free. Don't buy, carry, light or "
        "hold cigarettes for others (NCI), and keep your home and car "
        "smoke-free, which also protects the people you live with from "
        "secondhand smoke.\n\n"
        "Build new routines. Fill the times you used to smoke or vape with "
        "activities you enjoy, especially ones that keep you active and "
        "around supportive people.\n\n"
        "Look after the basics. Regular activity, balanced meals, enough "
        "sleep and healthy ways to handle stress make urges easier to "
        "manage.\n\n"
        "Stay connected. Talk to the people who supported you when you first "
        "quit, and look for new support if you need it (Smokefree.gov).\n\n"
        "Be wary of \"just one\". Smokefree.gov's advice while quitting is "
        "not even one puff. WHO describes nicotine as highly addictive, and "
        "newer products such as nicotine pouches as having high addiction "
        "potential. If you're using a nicotine product such as nicotine "
        "replacement or an e-cigarette to help you stop smoking, follow a "
        "plan agreed with a healthcare professional or stop-smoking "
        "service (NHS).",
  ),
];

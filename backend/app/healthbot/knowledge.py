"""Retrieval-augmented generation (RAG) for the Health-Bot.

The knowledge base is the 32 reviewed topics in service.KNOWLEDGE_BASE plus the
conversational entries below. Every medical statement in the new entries was
taken from the linked public-health page itself (read on 2026-11-26); the
pages were confirmed live on 2026-11-25. No model is trained here.

`retrieve()` finds the entries most relevant to a question so Gemini answers
from vetted facts. It uses character n-gram TF-IDF similarity, which matches
pieces of words rather than whole words, so misspellings ("withdrawl",
"nicotin", "cigrette") and paraphrases still find the right entry. It runs
locally in microseconds; no external calls.
"""
from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache

from .service import KNOWLEDGE_BASE
from .sources import (
    CDC_BENEFITS,
    CDC_NICOTINE_POUCHES,
    CDC_TIPS,
    CDC_VAPING_HEALTH,
    NCI_HARMS_AND_BENEFITS,
    NCI_WITHDRAWAL,
    NHS_ECIGARETTES,
    NHS_MENTAL_HEALTH,
    NHS_WHAT_HAPPENS,
    SMOKEFREE_CRAVINGS,
    SMOKEFREE_NUTRITION,
    SMOKEFREE_QUIT_PLAN,
    SMOKEFREE_SETBACK,
    SMOKEFREE_STRESS,
    SMOKEFREE_TRIGGERS,
    SMOKEFREE_WITHDRAWAL,
    TOPIC_SOURCES,
    WHO_CESSATION_BENEFITS,
    TrustedSource,
)


@dataclass(frozen=True)
class KnowledgeEntry:
    id: str
    title: str
    text: str
    sources: tuple[TrustedSource, ...]
    keywords: tuple[str, ...] = ()


#: Conversational knowledge added for open-ended questions (time-based,
#: comparisons, plans, food, stress, slips). Facts are attributed in the text
#: so the model can say where they come from.
CONVERSATIONAL_KNOWLEDGE: tuple[KnowledgeEntry, ...] = (
    KnowledgeEntry(
        "recovery_timeline",
        "What happens in the body after quitting (recovery timeline)",
        "Recovery starts quickly. Within 20 minutes heart rate and blood pressure drop (WHO). "
        "After about 8 hours the carbon monoxide in the blood has halved, and after 48 hours it is "
        "at a non-smoker's level; taste and smell also start to improve (NHS). After 72 hours "
        "breathing may feel easier because the airways (bronchial tubes) start to relax (NHS). "
        "Over 2-12 weeks circulation improves and lung function increases (WHO). Between 1 and 9 "
        "months coughing and shortness of breath decrease (WHO), and within 3-9 months lung "
        "function can increase by up to 10% (NHS). After 1 year the risk of coronary heart "
        "disease is about half that of a smoker; after 10 years the risk of lung cancer falls to "
        "about half that of a smoker; after 15 years the risk of coronary heart disease is that "
        "of a non-smoker (WHO). These are typical milestones, and recovery differs from person "
        "to person.",
        (WHO_CESSATION_BENEFITS, NHS_WHAT_HAPPENS, CDC_BENEFITS),
        ("lungs recover", "lungs heal", "body heal", "timeline", "what happens when I quit",
         "health benefits", "heart", "how long until", "after quitting"),
    ),
    KnowledgeEntry(
        "withdrawal_timeline",
        "How long nicotine withdrawal lasts and when you feel normal again",
        "Cravings can start within an hour or two after the last use and may come often for the "
        "next few days or weeks. Withdrawal symptoms are usually worst during the first week, "
        "peaking during the first 3 days; negative feelings such as irritability and low mood "
        "peak within a week and may last 2 to 4 weeks (NCI). After that most people feel much "
        "more like themselves, although occasional mild cravings can appear months or even years "
        "later, often around old triggers. Everyone is different: some people have withdrawal "
        "symptoms for several months, especially after heavy use for many years (NCI).",
        (NCI_WITHDRAWAL, SMOKEFREE_WITHDRAWAL),
        ("how long does withdrawal last", "when will I feel normal", "how many days",
         "first week", "withdrawal timeline", "get easier", "feel better", "feel awful",
         "feel terrible", "feel so bad", "worst day", "will tomorrow be better"),
    ),
    KnowledgeEntry(
        "craving_duration",
        "How long a single craving lasts and how to ride it out",
        "A single craving does not last forever: NCI suggests telling yourself the urge will go "
        "away in a few minutes, and the NHS notes that cravings last up to about 15 minutes. "
        "Have go-to distractions ready, such as chewing gum, a short walk, or doing something "
        "helpful for someone for a few minutes (Smokefree.gov). The moment passes and the "
        "progress you have made stays.",
        (SMOKEFREE_CRAVINGS, NHS_WHAT_HAPPENS, NCI_WITHDRAWAL),
        ("how long does a craving last", "urge", "craving right now", "beat a craving",
         "ride it out", "distract"),
    ),
    KnowledgeEntry(
        "slip_after_quitting",
        "Smoking or vaping once after being nicotine-free (a slip)",
        "Having one cigarette or vape after days or weeks off nicotine is a slip, not a failure. "
        "Smokefree.gov says a slip is a temporary setback and an opportunity to learn, and "
        "encourages you to be proud of all the cigarettes you did not smoke. Work out what "
        "triggered it (for example stress, alcohol or being around smokers), plan what you will "
        "do next time, and recommit right away rather than treating it as a reason to keep "
        "using. The time you stayed nicotine-free still counts.",
        (SMOKEFREE_SETBACK,),
        ("smoked one cigarette", "had one cigarette", "one puff", "slipped", "slip",
         "after 30 days", "after a month", "relapse", "smoked again"),
    ),
    KnowledgeEntry(
        "nicotine_and_brain",
        "Why nicotine is addictive and how it affects the brain",
        "Nicotine is the drug mainly responsible for addiction to tobacco products (NCI). It is "
        "absorbed through the lining of the mouth and the lungs and reaches the brain in a "
        "matter of seconds (NCI), where it acts on the brain's reward system, so the brain learns "
        "to want it again. NCI notes that this addiction is similar to the addiction produced by "
        "drugs such as heroin and cocaine. When nicotine levels drop, the body goes through "
        "withdrawal and cravings appear; after quitting, the brain gradually adjusts, which is "
        "why cravings become weaker and less frequent over time. While nicotine is the addictive "
        "substance in cigarettes and can be harmful in high doses, most of the harm from smoking "
        "comes from the thousands of other chemicals in tobacco smoke, many of which are toxic "
        "(NHS).",
        (NCI_HARMS_AND_BENEFITS, NCI_WITHDRAWAL, NHS_ECIGARETTES),
        ("brain", "addictive", "why is nicotine addictive", "dopamine", "how does nicotine work",
         "addiction", "is nicotine harmful", "does nicotine cause cancer"),
    ),
    KnowledgeEntry(
        "smoking_vs_vaping",
        "Differences between smoking and vaping",
        "Cigarettes burn tobacco and produce smoke containing tar and carbon monoxide. "
        "E-cigarettes heat a liquid that typically contains nicotine, propylene glycol, vegetable "
        "glycerine and flavourings to make an aerosol; they do not burn tobacco and do not "
        "produce tar or carbon monoxide (NHS). The NHS says vapes are likely to be far less "
        "harmful than cigarettes and can help adults stop smoking. The CDC stresses that no "
        "tobacco products, including e-cigarettes, are safe: most vapes contain nicotine, which "
        "is highly addictive, the aerosol can contain harmful substances, and e-cigarettes "
        "should not be used by youth, young adults or pregnant women; nicotine is toxic to "
        "developing fetuses and is a health danger for pregnant women (CDC). The NHS adds that "
        "vaping is not completely risk-free and its long-term risks are not yet clear. Both keep "
        "nicotine addiction going, so being free of both is the healthiest goal.",
        (NHS_ECIGARETTES, CDC_VAPING_HEALTH),
        ("difference between smoking and vaping", "vaping vs smoking", "is vaping safer",
         "e-cigarette", "vape", "vaping", "safer than smoking", "pregnant", "pregnancy"),
    ),
    KnowledgeEntry(
        "hookah_and_other_tobacco",
        "Hookah (shisha) and other tobacco products",
        "All forms of tobacco are harmful and addictive (NCI). Some people think hookah smoking "
        "is less harmful and addictive than cigarette smoking, but research shows hookah smoke "
        "is at least as toxic as cigarette smoke (NCI). Quitting hookah brings the same kind of "
        "withdrawal and the same coping strategies apply.",
        (NCI_HARMS_AND_BENEFITS,),
        ("hookah", "shisha", "sheesha", "waterpipe", "smokeless", "chewing tobacco",
         "other tobacco"),
    ),
    KnowledgeEntry(
        "food_and_cravings",
        "What to eat while quitting and food for cravings",
        "After quitting, food likes and dislikes can change, and studies show people want more "
        "sweet and fatty foods, which are usually high in calories (Smokefree.gov). Because "
        "snacking can replace the hand-to-mouth habit, choose healthy crunchy options such as "
        "carrots and celery, or sugar-free mints (Smokefree.gov). Taste and smell improve within "
        "about 48 hours of quitting, so food may taste nicer and you could feel hungrier (NHS). "
        "Planning snacks and regular meals in advance helps you stay in control of food choices "
        "and avoid overeating.",
        (SMOKEFREE_NUTRITION, NHS_WHAT_HAPPENS),
        ("what should I eat", "food", "diet", "snack", "eat", "weight gain", "sugar", "hungry",
         "nutrition"),
    ),
    KnowledgeEntry(
        "stress_and_mood",
        "Stress, anxiety and mood while quitting",
        "Smoking can feel calming, but it is not a long-term stress reliever: nicotine addiction "
        "itself causes stress, and cravings feel stressful because the body is going through "
        "withdrawal (Smokefree.gov). The NHS says smoking actually increases anxiety and "
        "tension, and that stopping improves mood and helps relieve stress, anxiety and "
        "depression; evidence suggests this benefit can equal that of taking antidepressants. "
        "In the moment, a short walk or a relaxation exercise works better than a cigarette "
        "(Smokefree.gov). Anyone taking antidepressants or antipsychotic medicines should talk "
        "to their doctor before stopping smoking (NHS).",
        (SMOKEFREE_STRESS, NHS_MENTAL_HEALTH),
        ("stressed", "stress", "anxiety", "anxious", "depressed", "low mood", "calm", "tense",
         "overwhelmed", "help me"),
    ),
    KnowledgeEntry(
        "quick_calming_steps",
        "Quick steps to get through a craving or stressful moment",
        "When an urge or stress hits, give it a few minutes: delay acting on it, take slow deep "
        "breaths, drink some water, and do something else, such as a short walk, chewing gum, "
        "messaging a friend or a quick task (Smokefree.gov, NCI). Remind yourself the urge will "
        "pass. In Quit Companion you can log the craving to get suggested alternatives, or try "
        "the breathing game.",
        (SMOKEFREE_CRAVINGS, NCI_WITHDRAWAL),
        ("help me right now", "calm down", "what do I do now", "about to smoke",
         "craving now", "breathing exercise"),
    ),
    KnowledgeEntry(
        "making_a_quit_plan",
        "Building a quit or recovery plan",
        "A personal quit plan makes it easier to stay on track and quit for good (Smokefree.gov). "
        "Useful parts of a plan: choose a quit date within the next two weeks; know your "
        "triggers and what you will do instead; tell people important to you and ask someone "
        "who has quit for support; get expert help where you can; and prepare distractions for "
        "when an urge comes (Smokefree.gov). Removing cigarettes or vapes from home, car and bag "
        "and rewarding milestones also help. In Quit Companion, the Weekly Plan, Log Craving and "
        "Journal features support a plan day by day.",
        (SMOKEFREE_QUIT_PLAN, CDC_TIPS),
        ("plan", "7-day plan", "7 day plan", "week plan", "quit plan", "recovery plan",
         "routine", "schedule", "step by step"),
    ),
    KnowledgeEntry(
        "nicotine_pouches",
        "Nicotine pouches",
        "Nicotine pouches are small pouches with a powder made of nicotine, flavourings and other "
        "ingredients; people put them between the lip and gum, where the nicotine is absorbed (CDC). "
        "They do not contain tobacco leaf, but they can contain high levels of nicotine, which is "
        "highly addictive. The CDC says there are no safe tobacco products, including nicotine "
        "pouches, and scientists are still learning about their short- and long-term health "
        "effects. Youth, young adults and pregnant women should not use them, and nicotine can harm "
        "brain development, which continues until about age 25 (CDC). The FDA has not approved "
        "nicotine pouches as a quit-smoking aid (CDC). Stopping pouches brings the same kind of "
        "nicotine withdrawal as other products, and the same coping strategies help.",
        (CDC_NICOTINE_POUCHES,),
        ("pouch", "pouches", "nicotine pouch", "zyn", "velo", "snus", "lip pouch",
         "are pouches safe"),
    ),
    KnowledgeEntry(
        "low_mood_after_quitting",
        "Feeling low, sad or empty after quitting",
        "It is common to feel sad for a period of time soon after quitting. If mild low mood "
        "happens, it usually begins within the first day, continues for a couple of weeks and goes "
        "away within a month; people with a history of depression often have stronger withdrawal "
        "symptoms, including low mood (NCI). Things that help: get together with a friend; notice "
        "whether you are actually tired, lonely, bored or hungry and deal with that need; do "
        "physical activities you enjoy; breathe deeply; and write down what is upsetting you and "
        "possible solutions (NCI). Over time, stopping smoking improves mood and lowers anxiety and "
        "stress (NHS). If low mood is severe, does not lift, or comes with thoughts of self-harm, "
        "talk to a doctor or a helpline straight away.",
        (NCI_WITHDRAWAL, NHS_MENTAL_HEALTH),
        ("feel low", "sad", "empty", "feeling down", "depressed", "lonely", "crying", "unhappy",
         "no joy", "hopeless"),
    ),
    KnowledgeEntry(
        "withdrawal_symptoms_list",
        "Which symptoms are part of nicotine withdrawal",
        "Common nicotine withdrawal symptoms are cravings; anger, frustration and irritability; "
        "difficulty concentrating; trouble sleeping; restlessness; anxiety; low mood; and hunger "
        "or increased appetite. Less common ones include headaches, tiredness, dizziness, coughing, "
        "mouth ulcers and constipation (NCI). A symptom that is not on these lists may have another "
        "cause, so anything new, severe or long-lasting is worth checking with a doctor.",
        (NCI_WITHDRAWAL, SMOKEFREE_WITHDRAWAL),
        ("symptoms", "withdrawal symptoms", "side effects", "is this from quitting",
         "because of quitting", "shaking", "shaky", "trembling", "tremor", "strange feeling"),
    ),
    KnowledgeEntry(
        "encouragement_and_benefits",
        "Encouragement: what quitting gives you",
        "Quitting brings benefits at any age. Compared with people who keep smoking, those who quit "
        "at about 30 gain almost 10 years of life expectancy, at about 40 about 9 years, at about 50 "
        "about 6 years and at about 60 about 3 years (WHO). After 1 year the risk of a heart attack "
        "is about half that of a smoker (NHS). Benefits start fast: within 48 hours carbon monoxide "
        "is down to a non-smoker's level and taste and smell start to improve (NHS). Every "
        "nicotine-free day counts, and each craving you ride out makes the next one easier.",
        (WHO_CESSATION_BENEFITS, NHS_WHAT_HAPPENS),
        ("motivate", "motivating", "motivation", "inspire me", "encourage me", "why quit",
         "benefits of quitting", "is it worth it", "something positive", "keep going"),
    ),
    KnowledgeEntry(
        "app_features",
        "Quit Companion features that can help",
        "Quit Companion includes: a Dashboard showing nicotine-free days, money saved (worked out "
        "from your usual daily use and cost per unit) and a health recovery timeline; Log Craving "
        "(records a craving and gives a relapse-risk score with suggested alternatives); Alternatives and mini-games such as a breathing game, a "
        "private Journal, a Community for peer support, a Knowledge Hub of articles and videos "
        "from WHO, CDC, NHS and Smokefree.gov, a Weekly Plan, Rewards and badges, Reminders, "
        "and Crisis Support with helplines such as Rescue 1122 and Umang Pakistan.",
        (),
        ("app", "feature", "what can this app do", "game", "journal", "community", "helpline",
         "reminder", "money", "save money", "savings", "how much money", "dashboard"),
    ),
)


#: Extra search words for the reviewed topics (retrieval only; their reviewed
#: texts are unchanged). Everyday wording people actually use.
RETRIEVAL_SYNONYMS: dict[str, tuple[str, ...]] = {
    "fatigue": ("tired", "tiredness", "sleepy all day", "exhausted", "no energy"),
    "irritability": ("angry", "anger", "irritated", "short-tempered", "frustrated", "mood swings"),
    "breathing_improvement": ("chest feels tight", "tight chest", "breathless", "hard to breathe",
                              "lungs"),
    "concentration": ("can't focus", "brain fog", "forgetful"),
    "appetite": ("eating a lot", "gaining weight", "hungry all the time"),
    "motivation": ("motivate me", "motivating", "inspire me", "encourage me", "want to give up"),
    "sleep": ("can't sleep", "insomnia", "waking at night", "bad dreams"),
    "avoiding_triggers": ("after eating", "after meals", "after food", "with tea", "routine",
                          "habit"),
    "exercise_while_quitting": ("running", "go for a run", "gym", "sport", "jogging"),
    "oral_fixation": ("chew gum", "chewing gum", "gum", "mints", "toothpick"),
    "secondhand_exposure": ("smokes inside", "smoking at home", "smoke in the house",
                            "partner smokes"),
    "social_pressure": ("friends offer", "party", "wedding", "everyone smokes"),
}


def _topic_title(topic: str) -> str:
    return topic.replace("_", " ").capitalize()


def all_entries() -> tuple[KnowledgeEntry, ...]:
    """The 32 reviewed topics plus the conversational entries."""
    reviewed = tuple(
        KnowledgeEntry(topic, _topic_title(topic), text, TOPIC_SOURCES.get(topic, ()),
                       tuple(keywords) + RETRIEVAL_SYNONYMS.get(topic, ()))
        for topic, keywords, text in KNOWLEDGE_BASE
    )
    return reviewed + CONVERSATIONAL_KNOWLEDGE


@lru_cache(maxsize=1)
def _index():
    from sklearn.feature_extraction.text import TfidfVectorizer

    entries = all_entries()
    # Title and keywords repeated so they weigh more than the long text.
    documents = [
        f"{e.title}. {e.title}. {' | '.join(e.keywords)}. {' | '.join(e.keywords)}. {e.text}"
        for e in entries
    ]
    vectorizer = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), sublinear_tf=True)
    matrix = vectorizer.fit_transform(documents)
    return entries, vectorizer, matrix


#: Filler words removed from the question before searching, so short
#: questions are matched on their meaningful words ("tired", "angry").
_FILLER = frozenset(
    "a an the i im i'm am is are was were be been my me you your we us it its this that these those "
    "and or but so of to in on at for with about from as can could would should will do does did "
    "please tell what why how when which who feel feeling get getting really very just".split()
)


def _focus(text: str) -> str:
    words = [w for w in text.lower().replace("?", " ").replace(".", " ").replace(",", " ").split()
             if w not in _FILLER]
    return " ".join(words) or text


#: Minimum similarity for an entry to be used, and the share of the best score
#: an entry must reach to be included alongside it (keeps the notes focused).
MIN_SCORE = 0.17
RELATIVE_CUTOFF = 0.5


def retrieve(
    query: str, *, context: str = "", limit: int = 4
) -> list[tuple[KnowledgeEntry, float]]:
    """Most relevant entries for `query`, best first, with their scores.

    `context` (the previous user message) helps follow-ups such as "what
    about vaping?" find the right topic; it counts half as much as the query.
    """
    entries, vectorizer, matrix = _index()
    scores = (matrix @ vectorizer.transform([_focus(query)]).T).toarray().ravel()
    if context.strip():
        scores = scores + 0.5 * (matrix @ vectorizer.transform([_focus(context)]).T).toarray().ravel()
    ranked = sorted(range(len(entries)), key=lambda i: scores[i], reverse=True)
    if not ranked or scores[ranked[0]] < MIN_SCORE:
        return []
    cutoff = max(MIN_SCORE, RELATIVE_CUTOFF * scores[ranked[0]])
    return [(entries[i], float(scores[i])) for i in ranked[:limit] if scores[i] >= cutoff]


def entry_by_id(entry_id: str) -> KnowledgeEntry | None:
    return next((e for e in all_entries() if e.id == entry_id), None)

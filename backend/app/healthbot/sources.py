"""Topic-specific trusted sources for Health-Bot answers (FR8).

Every URL below was fetched on 2026-11-23 (HTTP 200, no redirect) and its
page confirmed to cover the topic it is attached to. Only public-health
agencies are used: CDC, NCI (cancer.gov), NCI's Smokefree.gov and the NHS.

Rules:
- Emergency answers carry no sources: the fixed escalation text stands alone.
- Unmatched answers (out of scope, medication refusals, "consult a doctor")
  carry no sources, so a refusal is never dressed up as cited guidance.
- A source is a pointer for further reading, not a claim that the page
  endorses the generated wording.

Re-verify the URLs (tools/check_healthbot_sources.py) before release; agency
sites reorganise pages.
"""
from __future__ import annotations

from dataclasses import dataclass

from .service import KNOWLEDGE_BASE, AnswerType


@dataclass(frozen=True)
class TrustedSource:
    title: str
    url: str


SMOKEFREE_WITHDRAWAL = TrustedSource(
    "Managing Nicotine Withdrawal (Smokefree.gov, NCI)",
    "https://smokefree.gov/challenges-when-quitting/withdrawal/managing-nicotine-withdrawal",
)
NCI_WITHDRAWAL = TrustedSource(
    "Handling Nicotine Withdrawal and Triggers (National Cancer Institute)",
    "https://www.cancer.gov/about-cancer/causes-prevention/risk/tobacco/withdrawal-fact-sheet",
)
SMOKEFREE_TRIGGERS = TrustedSource(
    "Know Your Smoking Triggers (Smokefree.gov, NCI)",
    "https://smokefree.gov/challenges-when-quitting/cravings-triggers/know-your-triggers",
)
CDC_TIPS = TrustedSource(
    "Tips for Quitting (CDC)",
    "https://www.cdc.gov/tobacco/campaign/tips/quit-smoking/tips-for-quitting/index.html",
)
NHS_WHAT_HAPPENS = TrustedSource(
    "What could happen when you quit smoking (NHS)",
    "https://www.nhs.uk/better-health/quit-smoking/ready-to-quit-smoking/what-could-happen-when-you-quit-smoking/",
)
SMOKEFREE_SETBACK = TrustedSource(
    "Get Back on Track After a Setback (Smokefree.gov, NCI)",
    "https://smokefree.gov/challenges-when-quitting/stick-with-it/get-back-on-track",
)
CDC_BENEFITS = TrustedSource(
    "Benefits of Quitting Smoking (CDC)",
    "https://www.cdc.gov/tobacco/about/benefits-of-quitting.html",
)
CDC_SECONDHAND = TrustedSource(
    "Health Problems Caused by Secondhand Smoke (CDC)",
    "https://www.cdc.gov/tobacco/secondhand-smoke/health.html",
)
SMOKEFREE_VAPING_WITHDRAWAL = TrustedSource(
    "Nicotine Withdrawal and Vaping (Smokefree.gov, NCI)",
    "https://smokefree.gov/quit-vaping-resources/nicotine-withdrawal-vaping",
)
CDC_VAPING_QUITTING = TrustedSource(
    "Vaping and Quitting (CDC)",
    "https://www.cdc.gov/tobacco/e-cigarettes/quitting.html",
)

ALL_SOURCES: tuple[TrustedSource, ...] = (
    SMOKEFREE_WITHDRAWAL,
    NCI_WITHDRAWAL,
    SMOKEFREE_TRIGGERS,
    CDC_TIPS,
    NHS_WHAT_HAPPENS,
    SMOKEFREE_SETBACK,
    CDC_BENEFITS,
    CDC_SECONDHAND,
    SMOKEFREE_VAPING_WITHDRAWAL,
    CDC_VAPING_QUITTING,
)

_WITHDRAWAL = (SMOKEFREE_WITHDRAWAL, NCI_WITHDRAWAL)
_CRAVINGS = (SMOKEFREE_TRIGGERS, CDC_TIPS)
_SETBACKS = (SMOKEFREE_SETBACK, CDC_TIPS)
_BENEFITS = (CDC_BENEFITS, NHS_WHAT_HAPPENS)

#: Default for an in-scope generated answer that matches no curated topic.
GENERAL_SOURCES: tuple[TrustedSource, ...] = (CDC_TIPS, NCI_WITHDRAWAL)

#: One entry per KNOWLEDGE_BASE topic (enforced by tests).
TOPIC_SOURCES: dict[str, tuple[TrustedSource, ...]] = {
    "headaches": _WITHDRAWAL,
    "irritability": _WITHDRAWAL,
    "sleep": _WITHDRAWAL,
    "anxiety": _WITHDRAWAL,
    "how_long_cravings_last": _WITHDRAWAL,
    "craving_intensity": _CRAVINGS,
    "appetite": (NCI_WITHDRAWAL, NHS_WHAT_HAPPENS),
    "concentration": _WITHDRAWAL,
    "coughing": (NHS_WHAT_HAPPENS, CDC_BENEFITS),
    "dizziness": _WITHDRAWAL,
    "digestive": _WITHDRAWAL,
    "oral_irritation": _WITHDRAWAL,
    "relapse_support": _SETBACKS,
    "motivation": _SETBACKS,
    "avoiding_triggers": _CRAVINGS,
    "exercise_while_quitting": (CDC_TIPS, NHS_WHAT_HAPPENS),
    "alcohol": _CRAVINGS,
    "caffeine": _CRAVINGS,
    "taste_and_smell": _BENEFITS,
    "breathing_improvement": _BENEFITS,
    "secondhand_exposure": (CDC_SECONDHAND,),
    "vaping_withdrawal": (SMOKEFREE_VAPING_WITHDRAWAL, CDC_VAPING_QUITTING),
    "skin_changes": _BENEFITS,
    "sweating": _WITHDRAWAL,
    "fatigue": _WITHDRAWAL,
    "staying_on_track": _SETBACKS,
    "social_pressure": _CRAVINGS,
    "stress_management": (NCI_WITHDRAWAL, SMOKEFREE_TRIGGERS),
    "oral_fixation": _CRAVINGS,
    "getting_sick": _BENEFITS,
    "throat_irritation": _WITHDRAWAL,
    "is_this_normal": _WITHDRAWAL,
}


def match_topic(query: str) -> str | None:
    """Same first-match-wins keyword order as service.answer_query."""
    lowered = query.lower()
    for topic, keywords, _response in KNOWLEDGE_BASE:
        if any(keyword in lowered for keyword in keywords):
            return topic
    return None


def sources_for_query(query: str) -> tuple[TrustedSource, ...]:
    topic = match_topic(query)
    return TOPIC_SOURCES.get(topic, GENERAL_SOURCES) if topic else GENERAL_SOURCES


def sources_for_answer(query: str, answer_type: AnswerType) -> tuple[TrustedSource, ...]:
    if answer_type != AnswerType.MATCHED:
        return ()
    return sources_for_query(query)

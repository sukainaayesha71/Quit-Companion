"""Phase 2 (backend AI/ML plan, 2026-08-17), updated for Open Decision 6
(2026-08-17, same day): explicit feature mapping between the EMASENS_ML
dataset (Perski et al., 2024) and Quit Companion's CravingLog.

Open Decision 6 extended CravingLog with ten 0-10 mood-slider fields
(mobile/lib/models/craving_log.dart) — one per EMASENS_ML affect
dimension. This upgrades those ten mappings from "partial" to "direct":
the app field, once populated by the new UI sliders, IS the same 0-10
scale as the source dataset's `*_imp` columns, no approximation needed.
All *other* EMASENS_ML features (demographics, cigarette availability,
structured location/activity/social-context, motivation/confidence/pain,
substance use, lapse_prior, study_day) remain unavailable — CravingLog
still does not collect them, and this file does not fabricate them.

This module documents, in code, exactly which EMASENS_ML columns are used
and why, and defines TWO feature sets rather than silently forcing an
incompatible dataset into our production schema:

- FULL_EMA_FEATURES: every predictor the original paper's group-level,
  EMA-only model used. Trained to (a) validate this pipeline reproduces the
  paper's reported performance on the same data/features, and (b) show the
  ceiling performance achievable on this dataset.

- CRAVINGLOG_COMPATIBLE_FEATURES: only the subset that has a real,
  defensible mapping to what CravingLog actually collects today. This is
  the candidate for eventual production use (Phase 7) — a model trained on
  fields our app cannot supply at inference time would be undeployable,
  regardless of its offline accuracy.

Nothing here invents a feature or a label. Where EMASENS_ML has no
CravingLog equivalent (demographics, substance availability, activity/
location detail, prior-lapse history), it is explicitly excluded, not
approximated silently.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class FeatureMapping:
    emasens_column: str
    cravinglog_field: str | None
    mapping_quality: str  # "direct" | "partial" | "unavailable"
    notes: str


# --- Full documented mapping table (Phase 2 deliverable) -------------------

FEATURE_MAPPING_TABLE: list[FeatureMapping] = [
    FeatureMapping(
        "craving_imp", "intensity", "direct",
        "EMASENS 0-10 Likert vs. CravingLog's 1-10 integer scale — trivial "
        "rescale, same construct (self-reported craving severity).",
    ),
    FeatureMapping(
        "happy_imp", "moodHappy", "direct",
        "Open Decision 6 (2026-08-17): CravingLog now collects a dedicated "
        "0-10 'Happy' slider (mobile/lib/screens/craving/log_craving_screen.dart) "
        "alongside the pre-existing categorical mood pick — same 0-10 scale "
        "as EMASENS's happy_imp, no approximation needed. Nullable in "
        "Firestore for records logged before this decision; defaults to 5 "
        "(neutral midpoint) in the UI/controller when not explicitly moved.",
    ),
    FeatureMapping(
        "stressed_imp", "moodStressed", "direct",
        "Same upgrade as happy_imp above — dedicated 'Stressed' slider.",
    ),
    FeatureMapping(
        "sad_imp", "moodSad", "direct",
        "Same upgrade as happy_imp above — dedicated 'Sad' slider.",
    ),
    FeatureMapping(
        "bored_imp", "moodBored", "direct",
        "Same upgrade as happy_imp above — dedicated 'Bored' slider.",
    ),
    FeatureMapping(
        "enthusiastic_imp", "moodEnthusiastic", "direct",
        "Same upgrade as happy_imp above — dedicated 'Enthusiastic' slider, "
        "newly added by Open Decision 6 (had no categorical-mood analog at "
        "all before this).",
    ),
    FeatureMapping(
        "excited_imp", "moodExcited", "direct",
        "Same upgrade as enthusiastic_imp above — dedicated 'Excited' slider.",
    ),
    FeatureMapping(
        "contented_imp", "moodContented", "direct",
        "Same upgrade as enthusiastic_imp above — dedicated 'Contented' slider.",
    ),
    FeatureMapping(
        "calm_imp", "moodCalm", "direct",
        "Same upgrade as enthusiastic_imp above — dedicated 'Calm' slider.",
    ),
    FeatureMapping(
        "irritable_imp", "moodIrritable", "direct",
        "Same upgrade as enthusiastic_imp above — dedicated 'Irritable' slider.",
    ),
    FeatureMapping(
        "anxious_imp", "moodAnxious", "direct",
        "Same upgrade as enthusiastic_imp above — dedicated 'Anxious' slider.",
    ),
    FeatureMapping(
        "pain_imp", None, "unavailable",
        "CravingLog collects no bodily-pain field.",
    ),
    FeatureMapping(
        "motivation_imp", None, "unavailable",
        "CravingLog collects no per-craving motivation-to-quit rating "
        "(onboarding captures primaryMotivation once, as free text, not "
        "per-event, not on a comparable 0-10 scale).",
    ),
    FeatureMapping(
        "confidence_imp", None, "unavailable",
        "CravingLog collects no per-craving self-efficacy/confidence rating.",
    ),
    FeatureMapping(
        "cigarette_availability_imp", None, "unavailable",
        "CravingLog has no equivalent field. mood == 'social' (CravingLog's "
        "5th mood value) has no EMASENS equivalent either, and is not "
        "mapped by this table in either direction.",
    ),
    FeatureMapping(
        "alcohol_imp / caffeine_imp / nicotine_imp", None, "unavailable",
        "No equivalent fields in CravingLog.",
    ),
    FeatureMapping(
        "location_*_imp (9 flags)", "locationContext", "unavailable",
        "CravingLog's locationContext is free text, not the same structured "
        "9-category vocabulary — not mapped without free-text classification, "
        "which this plan does not build.",
    ),
    FeatureMapping(
        "activity_*_imp (12 flags)", "activity", "unavailable",
        "CravingLog's activity is free text, not the same structured "
        "12-category vocabulary — same reasoning as location above.",
    ),
    FeatureMapping(
        "social_context_*_imp (8 flags)", "triggerCategory == 'socialPressure'", "unavailable",
        "CravingLog's triggerCategory is a single 5-value pick (stress/"
        "afterMeal/socialPressure/boredom/other), not the same 8-category "
        "social-context vocabulary. Not mapped — collapsing 8 flags into 1 "
        "boolean would discard information silently.",
    ),
    FeatureMapping(
        "lapse_prior", "last24hCount (loose analog only)", "unavailable",
        "EMASENS's lapse_prior is 'was the immediately preceding EMA a "
        "lapse' (binary, same person's prior entry). CravingLog's "
        "last24hCount is 'how many craving logs in the last 24h' (a count, "
        "not a lapse-history flag, and not scoped to the immediately prior "
        "entry). Conceptually adjacent, not the same signal — excluded "
        "rather than treated as equivalent.",
    ),
    FeatureMapping(
        "age / sex / job_type / ethnicity / post_16_edu / past_quit_attempt / "
        "time_to_first_cig / motivation_to_stop", None, "unavailable",
        "One-time demographic/onboarding-style fields in EMASENS. Some have "
        "loose onboarding analogs (e.g. NicotineUser has no age/sex field at "
        "all today) but none are collected per-craving-event, so they cannot "
        "be fed to a per-event prediction endpoint without a separate join — "
        "not built here.",
    ),
]

# --- Feature sets actually used for training --------------------------------

#: Every EMA-only predictor the paper's own model used (script
#: 18_ML_analyses_group_no_sensor.R), reproduced here for the "full/academic"
#: model. Excludes IDs, timestamps, and the near-zero-variance columns the
#: source script itself drops (documented inline in that script).
FULL_EMA_FEATURES: list[str] = [
    "age", "sex", "cpd", "job_type", "post_16_edu", "ethnicity",
    "time_to_first_cig", "motivation_to_stop", "past_quit_attempt",
    "study_day",
    "excited_imp", "cigarette_availability_imp", "calm_imp", "bored_imp",
    "enthusiastic_imp", "irritable_imp", "anxious_imp", "contented_imp",
    "stressed_imp", "sad_imp", "motivation_imp", "craving_imp",
    "caffeine_imp", "happy_imp", "confidence_imp", "pain_imp",
    "alcohol_imp", "nicotine_imp",
    "location_home_imp", "location_school_work_imp", "location_outside_imp",
    "location_restaurant_imp", "location_public_place_imp",
    "location_public_transport_imp", "location_private_vehicle_imp",
    "location_other_imp",
    "activity_eating_imp", "activity_tv_imp", "activity_music_imp",
    "activity_reading_imp", "activity_working_imp", "activity_walking_imp",
    "activity_socialising_imp", "activity_social_media_imp",
    "activity_relaxing_imp", "activity_chores_imp", "activity_other_imp",
    "social_context_alone_imp", "social_context_partner_imp",
    "social_context_relative_imp", "social_context_other_imp",
    "lapse_prior",
]

#: Every field with a "direct" mapping quality above — the candidate set for
#: an eventual production model. Expanded by Open Decision 6 (2026-08-17)
#: from 5 to 11 features now that CravingLog collects all ten EMASENS mood
#: dimensions via dedicated sliders, not just the four with a categorical-
#: mood analog. Still excludes every "unavailable" feature in the table
#: above (demographics, substance availability, structured location/
#: activity/social-context, motivation/confidence/pain, lapse_prior) — none
#: of those are collected by CravingLog and none are fabricated here.
CRAVINGLOG_COMPATIBLE_FEATURES: list[str] = [
    "craving_imp",
    "happy_imp",
    "excited_imp",
    "enthusiastic_imp",
    "contented_imp",
    "calm_imp",
    "irritable_imp",
    "anxious_imp",
    "stressed_imp",
    "sad_imp",
    "bored_imp",
]

TARGET_COLUMN = "lapse_lagged"

GROUP_COLUMN = "id"  # participant id — required for the Phase 3 grouped split

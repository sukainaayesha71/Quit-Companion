"""Consistency checks for ml/pipeline/feature_mapping.py (Open Decision 6,
2026-08-17). These don't test model quality (that's train.py's own printed
report) — they guard against the mapping table and the two feature-set
constants silently drifting apart, e.g. a "direct" mapping added to the
table but never added to CRAVINGLOG_COMPATIBLE_FEATURES, or a feature listed
in one of the constants that no longer has a corresponding table row.
"""

from ml.pipeline.feature_mapping import (
    CRAVINGLOG_COMPATIBLE_FEATURES,
    FEATURE_MAPPING_TABLE,
    FULL_EMA_FEATURES,
)

_DIRECT_COLUMNS = {m.emasens_column for m in FEATURE_MAPPING_TABLE if m.mapping_quality == "direct"}
_ALL_TABLE_COLUMNS = {m.emasens_column for m in FEATURE_MAPPING_TABLE}


def test_every_direct_mapping_has_a_cravinglog_field():
    for mapping in FEATURE_MAPPING_TABLE:
        if mapping.mapping_quality == "direct":
            assert mapping.cravinglog_field is not None, (
                f"{mapping.emasens_column} is marked 'direct' but has no cravinglog_field"
            )


def test_every_unavailable_mapping_has_no_fabricated_cravinglog_value():
    # "unavailable" rows may still name the closest non-mapped CravingLog
    # field for documentation (e.g. lapse_prior -> last24hCount), but must
    # never claim "direct" while doing so.
    for mapping in FEATURE_MAPPING_TABLE:
        if mapping.mapping_quality == "unavailable":
            assert mapping.notes, f"{mapping.emasens_column} unavailable row has no explanatory note"


def test_cravinglog_compatible_features_are_all_direct_mappings():
    # No feature is ever trained on unless the table documents it as a real,
    # non-fabricated mapping to what CravingLog actually collects.
    for feature in CRAVINGLOG_COMPATIBLE_FEATURES:
        assert feature in _DIRECT_COLUMNS, (
            f"{feature} is in CRAVINGLOG_COMPATIBLE_FEATURES but not marked 'direct' in FEATURE_MAPPING_TABLE"
        )


def test_cravinglog_compatible_features_are_a_subset_of_full_ema_features():
    # The app-deployable feature set can never train on something the
    # academic/ceiling model itself doesn't use.
    assert set(CRAVINGLOG_COMPATIBLE_FEATURES).issubset(set(FULL_EMA_FEATURES))


def test_no_duplicate_emasens_columns_in_table():
    columns = [m.emasens_column for m in FEATURE_MAPPING_TABLE]
    assert len(columns) == len(set(columns)), "Duplicate emasens_column entries found in FEATURE_MAPPING_TABLE"


def test_all_ten_mood_dimensions_are_direct_after_open_decision_6():
    mood_columns = {
        "happy_imp", "excited_imp", "enthusiastic_imp", "contented_imp",
        "calm_imp", "irritable_imp", "anxious_imp", "stressed_imp",
        "sad_imp", "bored_imp",
    }
    assert mood_columns.issubset(_DIRECT_COLUMNS)
    assert mood_columns.issubset(set(CRAVINGLOG_COMPATIBLE_FEATURES))


def test_cravinglog_compatible_features_has_eleven_entries():
    # craving_imp + the ten mood dimensions, no more, no less — documents
    # the exact scope of Open Decision 6 so a silent future addition/removal
    # is caught here rather than discovered downstream in train.py.
    assert len(CRAVINGLOG_COMPATIBLE_FEATURES) == 11
    assert len(CRAVINGLOG_COMPATIBLE_FEATURES) == len(set(CRAVINGLOG_COMPATIBLE_FEATURES))

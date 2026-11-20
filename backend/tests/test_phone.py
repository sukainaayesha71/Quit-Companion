from app.phone import is_valid_e164, normalize_phone_number


def test_normalize_strips_stray_formatting_characters():
    assert normalize_phone_number("+92 335 760 6070") == "+923357606070"
    assert normalize_phone_number("+92-335-760-6070") == "+923357606070"
    assert normalize_phone_number(" +923357606070 ") == "+923357606070"


def test_normalize_passes_clean_e164_through_unchanged():
    assert normalize_phone_number("+923357606070") == "+923357606070"


def test_normalize_empty_string_stays_empty():
    assert normalize_phone_number("   ") == ""


def test_valid_e164_number_is_accepted():
    assert is_valid_e164("+923357606070") is True
    assert is_valid_e164("+14155552671") is True


def test_invalid_phone_numbers_are_rejected():
    assert is_valid_e164("") is False
    assert is_valid_e164("923357606070") is False  # missing leading +
    assert is_valid_e164("+9233") is False  # too short
    assert is_valid_e164("+0233576060") is False  # leading 0 after +
    assert is_valid_e164("not-a-number") is False

import re

# Mirrors mobile/lib/controllers/phone_auth_controller.dart's normalizePhoneNumber/_phonePattern
# so both sides agree on what counts as a valid E.164 number.
_E164_PATTERN = re.compile(r"^\+[1-9]\d{7,14}$")


def normalize_phone_number(raw: str) -> str:
    """Strips everything except digits and a single leading '+'."""
    trimmed = raw.strip()
    if not trimmed:
        return trimmed
    has_leading_plus = trimmed.startswith("+")
    digits_only = re.sub(r"[^0-9]", "", trimmed)
    return f"+{digits_only}" if has_leading_plus else digits_only


def is_valid_e164(phone_number: str) -> bool:
    return bool(_E164_PATTERN.match(phone_number))

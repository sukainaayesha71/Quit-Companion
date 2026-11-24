"""The mobile app's offline crisis detection must match the backend's.

mobile/lib/features/health_bot/domain/local_health_bot_fallback.dart copies
EMERGENCY_KEYWORDS and EMERGENCY_RESPONSE_TEXT so a crisis message still gets
the emergency referral when the backend is unreachable. This test fails if
either copy drifts.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from app.healthbot.service import EMERGENCY_KEYWORDS, EMERGENCY_RESPONSE_TEXT

DART_FILE = (
    Path(__file__).resolve().parents[2]
    / "mobile/lib/features/health_bot/domain/local_health_bot_fallback.dart"
)

_STRING = r"""'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)\""""


def _dart_strings(fragment: str) -> list[str]:
    return [single or double for single, double in re.findall(_STRING, fragment)]


@pytest.fixture(scope="module")
def dart_source() -> str:
    if not DART_FILE.exists():
        pytest.skip("mobile sources not present in this checkout")
    return DART_FILE.read_text(encoding="utf-8")


def test_emergency_keywords_match(dart_source: str) -> None:
    block = re.search(r"emergencyKeywords\s*=\s*\[(.*?)\];", dart_source, re.S)
    assert block, "emergencyKeywords list not found"
    assert _dart_strings(block.group(1)) == EMERGENCY_KEYWORDS


def test_emergency_text_matches(dart_source: str) -> None:
    block = re.search(r"emergencyResponseText\s*=\s*(.*?);", dart_source, re.S)
    assert block, "emergencyResponseText not found"
    assert "".join(_dart_strings(block.group(1))) == EMERGENCY_RESPONSE_TEXT

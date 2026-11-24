"""Manual pre-release check: every Health-Bot source URL still resolves.

Run from backend/:  .venv/Scripts/python.exe tools/check_healthbot_sources.py
Needs internet access; not part of the automated test suite.
"""
from __future__ import annotations

import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.healthbot.sources import ALL_SOURCES  # noqa: E402


def main() -> int:
    failures = 0
    with httpx.Client(follow_redirects=False, timeout=15.0,
                      headers={"User-Agent": "QuitCompanion-source-check/1.0"}) as client:
        for source in ALL_SOURCES:
            try:
                status = client.get(source.url).status_code
            except httpx.HTTPError as error:
                status = f"error: {error.__class__.__name__}"
            ok = status == 200
            failures += 0 if ok else 1
            print(f"{'OK  ' if ok else 'FAIL'} {status}  {source.url}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

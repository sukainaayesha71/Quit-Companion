"""A review record is valid only for the exact version of the supplied content.

An actual clinical advisor must provide the approval record; code cannot
substitute for that review. Changing catalogue content invalidates old approval.
"""
import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone


def content_digest() -> str:
    from .service import KNOWLEDGE_BASE, EMERGENCY_RESPONSE_TEXT
    from ..coaching.service import ACTIONS
    content = json.dumps({"knowledge": KNOWLEDGE_BASE, "actions": ACTIONS,
                          "emergency": EMERGENCY_RESPONSE_TEXT}, sort_keys=True)
    return hashlib.sha256(content.encode()).hexdigest()


def review_status(record_path: str | None) -> str:
    if not record_path: return "pending"
    try:
        record = json.loads(Path(record_path).read_text(encoding="utf-8"))
        reviewed_at = datetime.fromisoformat(record["reviewed_at"])
        if (record.get("approved") is True and record.get("content_sha256") == content_digest()
                and isinstance(record.get("reviewer"), str) and record["reviewer"].strip()
                and reviewed_at.tzinfo is not None and reviewed_at <= datetime.now(timezone.utc)):
            return "approved_catalogue"
    except (OSError, ValueError, KeyError, TypeError): pass
    return "pending"

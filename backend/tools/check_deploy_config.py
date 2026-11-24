"""Step 12 deployment preflight - checks deploy/.env WITHOUT printing values.

Usage (from backend/):
    .venv/Scripts/python.exe tools/check_deploy_config.py              # ../deploy/.env
    .venv/Scripts/python.exe tools/check_deploy_config.py path/to/.env

Prints OK / WARN / FAIL per item and exits 1 if anything FAILs. Secret values
(keys, tokens, file contents) are never printed - only whether they are set
and well-formed. Makes no network calls and changes nothing.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
REPO = BACKEND.parent
sys.path.insert(0, str(BACKEND))

PLACEHOLDER_DOMAINS = {"", "localhost", "your-api-domain.example"}
EXPECTED_PROJECT_FILE = REPO / "mobile" / "firebase.json"


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def expected_project_id() -> str | None:
    try:
        data = json.loads(EXPECTED_PROJECT_FILE.read_text(encoding="utf-8"))
        return data["flutter"]["platforms"]["android"]["default"]["projectId"]
    except (OSError, KeyError, ValueError):
        return None


def check(env: dict[str, str], env_path: Path) -> list[tuple[str, str, str]]:
    results: list[tuple[str, str, str]] = []

    def add(level: str, item: str, note: str) -> None:
        results.append((level, item, note))

    # HTTPS domain served by Caddy.
    domain = env.get("SITE_DOMAIN", "")
    if domain in PLACEHOLDER_DOMAINS:
        add("FAIL", "SITE_DOMAIN", "not set to a real domain (placeholder/localhost); HTTPS needs a public domain")
    elif not re.fullmatch(r"(?=.{1,253}$)([a-z0-9-]{1,63}\.)+[a-z]{2,63}", domain.lower()):
        add("FAIL", "SITE_DOMAIN", "does not look like a hostname (no scheme, no path)")
    else:
        add("OK", "SITE_DOMAIN", "set; app release URL will be https://<SITE_DOMAIN>")

    # Firebase Admin credential file (mounted read-only into both services).
    cred = env.get("FIREBASE_CREDENTIAL_FILE", "")
    if not cred or cred.startswith("/absolute/host/path"):
        add("FAIL", "FIREBASE_CREDENTIAL_FILE", "not set (placeholder)")
    else:
        path = Path(cred)
        if not path.is_file():
            add("FAIL", "FIREBASE_CREDENTIAL_FILE", "file not found at the configured path")
        else:
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                kind_ok = data.get("type") == "service_account" and bool(data.get("private_key"))
                project = data.get("project_id")
                expected = expected_project_id()
                if not kind_ok:
                    add("FAIL", "FIREBASE_CREDENTIAL_FILE", "not a service-account key")
                elif expected and project != expected:
                    add("FAIL", "FIREBASE_CREDENTIAL_FILE", f"project_id does not match the app's project ({expected})")
                else:
                    add("OK", "FIREBASE_CREDENTIAL_FILE", f"service-account key for project {project}")
            except (OSError, ValueError):
                add("FAIL", "FIREBASE_CREDENTIAL_FILE", "unreadable or not JSON")

    # Optional-but-important keys (presence only).
    add("OK" if env.get("GEMINI_API_KEY") else "WARN", "GEMINI_API_KEY",
        "set" if env.get("GEMINI_API_KEY") else "empty: Health-Bot will answer from the curated fallback only")
    add("OK" if env.get("FCM_SCHEDULER_TOKEN") else "WARN", "FCM_SCHEDULER_TOKEN",
        "set" if env.get("FCM_SCHEDULER_TOKEN")
        else "empty: POST /notifications/send is disabled (the worker does not need it)")

    # Relapse predictor.
    mode = env.get("RELAPSE_PREDICTOR_MODE", "ml")
    if mode not in {"ml", "candidate", "rule_based", "model"}:
        add("FAIL", "RELAPSE_PREDICTOR_MODE", "unknown mode")
    elif mode in {"ml", "candidate"}:
        try:
            from app.relapse.predictor import CandidatePredictor
            CandidatePredictor()
            add("OK", "RELAPSE_PREDICTOR_MODE", f"{mode}: packaged model loads")
        except Exception as error:  # noqa: BLE001 - report type only
            add("FAIL", "RELAPSE_PREDICTOR_MODE", f"{mode}: packaged model failed to load ({type(error).__name__})")
    else:
        add("OK", "RELAPSE_PREDICTOR_MODE", f"{mode}")

    # Clinical review gate (deploy/reviews is mounted at /run/reviews).
    if env.get("REQUIRE_CLINICAL_REVIEW", "false").lower() == "true":
        record = env.get("CLINICAL_REVIEW_RECORD", "")
        host_record = REPO / "deploy" / "reviews" / Path(record).name if record else None
        if not host_record or not host_record.is_file():
            add("WARN", "REQUIRE_CLINICAL_REVIEW",
                "true but no review record in deploy/reviews/: Health-Bot returns 503 for "
                "non-emergency questions (the app then shows its curated fallback) and /ready reports not ready")
        else:
            from app.healthbot.review import review_status
            status = review_status(str(host_record))
            add("OK" if status == "approved_catalogue" else "WARN", "REQUIRE_CLINICAL_REVIEW",
                f"record found, status: {status}")
    else:
        add("WARN", "REQUIRE_CLINICAL_REVIEW", "false: Health-Bot serves unreviewed guidance (development setting)")

    # Worker cadence.
    poll = env.get("WORKER_POLL_SECONDS", "30")
    if not poll.isdigit():
        add("FAIL", "WORKER_POLL_SECONDS", "not a whole number")
    elif not 5 <= int(poll) <= 45:
        add("WARN", "WORKER_POLL_SECONDS", "outside 5-45; the worker clamps it")
    else:
        add("OK", "WORKER_POLL_SECONDS", poll)

    # The env file itself must never be committed (templates are fine).
    if env_path.name.endswith(".example"):
        add("OK", "env file", "template (.example) - checked as a dry run")
        return results
    try:
        tracked = subprocess.run(["git", "ls-files", "--error-unmatch", str(env_path)],
                                 cwd=REPO, capture_output=True, check=False).returncode == 0
        add("FAIL" if tracked else "OK", "env file", "TRACKED BY GIT - remove it" if tracked else "not tracked by git")
    except OSError:
        add("WARN", "env file", "git not available to check tracking")

    return results


def main(argv: list[str]) -> int:
    env_path = Path(argv[1]) if len(argv) > 1 else REPO / "deploy" / ".env"
    if not env_path.is_file():
        print(f"FAIL  env file not found: {env_path}. Copy deploy/.env.example to deploy/.env first.")
        return 1
    results = check(read_env(env_path), env_path.resolve())
    width = max(len(item) for _, item, _ in results)
    for level, item, note in results:
        print(f"{level:<5} {item:<{width}}  {note}")
    failed = any(level == "FAIL" for level, _, _ in results)
    print("\nRESULT:", "NOT READY - fix the FAIL items" if failed else "ready (review any WARN items)")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

"""Step 13: LOCAL latency measurement of the real FastAPI app over loopback HTTP.

What is real: the app, routing, validation, predictors, Health-Bot logic and
the HTTP stack (uvicorn + httpx over 127.0.0.1).
What is simulated: Firebase auth (fake verifier), Firestore reads (a fixed
per-query delay, --firestore-ms), and Gemini (always a local stub — this tool
NEVER calls Gemini or any external service, even if a key is configured).

Not a production or 4G measurement: no real network distance, no real
Firestore, no real model latency from Gemini. For deployed numbers use
tools/benchmark_api.py against the HTTPS URL with a test account token.

Run from backend/:  .venv/Scripts/python.exe tools/measure_local_latency.py [--firestore-ms 80] [--samples 50]
"""
from __future__ import annotations

import argparse
import asyncio
import json
import socket
import statistics
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx  # noqa: E402
import uvicorn  # noqa: E402

from app.coaching.router import get_coaching_context  # noqa: E402
from app.config import settings  # noqa: E402
from app.dependencies import get_firebase_identity_provider, get_relapse_predictor  # noqa: E402
from app.fake_firebase_identity import FakeFirebaseIdentityProvider  # noqa: E402
from app.healthbot import service as healthbot  # noqa: E402
from app.healthbot.service import AnswerType, HealthBotAnswer  # noqa: E402
from app.main import app  # noqa: E402
from app.relapse.predictor import CandidatePredictor, RuleBasedPredictor  # noqa: E402

TOKEN = "local-measurement-token"
RELAPSE_BODY = {
    "intensity": 7, "mood": "stressed", "trigger_category": "stress", "last_24h_count": 2,
    **{f"mood_{m}": 5 for m in ("happy", "excited", "enthusiastic", "contented", "calm",
                                "irritable", "anxious", "stressed", "sad", "bored")},
}
ATTEMPTS = [{"alternativeId": f"a{i % 12}", "outcomeHelped": i % 3 != 0,
             "triggerCategory": "stress", "mood": "stressed",
             "attemptedAt": f"2026-11-{1 + i % 22:02d}T10:00:00"} for i in range(200)]


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class _Context:
    """Simulated Firestore: each query sleeps --firestore-ms."""

    def __init__(self, delay_s: float, attempts_only: bool):
        self.delay_s = delay_s
        if not attempts_only:
            self.read_attempts = None  # force the legacy full read path

    def _query(self, value):
        time.sleep(self.delay_s)
        return value

    def read(self, uid):
        return {"profile": self._query({}), "attempts": self._query(ATTEMPTS),
                "cravings": self._query([]), "usage": self._query([])}

    def read_attempts(self, uid):  # noqa: F811 - may be shadowed above
        return self._query(ATTEMPTS)


def _measure(client, method, path, body, n):
    times, statuses = [], []
    for _ in range(n):
        started = time.perf_counter()
        response = client.request(method, path, json=body)
        times.append((time.perf_counter() - started) * 1000)
        statuses.append(response.status_code)
    ordered = sorted(times)
    return {
        "n": n,
        "p50_ms": round(statistics.median(times), 1),
        "p95_ms": round(ordered[max(0, int(round(0.95 * n)) - 1)], 1),
        "max_ms": round(ordered[-1], 1),
        "statuses": sorted(set(statuses)),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--firestore-ms", type=float, default=80.0)
    parser.add_argument("--samples", type=int, default=50)
    args = parser.parse_args()

    identity = FakeFirebaseIdentityProvider()
    identity.valid_tokens[TOKEN] = "perf-user"
    app.dependency_overrides[get_firebase_identity_provider] = lambda: identity
    settings.require_clinical_review = False
    # Never reach Gemini: a key may exist in the local .env.
    settings.gemini_api_key = "local-measurement-not-a-key"

    port = _free_port()
    server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=port, log_level="warning"))
    threading.Thread(target=server.run, daemon=True).start()
    while not server.started:
        time.sleep(0.05)

    results: dict[str, dict] = {}
    n = max(5, min(args.samples, 500))
    delay = args.firestore_ms / 1000
    with httpx.Client(base_url=f"http://127.0.0.1:{port}", timeout=30,
                      headers={"Authorization": f"Bearer {TOKEN}"}) as client:
        client.get("/health")  # warm up

        for label, predictor in (("rule_based", RuleBasedPredictor()), ("ml", CandidatePredictor())):
            app.dependency_overrides[get_relapse_predictor] = lambda p=predictor: p
            results[f"predict_relapse[{label}]"] = _measure(client, "POST", "/predict/relapse", RELAPSE_BODY, n)

        for label, attempts_only in (("legacy_4_queries", False), ("attempts_only_1_query", True)):
            app.dependency_overrides[get_coaching_context] = lambda a=attempts_only: _Context(delay, a)
            results[f"recommend_alternative[{label}]"] = _measure(
                client, "POST", "/recommend/alternative",
                {"trigger_category": "stress", "mood": "stressed"}, max(5, n // 2))

        async def instant(query, **_):
            return HealthBotAnswer(AnswerType.MATCHED, "Stub reply.")

        async def slow(query, **_):
            await asyncio.sleep(0.8)
            return HealthBotAnswer(AnswerType.MATCHED, "Stub reply after 0.8 s.")

        async def hang(query, **_):
            await asyncio.sleep(30)

        original = healthbot._request_gemini_answer
        for label, stub, count in (("gemini_stub_instant", instant, n),
                                   ("gemini_stub_0.8s", slow, 10),
                                   ("gemini_stub_hangs_budget_fallback", hang, 5)):
            healthbot._request_gemini_answer = stub
            results[f"healthbot[{label}]"] = _measure(
                client, "POST", "/healthbot/query", {"query": "I have a headache"}, count)
        results["healthbot[emergency]"] = _measure(
            client, "POST", "/healthbot/query", {"query": "I feel suicidal"}, n)
        healthbot._request_gemini_answer = original

    server.should_exit = True
    print(json.dumps({"conditions": {
        "transport": "real HTTP over 127.0.0.1 loopback (uvicorn + httpx)",
        "auth": "fake verifier", "firestore": f"simulated {args.firestore_ms:g} ms per query",
        "gemini": "local stub only (no external calls)",
        "healthbot_gemini_budget_s": settings.healthbot_gemini_timeout_seconds,
    }, "results": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

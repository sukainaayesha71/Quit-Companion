"""Measure actual API p50/p95 without logging tokens or personal responses.

Set BENCHMARK_FIREBASE_ID_TOKEN to a dedicated test account's ID token.
Run: python tools/benchmark_api.py --url https://your-api --samples 5
This verifies server response latency, not Android/4G rendering latency.
"""
import argparse
import json
import os
import statistics
import time
import httpx


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8000")
    parser.add_argument("--samples", type=int, default=5)
    args = parser.parse_args()
    token = os.environ.get("BENCHMARK_FIREBASE_ID_TOKEN")
    if not token: raise SystemExit("Set BENCHMARK_FIREBASE_ID_TOKEN for a dedicated test account")
    results = {}
    routes = [("/predict/relapse", {"intensity": 5, "mood": "happy", "trigger_category": "other", "last_24h_count": 1}, 1500),
              ("/recommend/alternative", {}, 2000), ("/healthbot/query", {"query": "How can I manage a craving?"}, 2000)]
    with httpx.Client(timeout=15, headers={"Authorization": "Bearer " + token}) as client:
        for path, payload, target in routes:
            samples = []
            failures = 0
            for _ in range(max(1, min(args.samples, 50))):
                started = time.perf_counter()
                response = client.post(args.url.rstrip("/") + path, json=payload)
                samples.append((time.perf_counter() - started) * 1000)
                failures += response.status_code != 200
            ordered = sorted(samples)
            p95 = ordered[max(0, int(len(ordered) * .95 + .999) - 1)]
            results[path] = {"p50_ms": statistics.median(samples), "p95_ms": p95,
                             "http_failures": failures, "target_ms": target, "met": p95 <= target and not failures}
    print(json.dumps(results, indent=2))


if __name__ == "__main__": main()

# Step 13 — Performance testing and measurement: record (2026-11-23)

## Test environment

| Item | Value |
| --- | --- |
| Machine | Windows 11 Pro (development PC), Python 3.12.10, Flutter (project SDK), Dart VM tests |
| Physical Android device | **None connected** (`adb devices` empty) — no real-device measurements this run |
| Production backend / FCM | **Not deployed** (Step 12: prepared only) — no production URL |
| Gemini | **No live calls** (owner's instruction) — stubbed locally |
| Network | Loopback only. Remote latency is **simulated** where stated |

Measurement methods:
- **Backend:** `backend/tools/measure_local_latency.py` (new). Runs the real FastAPI app under uvicorn on `127.0.0.1` and uses real HTTP via httpx. Auth is a fake verifier. Firestore is a fixed simulated delay per query (80 ms). Gemini is a local stub. Reports p50/p95/max per path.
- **Mobile logic:** `mobile/test/perf/performance_measurements_test.dart` (new). Dart VM tests with stopwatches, fake repositories and a **simulated 300 ms per remote request**. They print `[perf]` lines.
- **Device instrumentation (new, for the manual phone run):** `lib/shared/domain/perf_log.dart` prints `[perf] <metric> <ms>ms` in debug/profile builds only, for `relapse_prediction`, `recommendations_local`, `recommendations_with_server_rerank`, `healthbot_response[_local_fallback]` and `dashboard_load`. It is silent in release builds and never logs content.
- **Existing (unchanged):** `backend/tools/benchmark_api.py` measures deployed endpoints with a test-account token. The `X-Response-Time-Ms` header is on every API response.

## Configuration (inspected, not decided)

- Local dev `backend/.env`: `RELAPSE_PREDICTOR_MODE=ml`; `REQUIRE_CLINICAL_REVIEW` unset (false).
- Production template `deploy/.env.example`: `RELAPSE_PREDICTOR_MODE=rule_based`; `REQUIRE_CLINICAL_REVIEW=true`.
- **Owner decision still required** for both. Prediction is measured in both modes. Measurements ran with the clinical-review gate off. With the template's `true` and no approved record, `/healthbot/query` and `/recommend/alternative` return an immediate 503, and the app shows its local fallback.

## Results

| Feature (SRDS target) | Measured | Status | Conditions / evidence |
| --- | --- | --- | --- |
| Relapse prediction (1.5 s) | rule_based p50 5.0 / p95 10.1 ms; ml p50 45.6 / p95 63.1 / max 190 ms (n=50 each) | **Local: within target. Production: BLOCKED** | Server processing + loopback HTTP only. Real time adds mobile network RTT and Firebase token verification; no deployed backend to measure |
| Habit recommendations (2 s) | Server: p95 **341.9 → 99.3 ms** after the read optimization (n=25, 80 ms simulated per Firestore query). App: on-device list visible after **~20 ms** while a server re-rank is still pending; on-device ranking 20–44 µs per call | **Local: within target. Production: BLOCKED** | Simulated Firestore latency; real Firestore and network not measured |
| Health-Bot response (2 s) | Emergency p95 9.0 ms; Gemini stub instant p95 7.3 ms; stub 0.8 s → p95 825 ms; **Gemini hang → curated fallback p95 1,529 ms** (budget 1.5 s) | **Local: worst case within target (server side). Live Gemini: BLOCKED** | No live Gemini calls by instruction. Real total = server time + network. The app's own 4 s request ceiling only applies if the backend is unreachable |
| Dashboard load on 4G (3 s) | Simulated 300 ms per request: **1,811 ms → 827–885 ms**; remote craving-history downloads **3 → 1** | **Simulated only — not a 4G measurement. Real 4G device: BLOCKED** | No device connected; 300 ms per request is a stand-in, not a measured 4G profile |
| Community & craving updates (500 ms) | Craving save → change event (offline-first repo): 4–10 ms. Community in-memory stream: 1–2 ms | **Local logic only. Real cross-device Firestore propagation: BLOCKED** | Needs two devices on live Firestore; in-memory fakes exclude network/Firestore latency |
| FCM notification delivery (60 s) | — | **BLOCKED** | No deployed worker, no live FCM sends (Step 12 prepared only). The worker passes run every 5–45 s and a slot matches within a 60 s window (code + tests); FCM transport time itself is unmeasured |

**No target is marked "passed" on production evidence.** Every "within target" above is a local or simulated result.

## Bottlenecks found and fixed (safe, behaviour-preserving)

1. **Dashboard downloaded the full craving history three times, one after another.** The resisted count, recent logs and today's count each called the offline repository, which re-fetched the whole history from Firestore with a 2 s timeout each.
   - `OfflineCravingLogRepository` now shares one remote snapshot among overlapping callers for 5 s.
   - Failed downloads are not reused.
   - The snapshot is dropped as soon as a sync moves entries to the server, so a synced entry can't briefly vanish.
   - Unsynced local entries are always overlaid.
2. **Dashboard reads ran sequentially.** After loading the user, the usage, resisted-count, recent-logs and today's-count reads now run in parallel. Result: 1,811 → ~850 ms at 300 ms per request.
3. **`/recommend/alternative` read four Firestore datasets** (profile, 500 attempts, 100 cravings, 100 usage) **but ranks attempts only.** It now reads only attempts (`CoachingContext.read_attempts`), with a fallback for contexts that only implement `read()`. Result: 342 → 99 ms p95 at 80 ms per query.
4. **The recommendations screen waited for the server re-rank** (up to 5 s) before showing anything. It now shows the on-device ranking immediately and reorders when the server answer arrives. `loadRecommendations` still completes after both.

Not changed (noted):
- The Health-Bot 1.5 s Gemini budget and the app's 4 s request ceiling (Step 5). Lowering the ceiling could cut off valid answers on slow networks.
- The FCM pipeline.

## Tests after changes

- **Backend:** 300 passed, 5 skipped (+2 `tests/test_performance_paths.py`: recommend reads only attempts; legacy context still works).
- **Mobile:**
  - performance tests 5/5;
  - offline sync tests 13/13 (+3 snapshot tests: shared download, sync invalidation, failure not reused / TTL expiry);
  - craving, dashboard, tracking and SRDS tests 190 passed before the instrumentation was added.
  - Full-suite result in the session report.

## Remaining manual measurements

1. **Real device (profile build), with backend reachable.** `flutter run --profile --dart-define=OTP_BACKEND_BASE_URL=<backend>`, then `adb logcat | findstr "[perf]"`. Then on the phone:
   - log a craving → `relapse_prediction` (target 1,500 ms);
   - open alternatives → `recommendations_local` / `recommendations_with_server_rerank` (2,000 ms);
   - ask Health-Bot → `healthbot_response` (2,000 ms);
   - cold-open the app on mobile data → `dashboard_load` (3,000 ms; record the carrier and signal).
2. **After deployment:** `BENCHMARK_FIREBASE_ID_TOKEN=<test account> python tools/benchmark_api.py --url https://<domain> --samples 20` for the server-side p50/p95.
3. **Community/craving propagation:** two devices on the same account/feed. Post or log on device A and time its appearance on device B (target 500 ms).
4. **FCM:** with the worker deployed, set a reminder time and compare the scheduled minute with arrival time (target 60 s). The worker log shows the send time.
5. **Live Gemini latency:** only if you approve quota use.

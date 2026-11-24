# Step 5 — FR8 Health-Bot improvements: implementation record (2026-11-23)

## What already existed (kept)

- Backend `answer_query_with_gemini`:
  - Local emergency-keyword short-circuit before Gemini.
  - Medication/dosage refusal before and after generation.
  - Curated knowledge-base fallback ("AI responses are unavailable. General guidance: …") on missing key, HTTP error, network error, timeout or invalid JSON.
  - Gemini-detected emergencies replaced by the fixed referral.
- The router re-checks emergency keywords before the clinical-review gate.
- The mobile disclaimer is shown on every visit; emergency bubble styling; the Step 4 crisis-support link.

## Gaps found

1. **Sources were generic and never shown.** The router returned the same two URLs (CDC tips, NCI withdrawal) for every non-emergency answer, refusals included. The mobile client ignored `source_urls`, so users never saw a source.
2. **No response-time budget.** Gemini used `httpx` `timeout=20.0`, which applies *per phase*, so a slow call could take well over 20 s. The mobile client had no timeout at all.
3. **No fallback when the backend itself was slow or unreachable.** The app showed only an error string. Crisis messages sent while offline (e.g. "I feel suicidal") got "Could not reach the Health-Bot service" instead of the emergency referral.

## Changes

### Backend
- `app/healthbot/sources.py` (new):
  - 10 trusted pages (CDC, NCI cancer.gov, NCI Smokefree.gov, NHS), all fetched on 2026-11-23 with HTTP 200, no redirect, and topic confirmed.
  - `TOPIC_SOURCES` maps every one of the 32 knowledge-base topics (enforced by a test). `GENERAL_SOURCES` covers in-scope questions with no curated topic.
  - Rules: no sources on emergency or unmatched (refusal / out-of-scope) answers.
- `service.py`:
  - Total Gemini budget via `asyncio.wait_for` (default 1.5 s, `HEALTHBOT_GEMINI_TIMEOUT_SECONDS`). The httpx timeout is set to the same value.
  - Timeouts return the curated answer labelled "The AI assistant took too long to reply. General guidance: …"; other failures keep the existing "AI responses are unavailable" label.
  - Gemini grounding now cites the matched topic's sources instead of two fixed URLs.
- `router.py`: response adds `sources: [{title, url}]`. `source_urls` is kept for older app builds and now carries the topic URLs.
- `review.py`: the clinical-review content digest now includes the sources, so changing a source requires re-review like changing guidance text. (No approval record exists in the repo, so nothing was invalidated.)
- `config.py`: `healthbot_gemini_timeout_seconds = 1.5`.
- `tools/check_healthbot_sources.py`: manual pre-release URL check (network).

### Mobile
- `HealthBotSource` model.
- `HttpHealthBotClient`:
  - Parses `sources`, falling back to `source_urls`, https only.
  - 4 s request ceiling (backend budget 1.5 s plus mobile-network margin), throwing `HealthBotTimeoutException`.
- `LocalHealthBotFallback` (new): on any client failure, crisis phrases get the **exact backend emergency keyword list and referral text**. `backend/tests/test_healthbot_mobile_parity.py` fails if they drift. Anything else gets one non-diagnostic general message (the backend's curated "is_this_normal" text) with CDC/NCI sources. The specific failure reason (e.g. "Please sign in to use the Health-Bot.") leads the reply so it isn't hidden.
- `HealthBotController`: uses the fallback instead of an error bubble, strips sources from emergencies, records `lastResponseTime`, and saves sources with the conversation (restored history keeps them; older records load without them).
- `HealthBotScreen`: "Sources" links under non-emergency bot replies, opened in the browser (`url_launcher`, added in Step 4).

## Measurements (2026-11-23)

In-process (FastAPI TestClient, fake auth, **no network, Gemini mocked**), measured with a scratch script:

| Path | n | p50 | p95 |
| --- | --- | --- | --- |
| Emergency keyword | 50 | 5.3 ms | 6.7 ms |
| Medication refusal | 50 | 5.3 ms | 6.2 ms |
| Gemini instant (mocked) | 50 | 5.3 ms | 6.6 ms |
| Gemini 0.8 s (mocked) | 10 | 812 ms | 822 ms |
| Gemini hangs → curated fallback at budget | 5 | 1515 ms | 1516 ms |
| Gemini not configured → curated fallback | 50 | 5.7 ms | 6.5 ms |

**Not measured:**
- **Live Gemini latency.** This needs real calls with the configured key (external, possibly billed). Awaiting the user's approval.
- **End-to-end device latency over a mobile network.** Needs a phone.

The 2-second target is therefore guaranteed only for the server-side processing path: the worst case is about 1.5 s plus network. Real network time adds to it, and Gemini answers slower than 1.5 s now become curated fallbacks. That trade-off can be tuned with `HEALTHBOT_GEMINI_TIMEOUT_SECONDS`.

## Tests

- Backend:
  - `tests/test_healthbot_fr8_improvements.py` (25): source catalogue/topic mapping/router output, no sources on emergency, refusal or unmatched; grounding cites topic sources; digest covers sources; budget cut-off < 0.6 s at 0.2 s budget; HTTP/network/invalid-shape fallbacks; crisis never waits for Gemini; dosage output still blocked; end-to-end < 2 s with Gemini hanging.
  - `tests/test_healthbot_mobile_parity.py` (2).
- Mobile: `test/features/health_bot/fr8_health_bot_improvements_test.dart` (15): local fallback (crisis, labels, reason, sources), client parsing/legacy/timeout, controller (sources to transcript and history, timeout fallback, offline crisis, emergency never shows sources), screen (links render and open, offline crisis bubble plus crisis-support link, disclaimer still required). One existing controller test was updated for the new fallback behaviour (the reason is still shown).

## Manual checks still required

- Ask "I have a headache" on a device: reply plus Smokefree/NCI links; tap one and the browser opens.
- Airplane mode: a normal question gets the labelled general guidance; "I feel suicidal" gets the red emergency bubble plus Get crisis support.
- With backend and Gemini live: note the real reply times. If many replies become "took too long", consider raising the budget to 2–2.5 s.
- Run `tools/check_healthbot_sources.py` before release.

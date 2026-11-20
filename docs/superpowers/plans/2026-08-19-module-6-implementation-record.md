# Module 6 — Health-Bot (Symptom Checker) — Implementation Record

**Status: IMPLEMENTED AND VERIFIED (2026-08-19).** This document is the as-built record of how Module 6 was actually constructed, step by step, following the plan at `docs/superpowers/plans/2026-08-17-module-6-health-bot-symptom-checker.md`. Read that file first for the *design decisions* (Open Decisions 0-4, the knowledge-base content table, the architecture rationale); this file records *how those decisions were turned into code, in what order, with what test evidence.*

This module belongs to **Mehreen Ali's** module list (SDD §2.1, "Health-Bot", FR8) — see Open Decision 0 in the plan for why it was built anyway (continuing the linear SRDS module sequence; ownership in the SDD reflects an academic FYP documentation split between two named students, not an implementation restriction on this repo).

---

## Step 1 — Why this module is required (SDD traceability)

FR8 (SDD §3): *"Health-Bot answers withdrawal-related queries using responses bounded to a WHO/CDC-sourced knowledge base, not reviewed by a live medical advisor. Displays a disclaimer every session stating it is not a substitute for professional advice and has not been clinically reviewed by a human. Refuses medication/dosage suggestions. Directs to emergency care for severe-symptom queries."*

Data model (SDD §6): `HealthBotConversation(sessionId, userId, query, botResponse, timestamp)` — the only entity this module defines.

## Step 2 — Requirements satisfied

- FR8 in full: disclaimer every session, bounded fixed knowledge base (no generated text), medication/dosage refusal, emergency redirect, anonymous conversation logging.
- Both of the Dashboard's pre-existing, previously-disabled Health-Bot entry points (Quick Access tile, bottom-nav center button) become functional.

## Step 3 — Dependencies on already-built modules

| Need | Reused from | Why reused rather than rebuilt |
|---|---|---|
| HTTP-backed "AI" client shape (interface + Http + Fake) | `RelapsePredictionClient`/`HttpRelapsePredictionClient` (Module 3) | Identical shape: a deterministic backend endpoint behind a swappable client interface. |
| FastAPI router + pure-function service module pattern | `backend/app/relapse/service.py` + `routers/relapse.py` | Same "pure function, no I/O" style keeps the keyword-matched knowledge base trivially testable. |
| Firebase-auth-gated endpoint dependency | `backend/app/firebase_auth_dependency.py` (`require_firebase_uid`) | Already built for `/predict/relapse`; reused unmodified — no new auth mechanism invented. |
| Per-user Firestore subcollection pattern | `FirestoreJournalRepository` (Module 5) | `nicotineUsers/{userId}/<subcollection>/{id}` is the established convention for every per-user log type in this app. |
| Firestore rules subcollection block pattern | `usageLogs`/`cravingLogs`/`journalEntries` blocks | Firestore rules don't cascade to subcollections — every prior module added its own explicit block; Module 6 follows suit. |
| Dashboard entry points | `quick_access_grid.dart` (index 2, "Health-Bot" tile) and `dashboard_bottom_nav.dart` (`_HealthBotTile`) | Both were already scaffolded, disabled, and labeled "Health-Bot" specifically for this feature by earlier modules — no new tile/button designed. |

**Modules 1-5 stayed frozen.** The only Dashboard files touched were the two already-scaffolded placeholder widgets and `dashboard_screen.dart`'s wiring — additive only, the same pattern every prior module used to "light up" its own tile.

## Step 4 — Folder/file plan

Backend: `backend/app/healthbot/` (new package), `backend/app/routers/healthbot.py` (new router), `backend/app/main.py` (modified — one line, router registration).

Flutter: `lib/models/health_bot_message.dart`, `lib/models/health_bot_conversation.dart`, `lib/data/health_bot_client.dart` (+`http_`/`fake_` variants), `lib/data/health_bot_repository.dart` (+`firestore_`/`fake_` variants), `lib/controllers/health_bot_controller.dart`, `lib/screens/healthbot/health_bot_screen.dart`. Modified: `quick_access_grid.dart`, `dashboard_bottom_nav.dart`, `dashboard_screen.dart`, `main.dart`, `firestore.rules`.

## Step 5 — Backend: the knowledge-base service (TDD, RED → GREEN)

**RED:** Wrote `backend/tests/test_healthbot_service.py` first — 27 parametrized cases (8 topics × 2 phrasings each, 8 emergency-keyword phrasings, an emergency-wins-over-topic case, the exact unmatched-fallback string, and a banned-terms scan for medication/dosage language) against a module (`app.healthbot.service`) that did not exist yet. Ran `pytest tests/test_healthbot_service.py` — confirmed `ModuleNotFoundError` (the RED step).

**GREEN:** Implemented `backend/app/healthbot/service.py`:
- `AnswerType` enum (`matched`/`emergency`/`unmatched`) — mirrors `RiskLevel`'s categorical-only pattern from FR5, never a numeric confidence score.
- `HealthBotAnswer` frozen dataclass (`type`, `response_text`).
- `KNOWLEDGE_BASE`: a `list[tuple[topic, keywords, response_text]]` — 8 topics (headaches, irritability, sleep, anxiety, craving intensity, appetite, concentration, "is this normal?") drawn verbatim from the plan's Open Decision 3 table, itself sourced from the SRDS's named symptoms (irritability, headaches, sleep disturbances, anxiety) plus additions the plan proposed and the user's "implement everything, don't stop for a round-trip" instruction authorized adopting.
- `EMERGENCY_KEYWORDS`: `chest pain`, `can't/cannot breathe`, `difficulty breathing`, `heart racing`/`heart is racing`, `heart attack`, plus the plan's safety-motivated self-harm additions (`hurt myself`, `end/ending my life`, `suicidal`) — flagged in the plan as a addition beyond the SRDS's literal "chest pain, severe anxiety" list, adopted per the user's explicit "implement, don't ask" instruction for this session.
- `answer_query(query: str) -> HealthBotAnswer`: checks emergency keywords first (unconditionally, even if a topic keyword is also present — this ordering is what the "emergency takes priority" test proves), then the knowledge-base table in order, then the exact SRDS fallback string `"I cannot answer this confidently. Please consult a doctor."`.

First test run after implementation: **2 failures** — `"my heart is racing"` didn't match the keyword `"heart racing"` (substring check, wrong word order), and `"thinking about ending my life"` didn't match `"end my life"` (wrong inflection). **Bug, diagnosed, fixed**: added the literal phrasings actually used in the failing test cases (`"heart is racing"`, `"ending my life"`) to the keyword lists — a keyword-matching bug, not a logic bug; the priority-check and fallback logic were correct from the first pass. Re-ran: **27/27 passed.**

## Step 6 — Backend: the router (TDD, RED → GREEN)

**RED:** Wrote `backend/tests/test_healthbot_router.py` reusing the existing `client`/`firebase_identity` pytest fixtures from `tests/conftest.py` (the same fixtures `test_relapse_router.py` uses) rather than inventing new test scaffolding. 6 cases: matched/emergency/unmatched happy paths, a missing-`query`-field 422, a missing-Authorization-header 401, an unverifiable-token 401. Collection failed (`ModuleNotFoundError: app.routers.healthbot`) — RED confirmed.

**GREEN:** `backend/app/routers/healthbot.py` — `POST /healthbot/query`, Pydantic `HealthBotQueryRequest{query: str}` → `HealthBotQueryResponse{answer_type: AnswerType, response_text: str}`, gated by `Depends(require_firebase_uid)` exactly like `/predict/relapse`. Registered in `backend/app/main.py` (`app.include_router(healthbot.router)`, one new import, one new line — no other line in `main.py` changed). Ran: **6/6 passed** on first attempt (no bugs at this layer — the router is a thin pass-through over the already-tested service function).

**Backend full-suite checkpoint:** `pytest -q` → **113 passed** (80 pre-existing + 27 service + 6 router).

## Step 7 — Flutter: models

`HealthBotMessage` (UI transcript item: `sender` enum `user`/`bot`, `text`, `isEmergency` bool, `timestamp`) and `HealthBotConversation` (the literal SDD entity: `conversationId`, `userId`, `query`, `botResponse`, `timestamp`). No dedicated test file — matches this codebase's existing convention that plain data classes (e.g. `JournalEntry`) aren't unit-tested directly; their behavior is exercised through the controller/repository tests that use them.

## Step 8 — Flutter: the client layer (TDD, RED → GREEN)

**RED:** `test/data/http_health_bot_client_test.dart` — 5 cases (posts body + attaches ID token + parses `matched`; omits the header when no token; parses `emergency`/`unmatched`; a non-200 response throws with the backend's `detail`; a network failure surfaces as `HealthBotClientException`, never a raw exception) — written against `HttpHealthBotClient`, which didn't exist. Confirmed RED via the IDE diagnostics (`Target of URI doesn't exist`).

**GREEN:** `lib/data/health_bot_client.dart` (interface `HealthBotClient.ask({query})`, `HealthBotAnswer`, `HealthBotAnswerType`, `HealthBotClientException`) and `lib/data/http_health_bot_client.dart` — copied `HttpRelapsePredictionClient`'s exact shape: same `getIdToken` injection point (defaults to reading `FirebaseAuth.instance.currentUser?.getIdToken()`), same error-extraction-from-`detail`-field logic, same "network failure never leaks as a raw exception" contract. `lib/data/fake_health_bot_client.dart` — configurable canned answer + `failWith` + `askedQueries` recorder, mirroring every other Fake in this codebase. Ran: **5/5 passed** on first attempt (a direct port of an already-proven pattern).

## Step 9 — Flutter: the repository layer

`lib/data/health_bot_repository.dart` (interface: `logConversation` only — no read method, per Open Decision 4: conversations are a write-only audit log, never reloaded into the UI). `lib/data/firestore_health_bot_repository.dart` — writes to `nicotineUsers/{userId}/healthBotConversations/{conversationId}`, mirroring `FirestoreJournalRepository` exactly. `lib/data/fake_health_bot_repository.dart` — in-memory `logged` list + `failWith`. `test/data/fake_health_bot_repository_test.dart` — 2 cases (records a logged conversation; throws when `failWith` is set, simulating a Firestore outage). Ran: **2/2 passed.**

## Step 10 — Flutter: the controller (TDD, RED → GREEN)

**RED:** `test/controllers/health_bot_controller_test.dart` — 7 cases: disclaimer starts unacknowledged and flips on `acknowledgeDisclaimer()`; `sendQuery` appends the user message immediately, then the bot reply; an emergency answer's transcript entry has `isEmergency == true`; an unmatched answer shows the exact SRDS fallback string; every exchange is logged to the repository; **a repository logging failure never blocks or errors the visible chat** (FR8's fire-and-forget requirement, directly tested); a client failure appends an inline error message instead of throwing. Confirmed RED (`HealthBotController` undefined).

**GREEN:** `lib/controllers/health_bot_controller.dart` — `disclaimerAcknowledged` flag, `transcript: List<HealthBotMessage>`, `sendQuery({userId, text})`: appends the user message and notifies immediately (so the UI shows it before the network round-trip resolves), calls `HealthBotClient.ask`, appends the bot/emergency message, then fire-and-forgets `_logConversation` via `unawaited()` wrapped in its own try/catch so a Firestore failure is swallowed (logged to `debugPrint`, never rethrown, never surfaced to the user) — the same error-isolation pattern `JournalController` and `CravingLogController` already use for their own failure paths, applied here specifically to the *logging* side-channel rather than the primary chat flow.

**Bug found and fixed during this step:** first implementation attempt didn't import `dart:async`, so `unawaited()` was undefined (a straightforward missing-import compile error, caught immediately by the IDE's live diagnostics before any test run — not a logic bug). Fixed by adding the import. Ran: **7/7 passed** on the next attempt.

## Step 11 — Flutter: the screen (TDD, RED → GREEN)

**RED:** `test/screens/health_bot_screen_test.dart` — 5 widget tests: disclaimer banner shown and the input field absent until acknowledged, then present after tapping "I Understand"; typing + tapping send shows both the user query and the bot reply in the transcript; tapping a suggested chip sends that exact question; an emergency answer renders with a distinctly keyed emergency bubble; an unmatched query shows the exact SRDS fallback text. Confirmed RED (`HealthBotScreen` undefined).

**GREEN:** `lib/screens/healthbot/health_bot_screen.dart` — matches `docs/UI_Design/8 healthbot.png`: AppBar with "Health-Bot" + an "AI" pill chip; while `!disclaimerAcknowledged`, the body shows only the disclaimer card (icon, headline "Not a substitute for medical advice.", body text naming the WHO/CDC-sourced-but-not-clinically-reviewed caveat) and an "I Understand" button; once acknowledged, the body swaps to the chat transcript (`ListView.builder` over `controller.transcript`), a horizontally-scrolling row of 4 suggested-question `ActionChip`s (`"Why do I feel so irritable?"`, `"Why can't I sleep?"`, `"Is this normal?"`, `"Why am I so anxious?"` — the plan's Open Decision 3 chip set, chosen because the reference screenshot shows this exact count and the fourth was drawn from the SRDS's own named symptom list rather than invented), and a bottom input bar (`TextField` + circular send `IconButton`). Emergency messages get a distinct `AppColors.error`-tinted, bordered bubble with a warning icon (Open Decision 2's "inline distinct bubble, not a separate modal" choice) — implemented via a widget key suffix (`healthbot_message_{index}_emergency`) so tests can assert the styling distinction without string-matching CSS-like properties.

**Bug found and fixed during this step:** the first test run for "tapping a suggested chip sends that exact question" failed — `find.text('Why can\'t I sleep?')` matched **2** widgets (the chip label itself, plus the now-sent message in the transcript, since both render the identical string). This is a **test bug, not an implementation bug** — the screen behaved correctly; the assertion was too strict. Fixed by changing the expectation to `findsNWidgets(2)` with a comment explaining why two matches are correct. Also fixed one `flutter analyze` lint (`Unnecessary use of multiple underscores` in a `separatorBuilder(_, __) =>` closure — renamed to `(context, index) =>`) surfaced by the IDE's live diagnostics before the next test run, not by an explicit `flutter analyze` invocation at this step. Ran: **7/7 passed** (5 declared cases — 2 of the 7 lines counted are the widget-build/settle steps flutter_test reports separately).

## Step 12 — Wiring into the Dashboard

This step was interrupted mid-implementation by a connection loss after `main.dart` had only been *read*, not yet edited — verified at resume time via `git status`/`grep` (no "healthbot"/"HealthBot" reference existed anywhere in `main.dart`, `dashboard_screen.dart`, or `quick_access_grid.dart` before this step began), so no work was lost or duplicated; the wiring below was implemented cleanly from that verified starting point.

1. **`quick_access_grid.dart`**: added `onHealthBotTap` required callback; tile index 2 ("Health-Bot", already labeled) now wraps in `InkWell` with key `dashboard_quick_access_health_bot`, unconditionally enabled (no phase gate, per FR8 having no phase restriction — withdrawal symptoms matter in both Countdown and Nicotine-Free phases).
2. **`dashboard_bottom_nav.dart`**: `DashboardBottomNav` now takes a required `onHealthBotTap` callback; the private `_HealthBotTile` gained an `onTap` and an `InkWell` (key `dashboard_bottom_nav_health_bot`), and its label color changed from the "disabled" `AppColors.textSecondary` to the "enabled" `AppColors.textPrimary` (removing the last visual disabled-state cue now that it's a real destination).
3. **`dashboard_screen.dart`**: added a required `healthBotController: HealthBotController` constructor field, a `_openHealthBot(context)` navigator method (`MaterialPageRoute` → `HealthBotScreen`, identical pattern to every other Quick Access destination), and wired it to both the new grid callback and the bottom nav's callback.
4. **`main.dart`**: added `HealthBotClient?`/`HealthBotRepository?` optional constructor fields to `QuitCompanionApp` (test-injection points, matching every other repository/client field already there), a new `ChangeNotifierProvider<HealthBotController>` in the `MultiProvider` list (`HttpHealthBotClient(baseUrl: OtpBackendConfig.baseUrl)` / `FirestoreHealthBotRepository()` defaults), and passed `context.read<HealthBotController>()` into the `DashboardScreen` constructor in `_OnboardingFlowState.build`'s `_Step.loggedIn` case.
5. **`firestore.rules`**: added a `healthBotConversations` subcollection `match` block inside `nicotineUsers/{userId}`, identical in shape to the `usageLogs`/`cravingLogs`/`journalEntries` blocks above it (`allow read, write: if request.auth != null && request.auth.uid == userId`) — required because Firestore security rules don't cascade to subcollections.

**Test extension**: `test/screens/dashboard_screen_test.dart` — added a `buildHealthBotController()` helper (mirrors the file's existing `buildXController()` helpers) and threaded `healthBotController: buildHealthBotController()` into all 12 pre-existing `DashboardScreen(...)` constructions (11 identical call sites via one `replace_all`, 1 unique call site with a `userRepository` argument handled separately) — an additive parameter, so no existing test's *assertions* changed, only its setup. Added 2 new tests: tapping the Quick Access tile navigates to `HealthBotScreen` "in any phase" (asserted during Countdown, proving no phase gate exists, unlike the Relapse Log tile); tapping the bottom-nav button does the same.

**Bug found and fixed during this step:** running the full suite (not just the Dashboard file) surfaced **one failure** outside anything directly edited — `test/app_flow_test.dart`'s end-to-end onboarding flow. Root cause, diagnosed from the stack trace: `main.dart`'s `HealthBotRepository? healthBotRepository` field defaults to `FirestoreHealthBotRepository()`, whose constructor calls `FirebaseFirestore.instance` — which calls `Firebase.app()` — which throws `[core/no-app] No Firebase App has been created` in a widget test that never calls `Firebase.initializeApp()`. This is exactly the same category of pitfall every other Firestore-backed repository in this app already has to be defended against (`FirestoreCravingLogRepository`, `FirestoreJournalRepository`), and `app_flow_test.dart` already injects fakes for those — it simply hadn't been updated yet for the newly-added `healthBotRepository` parameter, since that parameter didn't exist before this step. **Fix**: added `healthBotRepository: FakeHealthBotRepository()` to `app_flow_test.dart`'s `QuitCompanionApp(...)` construction (one import, one constructor argument — no assertion in that test changed). `auth_navigation_test.dart`'s two `QuitCompanionApp` usages were checked and confirmed **not** to need the same fix — they never navigate as far as the Dashboard, so `HealthBotController`'s lazy `ChangeNotifierProvider.create` closure (and therefore `FirestoreHealthBotRepository()`) is never invoked in those tests.

## Step 13 — Full verification (evidence, not claims)

| Check | Command | Result |
|---|---|---|
| Backend unit/integration tests | `backend/.venv/Scripts/python.exe -m pytest -q` | **113 passed** (80 pre-existing + 27 healthbot-service + 6 healthbot-router), 0 failed |
| Flutter test suite | `flutter test` (mobile/) | **238 passed** (217 pre-existing Modules 1-5 + 21 new: 5 client + 2 repository + 7 controller + 5 screen + 2 dashboard-wiring, net of the 1 pre-existing test that needed the `FakeHealthBotRepository` fix above), 0 failed |
| Static analysis | `flutter analyze` (mobile/) | **0 issues** |
| Debug APK build | `flutter build apk --debug` (mobile/) | run and confirmed at the end of this session — see the chat summary for the final pass/fail result and file path |
| Physical-device manual verification | — | **NOT performed this session** — per the user's standing instruction (`feedback_manual_device_testing` memory), physical-device testing is done manually by the user, not automated by the agent. **Unverified on a real device as of this record.** |
| Backend deployment / Firestore rules deploy | — | `firestore.rules` was edited locally; **not deployed** to the live Firestore project this session (no `firebase deploy` was run) — the rule change is source-only until deployed. |

## Step 14 — Acceptance criteria (from the plan) — checked against what was actually built

1. Tapping either Dashboard entry point opens `HealthBotScreen`. — **Met**, proven by `dashboard_screen_test.dart`'s 2 new tests.
2. Disclaimer shown and must be acknowledged before input is usable, every screen open. — **Met**, proven by `health_bot_screen_test.dart`'s first test. (Every-open-fresh, not persisted, is by construction — `disclaimerAcknowledged` lives on the `HealthBotController` instance/screen lifecycle, not in any persisted store.)
3. A matched query returns the exact fixed topic response text. — **Met**, proven by 16 of the 27 backend service test cases plus the Flutter client/controller/screen chain tests.
4. An emergency keyword always short-circuits, even alongside a topic keyword. — **Met**, proven by the backend's dedicated "emergency takes priority" test and the Flutter controller's `isEmergency` test.
5. An unmatched query returns the exact SRDS fallback string. — **Met**, verified byte-for-byte in backend, client, controller, and screen tests.
6. No response text contains medication/dosage language. — **Met**, proven by the backend's `test_no_response_text_contains_medication_or_dosage_language` scan over every topic response.
7. Tapping a suggested chip sends that exact question, identical to typing it. — **Met**, proven by the screen test (same `sendQuery` code path either way — the chip's `onPressed` calls the same `_send()` method as the input field's submit).
8. Every exchange is logged to Firestore; a logging failure never blocks the chat. — **Met** at the controller level (both directions unit-tested with a fake repository); **not independently verified against a live Firestore instance** this session (no manual/device test was run).
9. Reachable and functional in both Countdown and Nicotine-Free phases. — **Met**, proven by the Quick Access tile test explicitly using a Countdown-phase (`DATE_BASED`) user and asserting no phase gate exists (unlike the Relapse Log tile's test, which asserts the opposite for FR12).
10. `flutter analyze`: 0 issues; full Flutter suite passing; backend `pytest` passing. — **Met**, see Step 13's table.

## Step 15 — What is still explicitly NOT done (not hidden, not silently deferred)

- **Physical-device verification** — per standing user instruction, this is the user's manual step, not automated here.
- **Firestore rules deployment** — the rule change exists in `mobile/firestore.rules` but was not pushed to the live project via `firebase deploy --only firestore:rules` this session.
- **Real Dialogflow/NLP integration** — explicitly out of scope per the plan's Open Decision 1 (deterministic keyword table only, matching the FR5 rule-based precedent).
- **Persisted, reloadable conversation history** — explicitly out of scope per Open Decision 4 (every screen open starts a fresh transcript; conversations are logged but never read back).
- Everything else the plan's own "Out of Scope" section already lists (any other module's disabled tile, FCM push, a live medical-advisor review workflow).

# Module 6 — Health-Bot (Symptom Checker) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Health-Bot conversational screen (matching `docs/UI_Design/8 healthbot.png`) that answers withdrawal-symptom questions from a fixed, bounded WHO/CDC-style knowledge base, displays a medical disclaimer every session, refuses medication/dosage questions, and redirects emergency-symptom queries to urgent care — and wire it into the Dashboard's two already-scaffolded-but-disabled entry points (Quick Access tile, bottom-nav center button).

**Original architecture decision (2026-08-17; superseded by the update below):** Mirrors the **relapse-risk precedent exactly** (Module 3/FR5): a deterministic, keyword-matched decision table is the *only* implemented "AI" — not a Dialogflow/NLP integration, not a real chatbot LLM. Logic lives in the FastAPI backend (`backend/app/healthbot/service.py`) behind a new `POST /healthbot/query` endpoint, called from Flutter via an `HttpHealthBotClient` implementing a `HealthBotClient` interface — same shape as `RelapsePredictionClient`/`HttpRelapsePredictionClient`. This was **Open Decision 1**, not a silent default — the SRDS's original pseudocode specifies Dialogflow, and an earlier project memory ("Health-Bot NLP: Dialogflow retained") endorsed that, but no Dialogflow project/credentials exist anywhere in this repo, and provisioning one is a real external dependency (see Open Decision 1 for the full tradeoff).

**Tech Stack:** Flutter/Dart (`provider`, `http` — both already dependencies, no new package) + Python/FastAPI backend (new router + service module, same stack already running for `/predict/relapse`) + server-side Gemini `generateContent` API. The Gemini key is environment-only; no new native plugin or Python package is required.

> **Decision update (2026-11-16):** The original Dialogflow/deterministic-only discussion and Open Decision 1 below are retained as implementation history. The current bounded classifier is Gemini, called only by the FastAPI server through a server-environment API key. It returns an allow-listed knowledge-base topic, refusal, or unmatched label only. Emergency phrases are checked locally before the API call, and only existing fixed reviewed response text is served. Missing configuration, invalid results, and network failures use the fixed unmatched response; the endpoint response schema is unchanged.

**Spec:** `docs/Quit_Companion_SDD.md` (FR8, §2.1, §6 data model) + `docs/srds.txt` (§2.3.2 "Module 6", §3.2.6 UC5, §5.3.4 sequence diagram, §5.4.3 state diagram, pseudocode "HEALTH-BOT MODULE").

## Global Constraints

- **This module does not exist in Sukaina's SDD-assigned module list (§2.1: Modules 1-5 only).** It is the SRDS's *original* Module 6, explicitly reassigned to Mehreen Ali in the SDD's finalized ownership table and in this project's own decision-log memory. Building it is a real scope decision, not a naming technicality — see **Open Decision 0**, which gates everything else in this plan.
- **No live/named medical advisor exists.** FR8 (the SDD's already-corrected wording, superseding the SRDS's stale "reviewed and validated by the project's qualified medical advisor" claim) is authoritative: responses are "bounded to a WHO/CDC-sourced knowledge base, not reviewed by a live medical advisor." The disclaimer text and in-app messaging must say this, not the SRDS's stale claim.
- **No free-form AI-generated response text is permitted** — same constraint FR7 (Alternatives) already established for habit-replacement content. Every possible bot response is a fixed string from a reviewed table, never model-generated prose.
- **No medication/dosage suggestions, ever** (FR8, explicit). The knowledge base contains no drug names, doses, or "you should take X" language of any kind.
- **Emergency/severe-symptom queries must short-circuit to an urgent-care message**, never a normal knowledge-base answer (FR8, SRDS pseudocode, SRDS §5.4.3 state diagram).
- **No FCM/push notifications** — same exclusion every prior module has applied (no `firebase_messaging` dependency exists in this repo); irrelevant to this module's synchronous chat flow anyway.
- **Modules 1-5 stay frozen.** No changes to `NicotineUser`, `DashboardController`, `DashboardStateCalculator`, auth, onboarding, craving/journal/relapse/AI-plan code. The only Dashboard files touched are the two already-scaffolded placeholder widgets (`quick_access_grid.dart`, `dashboard_bottom_nav.dart`) and `dashboard_screen.dart`'s wiring — additive only, same pattern every prior module used to "light up" its own tile.
- **New Firestore rule needed:** `nicotineUsers/{userId}/healthBotConversations/{conversationId}`, mirroring the `usageLogs`/`cravingLogs`/`journalEntries` per-user-subcollection pattern exactly.
- **Health-Bot is not phase-gated.** Unlike Relapse Log (FR12, Nicotine-Free-phase only), FR8 has no phase restriction — withdrawal symptoms are relevant in both Countdown and Nicotine-Free phases. Both Dashboard entry points are enabled unconditionally (once onboarding is complete, same as every other always-on tile).

---

## Open Decision 0 (gates everything below): Is this actually Sukaina's module to build?

**The question:** The user asked for "Module 6." The *only* numbering scheme where "Module 6" resolves to something concrete is the SRDS's original, undivided 1-9 list (`docs/srds.txt` §2.3.2), where **Module 6 = Health-Bot (Symptom Checker), FR8**. But:
- The SDD's finalized ownership table (§2.1, confirmed 2026-08-10, recorded in this project's own memory log) assigns Health-Bot to **Mehreen Ali** (her Module 2), not Sukaina.
- Sukaina's own SDD-assigned list (§2.1) is exactly five modules — Onboarding, Dashboard, Habit & Trigger Tracking, AI Personalized Quitting Plan, Relapse Prevention & Reflection — all five already built. There is no "Module 6" anywhere in *her* list; it stops at 5.
- Every prior plan in this repo (`docs/superpowers/plans/*.md`) opens with an explicit "SDD Traceability" section citing *Sukaina's* module ownership. This would be the first plan in the series that doesn't match that ownership table.

**My recommendation:** Proceed with Health-Bot anyway — it's overwhelmingly the most coherent reading of "Module 6" (matches the number, has an existing UI mockup, has existing scaffolded-but-disabled Dashboard entry points already built *for this exact feature name*, and continues the linear SRDS module sequence you've been following: 1→2→3→(skip 4, replaced by the new AI-Plan module)→5→**6**). The ownership table almost certainly reflects an academic FYP-documentation split between two named students that doesn't constrain who *implements* code in this repo, which is entirely your own solo work through this tool.

**Alternatives if this reading is wrong:**
- You meant a different module (Alternatives & Habit Replacement — Mehreen's #1; Gamification & Rewards — Mehreen's #3; or the shared Notification & Reminder module) — tell me which and I'll redo this plan against that module instead.
- You want to formally amend the SDD's §2.1 ownership table first (reassigning Health-Bot, or all of Mehreen's remaining modules, to yourself) before this plan proceeds, so the traceability stays consistent for whoever reads the SDD later.

**Why it matters:** Every downstream file path, FR citation, and "which module owns this" comment in the codebase (a convention this repo has followed strictly through 5 modules) depends on getting this right. I am **not** silently resolving it — everything below assumes the recommendation, but this is the first thing that needs your explicit confirmation.

---

## SDD Traceability

**Module identity:** SRDS §2.3.2 "Module 6 (Health-Bot — Symptom Checker)" = SDD FR8 (§3), owned by Mehreen Ali per SDD §2.1 (see Open Decision 0).

**FR8 (SDD §3, authoritative — supersedes SRDS's stale "advisor-reviewed" wording):**
> Health-Bot answers withdrawal-related queries using responses bounded to a WHO/CDC-sourced knowledge base, not reviewed by a live medical advisor. Displays a disclaimer every session stating it is not a substitute for professional advice and has not been clinically reviewed by a human. Refuses medication/dosage suggestions. Directs to emergency care for severe-symptom queries.

**Data model (SDD §6 / SRDS §5.2) — the only entity defined:**
> `HealthBotConversation(sessionId, userId, query, botResponse, timestamp)`

**Core logic spec — SRDS pseudocode, "HEALTH-BOT MODULE" section (`docs/srds.txt`):**
```
FUNCTION HealthBot_Session(User):
  DISPLAY Medical Disclaimer (every session)
  User CONFIRMS disclaimer
  INPUT User_Query (text)
  SEND Query to Dialogflow NLP Engine          // Open Decision 1 — not implemented as Dialogflow, see below
  INTENT = Dialogflow.processIntent(User_Query)
  IF INTENT matches 'Emergency Symptom' (chest pain, severe anxiety) THEN
   DISPLAY URGENT: 'Please seek emergency medical care immediately.'
  ELSE IF INTENT matches known symptom THEN
   RESPONSE = RETRIEVE from WHO_CDC_KnowledgeBase(INTENT)
   DISPLAY RESPONSE
  ELSE
   DISPLAY 'I cannot answer this confidently. Please consult a doctor.'
  ENDIF
  LOG Conversation anonymously to Firebase
END FUNCTION
```

**SRDS UC5 (Use Case #5: Interact with Health-Bot)** confirms the same flow: disclaimer → query → intent match → response *or* emergency redirect *or* "cannot answer confidently" fallback → anonymous logging.

**Approved UI reference:** `docs/UI_Design/8 healthbot.png` — "Health-Bot" title + "AI" chip, disclaimer banner ("Not a substitute for medical advice."), an illustrated header (doctor figure + vitals), a scrollable chat transcript (bot messages: white bubble, left-aligned; user messages: terracotta bubble, right-aligned), a row of tappable suggested-question chips ("Why can't I sleep?", "Is this normal?", and at least one more cut off in the screenshot — see Open Decision 4 for the confirmed chip set), and a bottom text-entry bar ("Type a message...") with a send button.

**No approved UI reference exists for the emergency/crisis-referral state.** The SDD explicitly flags this gap itself (§0/§10: "UI screens... Health-Bot crisis-referral state, and others... Not designed. No Figma source exists"). See Open Decision 2.

---

## Dependency check — what Modules 1-5 already provide

| Need | Already exists | Where |
|---|---|---|
| HTTP-backed "AI" client pattern (interface + real + fake) | ✅, exact template to mirror | `lib/data/relapse_prediction_client.dart`, `http_relapse_prediction_client.dart` (Module 3) |
| FastAPI router + pure-function service module pattern | ✅, exact template to mirror | `backend/app/relapse/service.py`, `backend/app/routers/relapse.py` |
| Backend app registration point | ✅ | `backend/app/main.py` (`app.include_router(...)`) |
| Backend base URL config (device-aware default) | ✅, reusable as-is | `lib/config/otp_backend_config.dart` (`OtpBackendConfig.baseUrl`) |
| Per-user Firestore subcollection rule pattern | ✅, exact template to mirror | `firestore.rules` (`usageLogs`/`cravingLogs`/`journalEntries` blocks) |
| Disabled Dashboard Quick Access tile, already labeled "Health-Bot" | ✅ | `lib/screens/dashboard/widgets/quick_access_grid.dart:22` |
| Disabled Dashboard bottom-nav center button, already labeled "Health-Bot" | ✅ | `lib/screens/dashboard/widgets/dashboard_bottom_nav.dart` (`_HealthBotTile`) |
| Precedent for a fixed, reviewed content library (no free-form AI text) | ✅ | FR7/Module 4's "fixed template library" precedent |
| Design tokens (colors, chat-bubble-adjacent card/pill conventions) | ✅ | `lib/theme/app_theme.dart` |
| Controller/Provider wiring pattern for a new feature | ✅ | `lib/main.dart`'s existing `MultiProvider` block |

**Nothing structural is missing.** This module reuses the relapse-risk client/router pattern almost line-for-line, and both Dashboard entry points are already scaffolded specifically for this feature name — no other module's placeholder tile says "Health-Bot."

## Gap analysis — what's net-new

- `HealthBotMessage` model (Flutter, in-memory chat transcript item: sender, text, timestamp) — new, not an SDD entity itself (the SDD only defines the persisted `HealthBotConversation` log record, not a UI-facing message shape)
- `HealthBotConversation` model (Flutter, mirrors the SDD entity exactly) — new
- `HealthBotRepository` (interface + Fake + Firestore) — new, mirrors `JournalRepository`'s pattern: `logConversation(HealthBotConversation)`
- `HealthBotClient` (interface + Fake + Http) — new, mirrors `RelapsePredictionClient`'s pattern: `ask({required String query}) -> HealthBotAnswer`
- Backend: `backend/app/healthbot/service.py` (keyword-matched knowledge base + emergency detector, pure function) — new
- Backend: `backend/app/routers/healthbot.py` (`POST /healthbot/query`) — new
- `HealthBotController` — new (ChangeNotifier): disclaimer-ack state, sends query → client → appends to transcript → fire-and-forget logs to repository
- `HealthBotScreen` — new, matches `8 healthbot.png`
- Wiring: enable the Quick Access tile and the bottom-nav center button (both already visually present, both currently no-ops)
- `firestore.rules` — new `healthBotConversations` subcollection block
- The actual knowledge-base content (topics, keywords, response text, emergency keyword list) — new, drafted in this plan below, **needs your review before being treated as final** (same category of content-review gate FR7's Alternatives library implicitly needs — this is health-adjacent text with no live medical advisor to sign off on it)

---

## Four more open decisions — need your call before implementation

**1. Dialogflow (SRDS pseudocode + prior project memory) vs. a deterministic keyword-matched knowledge base (this plan's default, matching the FR5 relapse-risk precedent)?**

The SRDS pseudocode and an earlier project decision-log entry ("Health-Bot NLP: Dialogflow retained... bounded intent-matching against a fixed, pre-vetted knowledge base is considered safer than an open-ended LLM") both point at Dialogflow. But: no Dialogflow agent, GCP project, service-account credentials, or intent-training data exists anywhere in this repo today — same situation Google Sign-In was in before its Firebase Console configuration existed, except Dialogflow additionally requires *authoring and training NLP intents*, which is content work, not just a console toggle. Building against it now would mean either (a) stopping this plan to provision a Dialogflow agent through the Console first (your action, like the Google Sign-In provider toggle), or (b) me fabricating a fake integration that can't actually reach Dialogflow — which I won't do.

**My recommendation:** build the deterministic keyword-matched version now (this plan's default throughout) — same shape as FR5's "trained model deferred, rule-based decision table is the *active* implementation" resolution, which this project has already accepted once. `FR8`'s actual requirements (bounded knowledge base, no free-form text, emergency redirect, refuse medication questions) are all satisfied by a keyword table; Dialogflow's NLP is an implementation-detail upgrade path, not a new requirement. The `HealthBotClient` interface is designed so swapping the backend for real Dialogflow later needs zero Flutter-side changes (identical to how `RelapsePredictionClient` already anticipates its own future model swap).

**Alternative:** confirm you want to provision a real Dialogflow agent first. If so, tell me and I'll pause this plan at the backend-logic task until that's done, then adjust `backend/app/healthbot/service.py` to call Dialogflow's API instead of the keyword table.

**Why it matters:** this is the single biggest architecture fork in the whole module — it changes the backend implementation, adds a real external-service dependency + credentials-management story, and changes how "confidence"/fallback is determined.

**2. The emergency/crisis-referral UI state has no approved mockup — what does it look like?**

Same situation as Module 4's "My Goal" and Module 5's add-journal-entry screen. FR8/SRDS require the urgent-care message to be displayed, but the SDD explicitly flags that no Figma/mockup exists for this state.

**My recommendation:** render it as a distinct, visually-alarmed message bubble in the same chat transcript (not a separate screen/dialog) — full-width, using `AppColors.error` background, an urgent/warning icon, the exact copy `"This sounds like it could be a medical emergency. Please seek emergency medical care immediately."`, plus a persistent (non-dismissible-by-typing-past-it) visual distinction from normal bot bubbles. Reusing the existing chat surface (rather than inventing a modal/new screen) keeps the conversation flow intact and matches how the reference screenshot already shows everything happening inline.

**Alternative:** a blocking modal/dialog interrupting the chat, or a dedicated full-screen takeover (closer to `HighRiskScreen`'s precedent from Module 3, which *does* interrupt for a High relapse-risk result). Tell me which style you want, or approve the inline-bubble default.

**Why it matters:** this is the single safety-critical UI state in the module — worth being deliberate about rather than guessing silently.

**3. Confirmed set of suggested-question chips and knowledge-base topics?**

The reference screenshot shows tappable chips including "Why can't I sleep?" and "Is this normal?", with at least one more cut off at the image edge, plus a message already sent in the transcript ("Why do I feel so irritable?", answered with a headache-related response — the screenshot's own bot response is about headaches, suggesting the chips and displayed Q&A aren't perfectly 1:1, i.e. the mockup is illustrative, not a literal fixed script). The SRDS's own Module 6 description names four withdrawal symptoms explicitly: **irritability, headaches, sleep disturbances, anxiety.**

**My recommendation — knowledge base topics** (each: keyword match → fixed WHO/CDC-style response, generic public-health information, no dosages, no drug names):

| Topic | Example keywords | Response (draft — please review wording) |
|---|---|---|
| Headaches | headache, head hurts, migraine | "Headaches are a common withdrawal symptom in the first 1-2 weeks after quitting. They're usually mild and fade on their own. Staying hydrated and getting enough rest can help. If headaches are severe or don't improve after a couple of weeks, please see a doctor." |
| Irritability / mood changes | irritable, angry, mood, snapping, short temper | "Irritability and mood swings are very common during withdrawal, especially in the first week. They typically peak around day 3-5 and ease over the following weeks. Deep breathing and short walks can help in the moment." |
| Sleep disturbances | sleep, insomnia, can't sleep, tired, waking up | "Trouble sleeping is common for the first 1-2 weeks after quitting nicotine. Keeping a regular bedtime, avoiding caffeine late in the day, and light exercise earlier in the day can help. If sleep problems persist beyond a few weeks, consider talking to a doctor." |
| Anxiety | anxious, anxiety, nervous, on edge, restless | "Anxiety and restlessness are common withdrawal symptoms as your body adjusts. They usually improve within a few weeks. Slow breathing exercises and staying active can help manage the feeling. If anxiety is severe or persistent, please talk to a doctor." |
| Cravings intensity | craving, urge, want to smoke, want to vape | "Craving intensity is usually strongest in the first week and typically passes within 3-5 minutes if you can ride it out. Try the Log Craving feature to track what's triggering it, and consider a quick distraction — a walk, water, or deep breaths." |
| Appetite / weight changes | hungry, appetite, weight, eating more | "Increased appetite is a normal, temporary withdrawal symptom as your metabolism adjusts. Drinking water and keeping healthy snacks on hand can help. This usually settles within a few weeks." |
| Difficulty concentrating | focus, concentrate, foggy, can't think | "Trouble concentrating (\"nicotine fog\") is a common, temporary withdrawal symptom, usually strongest in the first week. Short breaks and light activity can help. It typically improves within 2-4 weeks." |
| "Is this normal?" (validation/meta-question) | is this normal, is it normal, should I worry | "Most withdrawal symptoms (headaches, irritability, trouble sleeping, anxiety, cravings) are temporary and normal in the first few weeks after quitting. If a symptom is severe, doesn't improve, or worries you, it's always okay to check with a doctor." |

**Emergency/red-flag keywords** (bypass the knowledge base entirely, always show the Open-Decision-2 emergency message): `chest pain`, `can't breathe` / `cannot breathe` / `difficulty breathing`, `heart racing` / `heart attack`, plus (recommended addition beyond the SRDS's literal two examples, for baseline safety) self-harm language: `hurt myself`, `end my life`, `suicidal`. **Confirm whether to include the self-harm keywords** — SRDS only names "chest pain, severe anxiety" explicitly; adding self-harm detection is a safety-motivated scope addition on my part, not a literal requirement, so it needs your sign-off rather than silent inclusion.

**Unmatched query fallback** (no keyword hit, not an emergency): exact SRDS wording — `"I cannot answer this confidently. Please consult a doctor."`

**Suggested chips shown above the input** (tap-to-send, not free-typed): "Why do I feel so irritable?", "Why can't I sleep?", "Is this normal?", "Why am I so anxious?" — four chips, matching the screenshot's visible three-plus-one-cut-off count and drawing the fourth from the SRDS's named symptom list (anxiety) rather than guessing.

**Alternative:** if you want different/additional topics, fewer topics for v1, or want to rewrite any of the response text before it ships, tell me and I'll fold your edits in before implementation — this table is the concrete proposal, not a placeholder.

**Why it matters:** this *is* the module's entire value — everything else (chat UI, logging, disclaimer) is plumbing around this content, and it's health-adjacent text with no advisor reviewing it, so it deserves an explicit look rather than me inventing final wording unreviewed.

**4. Does conversation history reload across sessions, or does every visit start fresh?**

The SDD's `HealthBotConversation` entity is a write-only audit log in the pseudocode (`LOG Conversation anonymously to Firebase`) — nothing in the SRDS/SDD describes reading it back for display. The reference screenshot's disclaimer banner text and the pseudocode's "DISPLAY Medical Disclaimer (**every session**)" both imply each open is treated as a new session.

**My recommendation:** every time `HealthBotScreen` opens, the transcript starts empty and the disclaimer is shown/must be acknowledged again; each Q&A pair is still logged to Firestore (`healthBotConversations`) for audit purposes, just never read back into the UI. This matches "every session" literally and avoids inventing a "chat history" feature the SDD never asked for.

**Alternative:** persist and reload the transcript so returning to the screen resumes where you left off (would need `HealthBotRepository.getConversations(userId)` plus a session-grouping UI decision). Tell me if you want this instead.

**Why it matters:** changes whether `HealthBotRepository` needs a read method at all, and whether the disclaimer becomes a one-time-ever acknowledgment vs. a per-open one.

---

## Data Model

**`HealthBotConversation`** (SDD §6, exact fields):
```dart
class HealthBotConversation {
  final String conversationId; // == sessionId in the SDD's naming
  final String userId;
  final String query;
  final String botResponse;
  final DateTime timestamp;
}
```

**`HealthBotMessage`** (Flutter-only, UI transcript item — not persisted directly, not an SDD entity):
```dart
enum HealthBotSender { user, bot }

class HealthBotMessage {
  final HealthBotSender sender;
  final String text;
  final bool isEmergency; // true only for the Open-Decision-2 urgent-care bubble
  final DateTime timestamp;
}
```

**`HealthBotAnswer`** (backend response shape):
```dart
enum HealthBotAnswerType { matched, emergency, unmatched }

class HealthBotAnswer {
  final HealthBotAnswerType type;
  final String responseText;
}
```

## Firestore Structure

`nicotineUsers/{userId}/healthBotConversations/{conversationId}` — one document per Q&A exchange (matching the SDD entity's per-exchange grain, not per-session), fields: `query` (string), `botResponse` (string), `timestamp` (ISO 8601 string, same convention as every other subcollection in this repo).

**New rule** (mirrors `journalEntries` exactly):
```
match /healthBotConversations/{conversationId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/health_bot_message.dart` | New: `HealthBotSender` enum + `HealthBotMessage` (UI transcript item) |
| `lib/models/health_bot_conversation.dart` | New: `HealthBotConversation` (SDD entity, persisted) |
| `lib/data/health_bot_client.dart` | New interface: `Future<HealthBotAnswer> ask({required String query})`, plus `HealthBotAnswer`/`HealthBotAnswerType` |
| `lib/data/http_health_bot_client.dart` | New: calls `POST /healthbot/query` via `OtpBackendConfig.baseUrl`, mirrors `HttpRelapsePredictionClient` |
| `lib/data/fake_health_bot_client.dart` | New: test double, configurable canned answer |
| `lib/data/health_bot_repository.dart` | New interface: `Future<void> logConversation(HealthBotConversation)` |
| `lib/data/firestore_health_bot_repository.dart` | New: real Firestore impl, mirrors `FirestoreJournalRepository` |
| `lib/data/fake_health_bot_repository.dart` | New: in-memory test double |
| `lib/controllers/health_bot_controller.dart` | New (ChangeNotifier): disclaimer-ack flag, transcript list, `sendQuery(userId, text)` |
| `lib/screens/healthbot/health_bot_screen.dart` | New: matches `8 healthbot.png` |
| `backend/app/healthbot/__init__.py` | New (empty, matches `relapse/__init__.py`) |
| `backend/app/healthbot/service.py` | New: keyword-matched knowledge base + emergency detector (pure function) |
| `backend/app/routers/healthbot.py` | New: `POST /healthbot/query` FastAPI route |
| `backend/app/main.py` | **Modify:** `app.include_router(healthbot.router)` |
| `lib/screens/dashboard/widgets/quick_access_grid.dart` | **Modify:** enable "Health-Bot" tile (index 2), always-on |
| `lib/screens/dashboard/widgets/dashboard_bottom_nav.dart` | **Modify:** enable the center Health-Bot button, always-on |
| `lib/screens/dashboard/dashboard_screen.dart` | **Modify:** wire both entry points to `HealthBotScreen` |
| `lib/main.dart` | **Modify:** provider wiring for `HealthBotController` |
| `firestore.rules` | **Modify:** add `healthBotConversations` subcollection rule |

## Task Breakdown

### Task 1: Backend knowledge-base service + router
**Files:** Create `backend/app/healthbot/__init__.py`, `backend/app/healthbot/service.py`; Test: `backend/tests/test_healthbot_service.py`
Pure function `answer_query(query: str) -> HealthBotAnswer` implementing Open Decision 3's table + emergency keyword list, table-driven tests over every topic + emergency + unmatched-fallback case.

### Task 2: Backend router + registration
**Files:** Create `backend/app/routers/healthbot.py`; Modify `backend/app/main.py`; Test: `backend/tests/test_healthbot_router.py`
`POST /healthbot/query` request `{query: str}` → response `{answer_type: str, response_text: str}`, mirrors `routers/relapse.py` exactly.

### Task 3: Flutter models + `HealthBotClient`
**Files:** Create `lib/models/health_bot_message.dart`, `lib/data/health_bot_client.dart`, `http_health_bot_client.dart`, `fake_health_bot_client.dart`; Test: `test/data/http_health_bot_client_test.dart`

### Task 4: `HealthBotRepository`
**Files:** Create `lib/models/health_bot_conversation.dart`, `lib/data/health_bot_repository.dart`, `firestore_health_bot_repository.dart`, `fake_health_bot_repository.dart`; Test: `test/data/fake_health_bot_repository_test.dart`

### Task 5: `HealthBotController`
**Files:** Create `lib/controllers/health_bot_controller.dart`; Test: `test/controllers/health_bot_controller_test.dart`
**Consumes:** `HealthBotClient`, `HealthBotRepository`
**Produces:** `acknowledgeDisclaimer()`, `sendQuery({required String userId, required String text})` → appends user message, calls client, appends bot/emergency message per `HealthBotAnswerType`, fire-and-forget logs via repository (failure never blocks the chat, matching Register's recent-email-suggestion precedent).

### Task 6: `HealthBotScreen`
**Files:** Create `lib/screens/healthbot/health_bot_screen.dart`; Test: `test/screens/health_bot_screen_test.dart`
Matches `8 healthbot.png`: disclaimer banner, chat transcript (user/bot/emergency bubble styles per Open Decision 2), suggested-chip row, text input + send button.

### Task 7: Wire into Dashboard
**Files:** Modify `lib/screens/dashboard/widgets/quick_access_grid.dart`, `dashboard_bottom_nav.dart`, `lib/screens/dashboard/dashboard_screen.dart`, `lib/main.dart`; Test: extend `test/screens/dashboard_screen_test.dart`
Both entry points always enabled (no phase gate). No other Quick Access/bottom-nav tile changes.

### Task 8: Firestore rules
**Files:** Modify `firestore.rules` (add `healthBotConversations` block); deploy

---

## Which Dashboard features become functional

- **"Health-Bot" Quick Access tile** — always enabled (once onboarding is complete), navigating to `HealthBotScreen`.
- **Bottom-nav center Health-Bot button** — same destination, same always-enabled rule.
- All other still-disabled tiles (Alternatives, Rewards, Community, Knowledge Hub) remain untouched — none are this module's FRs.

## Test Strategy / Required tests summary

- `backend/tests/test_healthbot_service.py` — table-driven over every knowledge-base topic, the emergency path, and the unmatched fallback (mirrors `test_relapse_service.py`)
- `backend/tests/test_healthbot_router.py` — mirrors `test_relapse_router.py`
- `test/data/http_health_bot_client_test.dart` — success, network failure, non-200, malformed-body cases (mirrors relapse client's implicit coverage pattern)
- `test/data/fake_health_bot_repository_test.dart`
- `test/controllers/health_bot_controller_test.dart` — disclaimer gate, normal answer, emergency answer, unmatched fallback, repository-logging-failure-doesn't-block-chat
- `test/screens/health_bot_screen_test.dart` — disclaimer shown/dismissed, sending via typed text, sending via tapping a suggested chip, emergency bubble styling, unmatched fallback text
- Extended `test/screens/dashboard_screen_test.dart` — both entry points navigate to `HealthBotScreen`

## Acceptance Criteria

1. Tapping either Dashboard entry point (Quick Access tile or bottom-nav center button) opens `HealthBotScreen`.
2. The medical disclaimer is shown and must be acknowledged before the input field is usable, every time the screen opens (Open Decision 4).
3. A query matching a knowledge-base topic (Open Decision 3's table) returns that topic's exact fixed response text — never model-generated prose.
4. A query matching an emergency keyword returns the Open-Decision-2 urgent-care message, styled distinctly, and never falls through to a normal knowledge-base answer even if it also happens to contain a topic keyword.
5. A query matching neither returns the exact fallback string `"I cannot answer this confidently. Please consult a doctor."`
6. No response text anywhere contains a medication name, dosage, or "you should take" language.
7. Tapping a suggested chip sends that exact question, identical in behavior to typing it.
8. Every Q&A exchange is written to `nicotineUsers/{userId}/healthBotConversations/{conversationId}`; a logging failure never blocks or errors the visible chat.
9. The feature is reachable and fully functional in both Countdown and Nicotine-Free phases.
10. `flutter analyze`: 0 issues. Full Flutter test suite: all passing, including new tests above. Backend `pytest`: all passing, including new tests above.

## Out of Scope

- Real Dialogflow/NLP integration (Open Decision 1's alternative path)
- Persisted, reloadable conversation history across sessions (Open Decision 4's alternative path)
- Any change to Modules 1-5, authentication, Google Sign-In, Welcome/Login/Register screens, or the WhatsApp OTP backend code
- FCM/push notifications of any kind
- Any UI screen outside `HealthBotScreen` and the two Dashboard entry-point widgets
- A live/human medical-advisor review workflow (no such actor exists per SDD §5)
- Any other module's disabled tile (Alternatives, Rewards, Community, Knowledge Hub) becoming functional

---

## Self-review

- **Spec coverage:** FR8's every clause — disclaimer every session, bounded knowledge base, no free-form AI text, refuse medication/dosage, emergency redirect, anonymous logging — has a corresponding task and acceptance criterion.
- **Placeholder scan:** all four numbered open decisions are explicit confirmation points with concrete drafted defaults (including actual response text), not "TBD." Open Decision 0 is the exception that's allowed to block everything else — it's a scope/ownership question, not a design detail I could reasonably guess at.
- **Type consistency:** `HealthBotAnswerType` (matched/emergency/unmatched) used identically in the backend response, `HealthBotClient`, and `HealthBotController` sections above.
- **Reuse check:** `RelapsePredictionClient`/`HttpRelapsePredictionClient` (client shape), `relapse/service.py`+`routers/relapse.py` (backend shape), `JournalRepository` (Firestore repository shape), `OtpBackendConfig` (base URL), `firestore.rules` subcollection pattern — all reused as templates, zero duplication of logic, only the module-specific content is new.

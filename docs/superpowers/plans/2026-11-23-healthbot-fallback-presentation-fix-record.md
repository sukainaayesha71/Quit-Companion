# Health-Bot fallback presentation fix: record (2026-11-23)

Found during physical-phone testing (vivo V2022). Owner-approved before implementation. No Firebase rules, credentials, configuration, timeout or unrelated modules changed.

## Problem and root cause

- **Symptom:** a useful answer with sources, but the first line read "The AI assistant took too long to reply. General guidance: …".
- **Evidence:** the backend log showed `Health-Bot Gemini exceeded the 1.5s budget` before each of the owner's two `/healthbot/query` 200 responses. So Gemini really did time out (1.5 s total budget, FR8 2 s target), and the backend answered from its curated knowledge base.
- **Root cause:** the fallback label was concatenated into `response_text` (`backend/app/healthbot/service.py`: `_SLOW_LABEL` / `_UNAVAILABLE_LABEL`), and the app rendered it verbatim. The app's own offline fallback did the same ("Health-Bot can't reach the server right now…" / "<reason> Meanwhile, here is general guidance: …").
- **Related gap:** no field said where the answer came from. Removing the label alone would have let curated text look AI-generated under the screen's "AI" chip.

## Fix

**Backend** (`app/healthbot/service.py`, `app/healthbot/router.py`)
- New `AnswerSource` (`ai`, `curated`, `safety`) and `FallbackReason` (`timeout`, `unavailable`). `HealthBotAnswer` carries both; the conservative default is `curated`, never `ai`.
- Fallbacks return clean curated text with `fallback_reason` set.
- Gemini replies are `ai`. Emergency referrals and both medication guards are `safety`, with unchanged text.
- `/healthbot/query` adds `answer_source` and `fallback_reason`; existing fields are unchanged.
- The 1.5 s budget is unchanged.

**App** (`mobile/lib/features/health_bot/…`)
- The client parses the new fields (missing → `unknown`). Connection failures now throw `HealthBotUnreachableException`.
- The local fallback returns clean general guidance, marked `offline` (emergency → `safety`, unchanged text).
- Controller labelling:
  - **AI:** no note.
  - **Curated:** "General guidance from Quit Companion's library — not AI-generated."
  - **Offline (timeout or unreachable):** "Offline guidance — Health-Bot couldn't be reached."
  - **Other client errors** (e.g. sign-in): the actionable reason as the note.
  - **Curated fallback with no matching answer:** "Sorry, I couldn't get an answer to that just now." plus a **Try again** button that resends the question.
  - **Emergency:** unchanged (no note, crisis button kept).
- The note is saved as an optional `note` field in the existing history document and restored on reload. Existing history is unchanged, and older records load without a note. Firestore rules already allow this; not modified.
- Screen: answer text first, then the italic note, then Try again (when applicable), then the existing source links.

## Tests (verified 2026-11-23)

| Check | Result |
| --- | --- |
| Backend pytest (full) | **322 passed, 0 failed, 0 skipped** (310 before). New `tests/test_healthbot_answer_source.py` (12 tests); 6 existing assertions updated from the old prefixes and exact-equality expectations. |
| Flutter suite (121 files) | **839 passed, 0 failed, 0 skipped**, exit code 0 (823 before). New `test/features/health_bot/answer_source_test.dart` (16 tests); 4 existing tests updated to the clean-text-plus-note behaviour. |
| `flutter analyze` | No issues |
| Debug APK | Rebuilt 2026-11-23 22:49:28 (`--dart-define=OTP_BACKEND_BASE_URL=http://127.0.0.1:8000`); installed on the phone with `adb install -r` (update; app data kept) |
| Backend | Restarted as a single instance; `/openapi.json` shows `answer_source` and `fallback_reason` |

## Remaining

- **Phone recheck pending:** see the physical-device test record.
- **Gemini response time:** with the unchanged 1.5 s budget, most replies on this connection are expected to be curated, now labelled honestly. Raising the budget is an owner decision and wasn't done.
- **Two older history entries** saved before the fix keep their original prefixed text.

## Follow-up (owner decision, 2026-11-23): no visible note on curated answers + Welcome branding

**Health-Bot**
- On review, the owner asked to remove the italic note "General guidance from Quit Companion's library — not AI-generated."
- Curated answers now show only the clean answer text first, then the source links.
- The origin is still recorded, never as AI:
  - every bot message carries `answerSource` (`ai` / `curated` / `safety` / `offline` / `unknown`);
  - new history documents store an `answerSource` field and restore it on reload (older records load without it);
  - the backend still returns `answer_source` and `fallback_reason`.
- Unchanged:
  - the offline note "Offline guidance — Health-Bot couldn't be reached.";
  - sign-in/actionable notes;
  - the "Sorry, I couldn't get an answer to that just now." + Try again path;
  - emergency replies and the crisis button;
  - medication refusals;
  - AI answers;
  - the 1.5 s budget.
- Changed files: `controllers/health_bot_controller.dart`, `models/health_bot_message.dart`, `models/health_bot_conversation.dart`, `data/firestore_health_bot_repository.dart`, and test `answer_source_test.dart`.

**Welcome screen** (`mobile/lib/features/auth/presentation/screens/welcome_screen.dart`)
- The title "Quit Companion" and the tagline "Nicotine Recovery Through Habit Tracking, Personalized Guidance & Improved Overall Health" now form one centred branding block: the tagline sits directly under the title. It replaces the previous, separately positioned tagline "Your journey to a nicotine-free life starts here."
- The block sits in the band between the original title line and the Register button, and scales down rather than overlapping the buttons on short screens or with large system text.
- Unchanged: the background image, theme, colours, and the Register and Log In buttons.
- New test `test/features/auth/presentation/welcome_screen_test.dart` (11 tests):
  - exact texts, with the old tagline gone;
  - across 320×640, 360×800 and 412×915 at text scale 1.0, 1.5 and 2.0: tagline directly under the title, same centre line, above the Register button, inside the screen, Log In button on screen, no layout exceptions;
  - both buttons still respond.

**Verified results**

| Check | Result |
| --- | --- |
| `flutter analyze` (full) | No issues |
| Flutter suite (122 files) | **850 passed, 0 failed, 0 skipped**, exit code 0 |
| Backend pytest (full) | **322 passed, 0 failed, 0 skipped** |
| Debug APK | Built 2026-11-23 23:15:18. Contains the new tagline and the offline/Try again texts; contains neither "not AI-generated" nor the old tagline. |
| Install on phone | **Pending:** the phone dropped to "unauthorized" over USB before installation |

## Welcome screen matched to the design document (2026-11-23, later)

- **Source of truth:** `docs/UI_Design/welcome screen 1.png`. The background, logo and illustration were already the design image itself (`mobile/assets/images/welcome_hero_full.png` = the design with the text and buttons erased), so they're unchanged.
- **Owner decision:** use the design's tagline. This **reverses** the earlier "Nicotine Recovery Through Habit Tracking…" tagline.
- Changes in `welcome_screen.dart`:
  - tagline "Your journey to a nicotine-free / life starts here." (design line break), now **dark** (`textPrimary`, regular weight) instead of grey;
  - **Log In:** white fill (`AppColors.surface`), sage outline and text, soft shadow;
  - **Register:** terracotta pill with white bold text and a soft shadow.
- Unchanged: the title (w800, dark, centred), the design-measured positions and button sizes, the branding block that can't overlap the buttons, and Register/Log In navigation.
- **Tests:** `welcome_screen_test.dart` (12 tests) checks the design tagline (and that the previous tagline is gone), the dark tagline, the white Log In fill with elevation, the Register elevation, and the 9 size/text-scale layout cases.
- **Results:**
  - full `flutter analyze`: no issues;
  - `test/features/auth` + `test/app_flow_test.dart` + `test/responsive_screens_test.dart`: **156 passed, 0 failed**.
- **Installed:** debug APK rebuilt 2026-11-23 23:28:18 (contains the design tagline, no previous tagline, no "not AI-generated" text). Installed on the vivo V2022 with `adb install -r` ("Success", 23:28:46; data kept). Visual comparison against the design on the phone is still pending.

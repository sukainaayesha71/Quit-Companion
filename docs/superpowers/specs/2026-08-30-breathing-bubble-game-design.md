# Breathing Bubble Mini-Game — Design

**Status: DESIGN, approved by user in brainstorming session (2026-08-30). Not yet implemented.**

## Why this exists

The user asked for 3-4 fully polished mini-games added to the Alternatives section, to be built one at a time, starting with Breathing Bubble as the most directly relevant to craving management. This spec covers Breathing Bubble only; the other three (Tap & Pop, Memory Match, Craving Countdown Challenge) each get their own brainstorm/spec/plan cycle afterward.

## Scope

A guided 4-7-8 breathing exercise, visualized as a smoothly expanding/contracting circle with a live phase label and cycle counter, replacing the existing static "4-7-8 Breathing" text-instruction alternative (`habit_alternative_library.dart`'s `'breathing'` entry, currently `AlternativeCategory.exercise`). Same visual/interaction philosophy as the two already-built games (Bubble Pop, Word Search): calm, no score, no failure state — but this one has a defined, celebrated completion point, since a breathing exercise naturally has a "you did the thing" endpoint that a purely open-ended distraction doesn't.

## Architecture change: decoupling "playable" from category

Currently `AlternativeDetailScreen` shows a Play button only when `alternative.category == AlternativeCategory.game`. Breathing Bubble replaces an `AlternativeCategory.exercise` entry, so that check no longer works for this case — and future games (Craving Countdown Challenge in particular) may not be `game`-category either. Replacing the category check with a small `Map<String, WidgetBuilder>`-style lookup keyed by `alternativeId` (already how routing works internally via the `switch` in `_openGame`) — the Play button now shows whenever the current alternative's id has a registered game screen, regardless of category. This is a pure refactor of existing code, not a behavior change for the two already-built games.

## The breathing animation

One `AnimationController` drives a full 19-second cycle (4-7-8, matching the existing alternative's name and its current instructions text, which already specifies this exact timing):
- 0-4s: inhale — circle scales from its minimum to maximum size
- 4-11s: hold — circle stays at maximum size with a very subtle pulse (small scale oscillation, not a size change)
- 11-19s: exhale — circle scales back down to minimum

Eased with `Curves.easeInOut` for the inhale/exhale scale segments (not linear) so the motion feels organic rather than mechanical. Circle fill color interpolates between `AppColors.sageLight` (at minimum size) and `AppColors.sage` (at maximum size), driven directly off the same scale value — no separate color animation to keep in sync. A phase label below the circle ("Breathe In" / "Hold" / "Breathe Out") updates live off the controller's current phase.

**Cute factor** (per user follow-up): the bubble gets a simple, friendly face — two small dot eyes and a soft curved smile, drawn as plain shapes (not an image asset, not referencing any existing character/franchise — an original, minimal "breathing buddy" look, in the same vein as the simple blob-characters common in meditation apps). The eyes blink slowly and infrequently (a quick double-scale-down-and-back on the eye shapes every ~6-10 seconds, randomized) purely for warmth — it doesn't track breathing phase, so it never competes with the phase label for attention. Kept small and understated relative to the bubble so it reads as "friendly," not "cartoonish clutter" — the app's existing calm/professional tone still governs the overall screen (same cream background, same typography as every other screen).

## Session structure

Exactly 6 cycles (~2 minutes total: 6 × 19s = 114s), with a small "Cycle N of 6" counter visible throughout. On completing the 6th cycle's exhale, the screen shows a short celebratory message ("Nice work — 6 calming breaths 🌿") and a "Done" button. A close button (top-left corner, `Icons.close`, matching the existing style used in Bubble Pop and Word Search) is available at all times and pops the screen immediately if tapped before the 6th cycle completes — leaving early shows no celebration and is not treated as a failure state, consistent with every other game's "leave whenever" philosophy; the celebration is additive for finishing, not a gate.

## Wiring

- `habit_alternative_library.dart`: the existing `'breathing'` entry (currently `category: AlternativeCategory.exercise`, `instructions: 'Breathe in for 4 seconds, hold for 7, exhale for 8.'`) keeps its category as `AlternativeCategory.exercise` (no reason to reclassify it as a "Game" filter item — the architecture change above means category no longer determines Play-button visibility). Its `instructions` text is updated to describe the interactive version.
- `alternative_detail_screen.dart`: `_openGame`'s existing `switch` statement gets a new case for `'breathing'` → `BreathingBubbleGameScreen()`; the Play-button visibility condition changes from `alternative.category == AlternativeCategory.game` to a check against the same set of ids the switch handles.

## Testing plan

- `mobile/test/screens/breathing_bubble_game_screen_test.dart`: the phase label reads "Breathe In" at the start; cycle counter shows "Cycle 1 of 6" initially; after pumping through a full cycle's duration the counter advances to "Cycle 2 of 6"; the close button pops the screen at any point; pumping through all 6 full cycles shows the completion message and Done button, which also pops the screen.
- `mobile/test/screens/alternative_detail_screen_test.dart` (extended): the Play button now appears for the `'breathing'` alternative (an `exercise`-category one) and routes to `BreathingBubbleGameScreen`; the existing exercise-category test fixture (`_alternative`, id `'breathing'` is NOT reused there — it's a different fixture id, `'breathing'` the real library entry vs the test's own unrelated `_alternative` fixture, so no collision) continues to assert no Play button for a *non-playable* exercise alternative.

No existing test is deleted or weakened. The refactor from category-based to id-based Play visibility must keep the two already-passing tests for Bubble Pop/Word Puzzle's Play button green unchanged.

## Explicitly out of scope

- No user-adjustable breathing pattern/timing (fixed 4-7-8, matching the entry's existing name).
- No sound/audio cues.
- No persistence of session completion (no Firestore write) — same ephemeral, session-only posture as the other two games.

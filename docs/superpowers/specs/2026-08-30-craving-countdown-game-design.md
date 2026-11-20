# Craving Countdown Challenge — Design

**Status: DESIGN, approved by user (fast-track, 2026-08-30). Not yet implemented.**

## Why this exists

Fourth and last of four new Alternatives mini-games requested by the user. The brief: "a gamified timer where the user commits to 'beating' a craving for a set duration (e.g., 3 minutes), with an engaging progress animation, encouraging messages that appear at intervals, and a reward/celebration when completed."

## Scope

New additive library entry, `alternativeId: 'craving_countdown'`, title "Craving Countdown Challenge". Unlike the other three games (which involve active tapping/matching), this one is deliberately ambient and passive — the point is simply staying present through a craving for a fixed duration, not "playing" in the usual sense.

## Mechanics

- Fixed 3-minute (180-second) countdown, driven by a single `AnimationController` (same pattern as Breathing Bubble — a continuous, smoothly-progressing value, not a discrete `Timer.periodic` tick like Tap & Pop, since there's no discrete event here, just continuous progress).
- A circular ring visualization: starts empty, fills to full (sage color) as the 180 seconds elapse — deliberately "filling up / building strength" rather than "draining away," to reinforce a positive framing rather than a ticking-clock-running-out feeling.
- Remaining time shown as mm:ss text in the center of the ring.
- Six original, short encouraging messages rotate beneath the ring, one per 30-second segment (180s / 6 = 30s each): plain, generic supportive phrasing in the same voice as the rest of the app's copy (e.g. HealthBot's tone) — not quoting any external source.
- No difficulty, no failure state for letting time "run out" — reaching 180 seconds is the success condition, not a loss condition.

## Session end

At 180 seconds: "You beat the craving! 💪" with **Play Again** (restart the 3-minute countdown, same screen) and **Done** (pop back to the Alternative detail screen) — same end-screen pattern as Breathing Bubble, Tap & Pop, and Memory Match. Close button available throughout; leaving early is never framed as a failure, consistent with every other game here — the whole point of offering an escape hatch is that forcing someone to stay against their will would be counterproductive for a craving-support tool.

## Wiring

Same pattern as the three prior additions: new entry in `habit_alternative_library.dart` (category: `AlternativeCategory.quickFix`, since this is a coping commitment rather than a game in the play sense — but still added to `alternative_detail_screen.dart`'s `_gameScreenIds` set regardless of category, following the precedent Breathing Bubble already established for category-independent Play-button visibility), `_openGame` switch case, and a `high_risk_screen.dart` `_uiMeta` entry (required — confirmed necessary twice now by the Tap & Pop and Memory Match additions).

## Testing plan

- `mobile/test/screens/craving_countdown_game_screen_test.dart`: starts at 3:00 with the first encouraging message; after 30 seconds shows the second message; after the full 180 seconds shows the completion message and Done button; Play Again resets the timer to 3:00 and restarts; the close button pops the screen at any point. Given the Breathing Bubble task's discovery that a single large `pump()` can't reliably drive multi-step `AnimationController` completions, this uses the same `pumpUntil`-based incremental-pump approach proven there rather than one large fixed-duration `pump()` call.
- `mobile/test/screens/alternative_detail_screen_test.dart` (extended): Play button appears for `craving_countdown` and routes to the new screen.
- `mobile/test/screens/high_risk_screen_test.dart`, `mobile/test/controllers/alternatives_controller_test.dart`, `mobile/test/domain/habit_alternative_matcher_test.dart` (extended): the same library-size counts bumped for each of the three prior game additions get bumped once more (7→8 total; the game-category-filter count in `alternatives_controller_test.dart` does NOT change, since this entry's category is `quickFix`, not `game`).

No existing test is deleted or weakened.

## Explicitly out of scope

- No adjustable duration (fixed 3 minutes, per the brief's example).
- No sound.
- No persisted streak/history of completed countdowns across sessions.

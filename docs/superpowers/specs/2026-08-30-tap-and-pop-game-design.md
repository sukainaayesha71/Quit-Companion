# Tap & Pop Distraction Game — Design

**Status: DESIGN, approved by user in brainstorming session (2026-08-30). Not yet implemented.**

## Why this exists

Second of four new Alternatives mini-games requested by the user (after Breathing Bubble). The user's brief specifically asked for "a simple, satisfying reflex game where bubbles/dots appear on screen and the user taps them quickly before they disappear, with a short timer and score counter... snappy and fun." This is meaningfully different from the already-built calm Bubble Pop (no timer, no score, self-paced) — different enough that it's a **distinct third game**, not a replacement or redesign of Bubble Pop.

## Scope

A new library entry, `alternativeId: 'tap_pop'`, `category: AlternativeCategory.game`, title "Tap & Pop". A 30-second timed reflex round: dots appear one at a time at random positions, each visible briefly before fading if unpopped; tapping pops it and scores a point. Ends with a score summary and the option to play again immediately or leave.

## Game mechanics

- One dot on screen at a time (not a swarm — keeps it readable and fair as a *reflex* test rather than a chaotic tap-everything game).
- Each dot: random position within the safe play area, random color alternating between `AppColors.sage` and `AppColors.terracotta`, visible for 1200ms before fading out unpopped if not tapped in time.
- Tapping a visible dot: pops it (quick scale-up-then-fade, ~150ms, matching the existing Bubble Pop's pop feel for visual consistency across the app's games), increments the score, and immediately spawns the next dot at a new random position.
- Missing a dot (it fades out untapped): no penalty, no score change — the next dot spawns immediately regardless.
- A 30-second countdown timer is visible the whole round (`AppColors.textSecondary`, small, non-alarming — this is meant to feel snappy, not stressful).
- Live score counter, prominent, updates on every successful pop.

## Session end

When the countdown reaches 0: the current dot (if any) disappears, and a summary appears — "You popped **N** bubbles! 🎉" — with two actions:
- **Play Again**: resets score to 0, restarts the 30-second timer, spawns a fresh dot immediately. No screen navigation — same screen, fresh round.
- **Done**: pops the screen back to the Alternative detail screen.

The close button (top-left, same style/position as every other game) is available throughout the round, not just at the end — closing mid-round simply ends it with no summary shown, consistent with the "leaving early is never a failure" philosophy already established for Bubble Pop, Word Search, and Breathing Bubble.

## Wiring

New entry added to `habit_alternative_library.dart` (not a replacement — additive, alongside the existing `bubble_pop` and `word_puzzle` entries already there). Added to `alternative_detail_screen.dart`'s `_gameScreenIds` set and `_openGame` switch, same pattern as the three existing games.

## Testing plan

- `mobile/test/screens/tap_and_pop_game_screen_test.dart`: a dot is visible shortly after opening; tapping it increments the score to 1 and a new dot appears; after the 30-second timer expires, the summary message with the correct final score appears; tapping Play Again resets the score to 0 and a new round starts (verified by popping a dot afterward and seeing the score reach 1 again, not 2); the close button pops the screen at any point during a round.
- `mobile/test/screens/alternative_detail_screen_test.dart` (extended): the Play button appears for the new `tap_pop` alternative and routes to the new screen.

No existing test is deleted or weakened.

## Explicitly out of scope

- No difficulty progression (dot lifetime/spawn rate stays constant for the full 30 seconds — this is a short craving-distraction, not a game meant to be "beaten" or mastered).
- No persisted high score across sessions (ephemeral, session-only, same posture as every other game here).
- No multiple simultaneous dots (deliberately one-at-a-time, per the "readable, fair reflex test" reasoning above).

# Memory Match Mini-Game — Design

**Status: DESIGN, approved by user (fast-track, 2026-08-30). Not yet implemented.**

## Why this exists

Third of four new Alternatives mini-games requested by the user. The brief: "a card-flip memory matching game themed around health facts or quit-smoking milestones... match icons representing lungs, heart, money saved, fresh air. Include a move counter and completion celebration."

## Scope

New additive library entry, `alternativeId: 'memory_match'`, `category: AlternativeCategory.game`, title "Memory Match" — alongside the three existing games (Bubble Pop, Word Search, Tap & Pop, Breathing Bubble), not a replacement of any of them.

## Game mechanics

- 4×4 grid, 16 cards, 8 matching pairs.
- Pairs represent quitting/health concepts, each a plain Material icon (no image assets, no copyrighted imagery): lungs (`Icons.air_rounded`), heart (`Icons.favorite_rounded`), money saved (`Icons.savings_rounded`), fresh air (`Icons.eco_rounded`), brain/science (`Icons.psychology_rounded`), streak/calendar (`Icons.calendar_today_rounded`), milestone (`Icons.emoji_events_rounded`), hydration (`Icons.water_drop_rounded`).
- Card back: a uniform sage-colored rounded tile (no per-card distinguishing mark face-down — that would defeat the point of a memory game).
- Tapping a face-down card flips it to reveal its icon. Tapping a second face-down card:
  - **Match**: both stay face-up, get a small confirming visual (e.g. brief scale pulse), and the move counter increments.
  - **Mismatch**: both stay revealed briefly (~800ms) so the player can register what they saw, then flip back face-down. Move counter also increments (a "move" is any pair-attempt, matching the standard memory-game convention, not just successful ones).
- While two cards are face-up awaiting the match/mismatch resolution, a third card cannot be flipped (prevents player input from racing the resolution animation).
- No timer for this game — the brief only specifies a move counter for Memory Match, unlike Tap & Pop's explicit timer request.

## Session end

When all 8 pairs are found: "You did it in **N** moves! 🎉" with **Play Again** (fresh shuffled grid, same screen, move counter reset to 0) and **Done** (pops back to the Alternative detail screen) — same end-screen pattern already established by Tap & Pop and Breathing Bubble. Close button available throughout, no penalty for leaving mid-game.

## Wiring

Same pattern as the three prior games: new entry in `habit_alternative_library.dart`, added to `alternative_detail_screen.dart`'s `_gameScreenIds` set and `_openGame` switch, and — since Tap & Pop's addition already proved this is a real crash risk — a new entry must also be added to `high_risk_screen.dart`'s per-id `_uiMeta` map (its null-asserted lookup has no default case; every new library entry needs a matching row there or the screen crashes on render).

## Testing plan

- `mobile/test/screens/memory_match_game_screen_test.dart`: all 16 cards start face-down; tapping a card reveals its icon; tapping a second non-matching card shows both then flips both back after the reveal delay; tapping a second matching card keeps both face-up and increments the move counter; a third tap is ignored while two cards are already face-up and unresolved; completing all 8 pairs shows the completion message with the correct move count; Play Again resets the board and move counter; the close button pops the screen at any point.
- `mobile/test/screens/alternative_detail_screen_test.dart` (extended): Play button appears for `memory_match` and routes to the new screen.
- `mobile/test/screens/high_risk_screen_test.dart` (extended): the card count assertion updates from six to seven alternatives, and the new card's key/title are asserted present, mirroring exactly how the Tap & Pop addition updated this same test.
- `mobile/test/controllers/alternatives_controller_test.dart` and `mobile/test/domain/habit_alternative_matcher_test.dart` (extended): hardcoded library-size counts updated from 6 to 7, same as the fix already applied for Tap & Pop.

No existing test is deleted or weakened.

## Explicitly out of scope

- No timer/countdown (per the brief, only Tap & Pop gets one).
- No difficulty levels or larger grid options.
- No persisted best-move-count across sessions.

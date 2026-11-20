# Mini-Games for Alternatives (Module 7) — Design

**Status: DESIGN, approved by user in brainstorming session (2026-08-29). Not yet implemented.**

## Why this exists

`habit_alternative_library.dart` has always contained two "game" category items — "Bubble Pop Mini-Game" and "Quick Word Puzzle" — whose `instructions` text tells the user to "open" a mini-game. No such mini-game was ever built anywhere in the codebase; tapping "Try This" on either card just opens the same generic instructions/Yes-No detail screen every other alternative uses. This was inherited placeholder copy from a pre-Module-7 draft screen, never followed up (confirmed via full-codebase search — see the investigation this design followed from). The user has now asked for these to be real, playable mini-games.

## Scope

Two original, simple, self-contained mini-games, reached from the existing "Try This" flow. Both are calm, unhurried distractions (no timer, no score, no win/lose pressure) — deliberately, since the point is to ride out a craving, not add stimulation. This is a purely additive feature: nothing about the existing Alternatives ranking, filtering, attempt-logging, or Firestore wiring changes.

## Architecture

New folder `mobile/lib/screens/games/`, kept separate from `screens/craving/` since these are a distinct, self-contained feature area:
- `bubble_pop_game_screen.dart`
- `word_search_game_screen.dart`

New pure domain file `mobile/lib/domain/word_search_generator.dart` — grid-generation logic, following the same "pure, testable, no I/O" pattern already established by `WeeklyPlanCalculator`, `RestartPlanCalculator`, etc.

**No new controller, no Firestore, no persisted state.** These are ephemeral, session-only distractions — there is nothing to save. The existing "Did this help?" outcome logging on `AlternativeDetailScreen` (via `AlternativesController.recordOutcome`) is untouched and still the only persistence involved in this flow. Each game screen owns its own local widget state (`StatefulWidget` + `setState`), which is the right scope here — adding a `ChangeNotifierProvider`/repository pair for state that never leaves the widget tree and is never read by anything else would be pure ceremony.

## Bubble Pop

A `StatefulWidget` (`BubblePopGameScreen`) holding an in-memory list of active bubbles. Each bubble is a small model (position, drift speed, pastel color, unique id) driven by its own `AnimationController` animating a slow upward float. New bubbles spawn on a randomized interval (a few seconds apart, not a rush) as long as the screen is open, up to a small concurrent cap (e.g. 8) so the screen never feels cluttered.

Tapping a bubble:
- Removes it from the active list (with a brief scale+fade "pop" animation, not an instant disappearance)
- Triggers `HapticFeedback.lightImpact()`

No timer, no score, no end condition. A "Done" button (top-left, matching the back-button style used elsewhere, e.g. `AlternativeDetailScreen`'s back button) pops the screen at any time — leaving is never "quitting early" since there's nothing to finish.

## Word Search

10x10 letter grid. Word bank (8 words, chosen for a calm/recovery theme, all original short English words — no external word list or copyrighted puzzle source): `CALM`, `HOPE`, `FOCUS`, `PEACE`, `STRONG`, `HEALING`, `BREATHE`, `PROGRESS`.

`WordSearchGenerator.generate(words, size)` (pure function, in `mobile/lib/domain/word_search_generator.dart`):
1. For each word, pick a random forward direction — horizontal (left-to-right), vertical (top-to-bottom), or diagonal (top-left-to-bottom-right) — and a random valid starting position such that the word fits in-bounds.
2. Retry a bounded number of times per word if the chosen placement would overwrite a different letter already placed by an earlier word at an intersecting cell (letters agreeing at an intersection are fine and expected).
3. Fill every remaining empty cell with a random uppercase letter.
4. Return a `WordSearchPuzzle` value object: the finished `List<List<String>>` grid, and a `Map<String, List<Point>>` (or equivalent) recording each word's exact placed cell path, which the screen needs to validate a user's drag selection.

Only forward directions (no reversed words) — deliberately, to keep this a gentle puzzle rather than a tricky one, matching the calm-distraction goal.

`WordSearchGameScreen`: renders the grid (a `GridView`/custom layout of letter tiles) and a word-bank list above it (the 8 target words, each struck through once found). The user drags a finger across a straight line of letters; on release, the selected cell path is compared against each remaining word's recorded path (matching in either direction along that line, so the user isn't forced to drag in one specific order) — a match highlights those cells permanently and crosses the word off the bank. When all 8 words are found, a small celebratory "All done" message appears with a "Done" button. A manual "Done"/back option is available at any time regardless of progress — same "no pressure to finish" philosophy as Bubble Pop.

## Wiring into the existing Alternatives flow

`AlternativeDetailScreen` gains a "Play" button, rendered only when `widget.alternative.category == AlternativeCategory.game` (both current game items qualify; this also means any future game-category alternative added to the library would need its own explicit routing case below — not a generic auto-dispatch, since each game is a bespoke screen, not a data-driven template).

Routing by `alternative.alternativeId`:
- `'bubble_pop'` → push `BubblePopGameScreen`
- `'word_puzzle'` → push `WordSearchGameScreen`

Existing behavior is fully preserved: the instructions text, the "Did this help?" Yes/No buttons, and `recordOutcome` logging are unchanged and still available on the same screen before or after playing.

**Content copy update** (`mobile/lib/data/habit_alternative_library.dart`): the current `description`/`instructions` strings for both game entries promise a specific duration ("play for 2 minutes") or a "round" structure ("try one round") that no longer matches the no-timer, no-rounds design agreed here. These two entries' text will be reworded to describe the actual experience (a calm, self-paced distraction) without a fabricated time/round claim.

## Testing plan

- `mobile/test/domain/word_search_generator_test.dart`: every word in the bank ends up placed somewhere in-bounds along a straight line matching one of the three allowed directions; intersecting cells between two placed words agree on their letter; every cell not part of any placed word is a single uppercase letter (never empty/null).
- `mobile/test/screens/bubble_pop_game_screen_test.dart`: a bubble appears within the test's pump window; tapping a bubble removes it from the tree; the "Done" button pops the screen.
- `mobile/test/screens/word_search_game_screen_test.dart`: the word bank renders all 8 target words; dragging across a known-placed word's cells (using a fixed/seeded puzzle via constructor injection, not real randomness) marks it found and updates the bank; the "Done" button pops the screen at any progress state.
- `mobile/test/screens/alternative_detail_screen_test.dart` (existing file, extended): the "Play" button is present for both game-category alternatives and absent for non-game ones; tapping it navigates to the correct game screen per `alternativeId`.

No existing test is deleted or weakened by this work — `alternative_detail_screen_test.dart`'s current assertions (title/description/instructions render, Yes/No logs an outcome) continue to hold unchanged; the new Play-button coverage is additive.

## Explicitly out of scope

- No score, timer, difficulty levels, or replay/high-score tracking for either game (contradicts the calm/no-pressure design goal agreed above).
- No Firestore persistence of game sessions/completions — only the pre-existing "Did this help?" outcome logging persists anything.
- No additional game-category alternatives beyond the two that already exist in the library.
- No changes to `AlternativesController`, `HabitAlternativeAttemptRepository`, Firestore rules, or the ranking/filtering logic in `high_risk_screen.dart`/`habit_alternative_matcher.dart`.

# Onboarding Flow Redesign — Design Spec

**Date:** 2026-08-30
**Status:** Approved for planning

## Problem

The onboarding flow (Module 1) currently collects product type, daily usage, cost,
motivation, and quit strategy through two generic Material-form screens
(`OnboardingDataScreen`, `QuitStrategyScreen`) that don't match the approved UI
references in `docs/UI_Design/` (sage/terracotta illustrated screens with a
product grid, per-product quantity sliders, and a goal-selection screen with an
inline date picker). The transition from Register → Consent → this form is an
abrupt `setState` swap with no animation, which reads as the flow "skipping"
past registration. Additionally, the data model has no `hookah` product type,
even though every reference screen shows Hookah as a selectable option.

## Reference designs

Located in `docs/UI_Design/` (file names don't all match the content 1:1 —
noted below):

| Screen | Source file | Content |
|---|---|---|
| Product selection | `user on boarding 4.png` | "What do you use?" — 2×2 grid: Vape / Cigarettes / Pouches / Hookah |
| Cigarette quantity | `after on boarding if ciagrettes selected this will open 4a.png` (left half) | "How many cigarettes do you use in a day?" — counter + slider 0–40+ |
| Goal selection | same file, right half | "What's your goal?" — 3 options + inline date picker, "Generate My Plan" |
| Vape quantity | `4b.png` | "How many puffs or ml do you use in a day?" — Puffs/ml toggle + counter + slider 0–400+ |
| Pouches quantity | `4c.png` | "How many pouches do you use in a day?" — counter + slider 0–20+ |
| Hookah quantity | `4d.png` | "How many sessions do you have in a week?" — counter + slider 0–12+ |

All six share one visual template: rounded header illustration, segmented
progress bar, "< Back" link, heading, interactive content, helper caption,
full-width terracotta pill button.

## Required end-to-end sequence

1. **Profile Registration** (existing `RegisterScreen`, unchanged) → Consent
   (existing `ConsentScreen`, unchanged)
2. **Product Selection** — "What do you use?" (new)
3. **Product-Specific Quantity** — conditional on product (new, one reusable
   screen + per-product config)
4. **Goal Selection** — "What's your goal?" + conditional quit-date picker
   (new, replaces `QuitStrategyScreen`)
5. **Habit Summary** — "Tell us about your habit": recap of product, daily
   usage, and goal/quit date (repurposed `OnboardingCompleteScreen`)
6. **Dashboard** (existing, unchanged)

## Decisions from stakeholder Q&A

- **Hookah**: add full support (`ProductType.hookah`), not deferred. Verified
  low blast radius — every existing usage site (`relapse_log_screen.dart`,
  `firestore_user_repository.dart`, `firestore_journal_repository.dart`)
  handles `ProductType.values` generically or via a lookup map that just needs
  one more entry.
- **Extra fields** (cost per unit, primary motivation, personal challenges,
  past quit attempts): none appear in the reference screens. Explicit
  instruction: match the pictures exactly, no additional fields. `costPerUnit`
  already defaults to `0` everywhere it's consumed
  (`DashboardStateCalculator._countdownState`/`_nicotineFreeState` both do
  `user.costPerUnit ?? 0`), so making it optional at collection time doesn't
  break Money Saved — it just starts at $0 until set elsewhere (out of scope
  here). The other three fields are already optional params on
  `recordProfile` and aren't read anywhere outside onboarding, so no model
  change is needed for them — onboarding just stops surfacing UI for them.
- **"Tell us about your habit"**: repurpose the existing post-strategy
  `OnboardingCompleteScreen` (currently "You're All Set!", quit-date-only) into
  this screen — rename its heading and expand its recap to include product
  type and daily usage, not just quit date. No new/duplicate summary screen.

## Architecture

### Data model changes

- `mobile/lib/models/product_type.dart`: add `hookah` to the enum.
- `mobile/lib/controllers/onboarding_controller.dart`: `recordProfile`'s
  `costPerUnit` parameter becomes optional (`double? costPerUnit` with no
  `required`, default `null`). Validation logic changes from "required,
  must be ≥ 0" to "if provided, must be ≥ 0" — `null` skips the check
  entirely. `baselineDailyUsage` keeps its existing `> 0` requirement
  unchanged.

### Shared onboarding chrome (`mobile/lib/screens/onboarding/widgets/`)

- `onboarding_progress_bar.dart` — takes `currentStep`/`totalSteps` (4 total:
  Product Selection / Quantity / Goal / Habit Summary). Rounded segments,
  sage-dark fill vs. sage-light track, matching the reference bar exactly.
- `onboarding_header_illustration.dart` — fixed-aspect rounded-top image
  frame wrapping `Image.asset`, mirroring the existing `RegisterHeroHeader`
  pattern (same codebase convention: crop reference art once, overlay real
  widgets on top rather than redrawing illustrations in code).
- `onboarding_back_link.dart` — "< Back" text button in sage.

The existing `ElevatedButtonTheme` (terracotta pill, full width, 56px) already
matches the reference "Continue"/"Generate My Plan" button pixel-for-pixel, so
screens use `ElevatedButton` directly — no new button widget needed.

### New screens

- **`product_selection_screen.dart`**: 2×2 `GridView`/`Wrap` of product
  cards (icon + label). Selected card: terracotta background + checkmark
  badge with sparkle accents, per the reference. Emits the chosen
  `ProductType` to the caller on Continue.

- **`product_quantity_screen.dart`** + **`product_quantity_config.dart`**:
  one screen, one config record per `ProductType`:
  ```
  ProductQuantityConfig(
    question, headerAsset, unitLabel, min, max, step, defaultValue,
    secondaryUnit,   // null for all but vape (adds the Puffs/ml toggle)
  )
  ```
  Renders the shared +/- counter, slider, and helper caption
  ("This helps us personalize your plan."). Interactive minimum is clamped to
  `1` (not `0`) so the counter can never rest on a value that fails
  `OnboardingController`'s `baselineDailyUsage > 0` validation — the "0" tick
  label still renders on the slider axis exactly as pictured, it's just not
  reachable by the thumb/counter. Vape's mode toggle (Puffs vs. ml) only
  changes the unit label and slider range shown; the numeric value collected
  is whichever mode is active when Continue is tapped.

- **`goal_selection_screen.dart`**: three `_StrategyOptionCard`-style rows
  reusing the existing `QuitStrategy` enum (`coldTurkey` → "Quit Completely",
  `gradual` → "Reduce Gradually", `dateBased` → "Quit by a Specific Date"),
  terracotta border+icon-tint on selection. Selecting "Quit by a Specific
  Date" reveals a target-date summary row + inline month calendar (custom
  `GridView` of day cells) instead of the current native `showDatePicker`
  dialog, matching the reference. Continue button label becomes
  "Generate My Plan".

- **`onboarding_complete_screen.dart`** (edited, not replaced): heading
  changes to "Tell us about your habit"; body adds product type and daily
  usage rows above the existing quit-day/reduction-plan text. Button and
  `onContinue` plumbing to Dashboard unchanged.

### Deleted

- `onboarding_data_screen.dart`, `quit_strategy_screen.dart` — fully
  superseded by the screens above.

### Illustration assets

Cropped from the `docs/UI_Design` source PNGs with Pillow (same approach
already used for `register_hero.png`/`welcome_hero_full.png` — crop once,
commit as a static asset, overlay real widgets on top) into
`mobile/assets/images/onboarding/`:
`product_selection_header.png`, `cigarette_quantity_header.png`,
`vape_quantity_header.png`, `pouches_quantity_header.png`,
`hookah_quantity_header.png`, `goal_selection_header.png`. Registered in
`pubspec.yaml`'s `assets:` list.

### Navigation (`mobile/lib/main.dart`)

`_Step` enum: replace `profile`/`strategy` with `productSelection`/
`quantity`/`goal`; `complete` stays. `_OnboardingFlowState` holds the
in-progress `ProductType` selection locally (same pattern as
`_pendingPhoneNumber`) to pass into the quantity screen's config lookup.

The step `switch` in `build()` gets wrapped in an `AnimatedSwitcher` (fade +
slight horizontal slide, ~250ms) keyed by `_step`, so every transition in the
whole flow — including Register→Consent, which is the one currently reported
as feeling abrupt — animates smoothly. This is a flow-level fix, not
per-screen.

## Error handling / edge cases

- Quantity screen Continue is disabled only in the already-impossible case of
  no `ProductType` selected (can't happen — `productSelection` always sets
  one before advancing).
- Goal selection: "Quit by a Specific Date" and "Reduce Gradually" both
  require a target date server-side (`QuitDateCalculator` throws
  `ArgumentError` without one); Continue stays enabled but submission surfaces
  the existing error text if no date is picked — same behavior as today's
  `QuitStrategyScreen`, just against the new inline calendar instead of the
  native picker.
- Hookah's `baselineDailyUsage` stores sessions-per-week (not per-day) in the
  same field `QuitDateCalculator`'s linear taper already uses generically —
  no calculator changes needed, just a unit-label difference in the UI.

## Testing

- `onboarding_controller_test.dart`: existing cases untouched (verified each
  one still passes a `costPerUnit`, so relaxing "required" doesn't change
  their behavior). Add: `costPerUnit` omitted entirely succeeds with `null`
  stored; `ProductType.hookah` round-trips through `recordProfile` and
  `submitQuitStrategy`.
- Replace `onboarding_data_screen_test.dart` and `quit_strategy_screen_test.dart`
  with widget tests for `product_selection_screen_test.dart`,
  `product_quantity_screen_test.dart` (including the vape toggle and the
  clamped-minimum behavior), `goal_selection_screen_test.dart` (date picker
  reveal/hide, button label swap).
- Update `onboarding_complete_screen_test.dart` (or add one, if none exists)
  for the expanded recap content.
- Update `app_flow_test.dart`'s end-to-end walk to go through
  Product Selection → Quantity → Goal → Habit Summary → Dashboard.

## Out of scope

- Collecting `costPerUnit` (Money Saved defaults to $0 until a future,
  separately-scoped screen/settings entry collects it).
- Any change to `primaryMotivation`/`personalChallenges`/`pastQuitAttempts`
  storage — fields stay on the model, unused by onboarding going forward.
- Hookah support in any screen other than onboarding/relapse-logging (already
  generic) — no new Hookah-specific dashboard/analytics work.

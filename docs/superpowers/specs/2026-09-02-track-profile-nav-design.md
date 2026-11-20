# Track & Profile Bottom-Nav Screens — Design Spec

**Goal:** Wire up the two dead bottom-nav icons (Track, Profile) that have sat disabled since the Dashboard's original build (`dashboard_bottom_nav.dart`'s doc comment: "Track/Profile have no screens yet and stay visually present but disabled"). Build real, data-backed screens for both, matching the two supplied reference mockups, with polished animation and hand-painted illustration consistent with the existing app's visual language — not a bare functional patch.

**Root cause (already diagnosed, not open):** `_navTile()` in `dashboard_bottom_nav.dart` only attaches an `InkWell`/`onTap` when a callback is passed; Track/Profile are called with no callback, so there is no gesture handler at all (not a bug — documented as intentionally deferred). No `TrackScreen`/`ProfileScreen` exist anywhere in the codebase; no route references `/track` or `/profile`.

**SDD/FR traceability:** Neither Track nor Profile is an owned module/FR in `docs/Quit_Companion_SDD.md` or `docs/PROJECT_BUILD_ROADMAP.md` — they are bottom-nav slots from the original UI mock with no assigned spec. This work is scoped as: (a) completing the Dashboard's general chrome (the same FR4/§2.1 "phase-aware dashboard" umbrella the bottom nav itself already falls under), plus (b) a small, additive amendment to Module 1's FR2 (profile data) to add a `gender` field — Module 1 is marked COMPLETE/device-verified, so this must be additive-only (new nullable field, new optional onboarding step) and must not change any existing field, screen, or test's behavior.

**Tech stack:** Flutter/Dart only, same patterns already used throughout `lib/screens/dashboard` and `lib/screens/rewards` — `provider` for state, `CustomPaint` for hand-painted illustrations/charts (no new packages, no image assets, matching `DashboardBackground`/`_JournalIllustration`/`WeeklyTrendChartPainter` precedent).

## Global constraints

- No new third-party packages (no `fl_chart`, no asset images) — all illustrations and charts are hand-painted Flutter primitives via `CustomPaint`/`Icon`/`Container` composition, exactly like every existing illustration in this codebase.
- No fabricated data. Every stat shown must trace to a real, already-persisted source (craving logs, journal/relapse entries, user profile fields). Where the mockup implies a metric that doesn't exist 1:1, the resolved mapping (below) is authoritative — do not invent new stored counters.
- Modules 1-5 stay behaviorally frozen except the one additive `gender` field on `NicotineUser` + one new optional onboarding step. No existing field, screen route, or test changes behavior.
- Match `AppColors`/`AppTheme` exactly — no new colors introduced outside that palette.
- Every new interactive element gets a `Key(...)` following this codebase's existing widget-testing convention (e.g. `dashboard_bottom_nav_community`).

## 1. Data model changes

- `mobile/lib/models/gender.dart` (new): `enum Gender { male, female }`.
- `NicotineUser` (`nicotine_user.dart`): add nullable `final Gender? gender;` + thread through constructor and `copyWith`. Firestore read/write (`firestore_user_repository.dart`) adds the field additively (older documents with no `gender` key must keep loading correctly, same null-safety precedent already used for the `mood*` fields on `CravingLog`).
- New onboarding step: **Gender selection**, visually consistent with `ProductSelectionScreen` (two large selectable cards/tiles). Inserted after Consent, before Product Selection, in `main.dart`'s `_Step` enum and `_buildStep` switch. `OnboardingController` gets `void recordGender(Gender gender)` (same shape as `recordConsent`).
- Existing/pre-gender users: `gender == null` → Profile defaults to the female illustration (today's only asset), correctable later from **Personal Information** (see §4), which is the one place gender can be set/changed post-onboarding.

## 2. Navigation wiring

- `DashboardBottomNav` (`dashboard_bottom_nav.dart`): add `required VoidCallback onTrackTap` and `required VoidCallback onProfileTap`. The two tiles switch to `active: true` with real `InkWell`s and new keys (`dashboard_bottom_nav_track`, `dashboard_bottom_nav_profile`), mirroring the existing `dashboard_bottom_nav_community` pattern exactly.
- `DashboardScreen` (`dashboard_screen.dart`): add `_openTrack`/`_openProfile` methods (same `Navigator.push(MaterialPageRoute(...))` shape as every existing `_open*` method), wired to the new callbacks. Add one new required constructor param, `required VoidCallback onLogout`, passed straight through to `ProfileScreen`.
- `main.dart`: in the `_Step.loggedIn` case, pass `onLogout: () { context.read<AuthController>()... .logout(); setState(() => _step = _Step.welcome); }` (exact repository call resolved during implementation — `AuthController` currently has no `logout()` method itself, only wraps register/login/Google-signin, so this needs either a new `AuthController.logout()` passthrough to `AuthRepository.logout()`, added the same additive way as its other methods, or a direct `context.read<AuthRepository>()` — implementer picks whichever matches this file's existing DI pattern once looked at directly).
- "Active tab" is push-based, not a persistent bottom-tab index — this matches how Home/Community/Health-Bot already behave (they push new routes rather than swap a selected index), so Track/Profile need no new tab-state machine.

## 3. Track screen

New `TrackController` (`controllers/track_controller.dart`), loaded the same way every other controller loads (`ChangeNotifier`, `loading/loaded/error` status, `Future<void> loadTrack(String userId)`), backed by existing repositories only (`CravingLogRepository`, `JournalRepository`, `UserRepository` — no new repository, no new Firestore collection).

Computed fields:
- **This Week chart** — do not recompute; `TrackScreen` receives the already-loaded `DashboardController` (same instance `DashboardScreen` holds) and reuses its `weeklyTrend` + the existing `WeeklyTrendChartPainter`, titled "This Week" (not "Smoke-free streaks" — that label implied a per-day streak metric that doesn't exist; reusing the real craving-trend data under an accurate title was the agreed resolution).
- **Total Cravings Logged** — count of all `CravingLog`s for the user (`getRecentLogs(userId, user.quitDate ?? epoch)` or equivalent all-time fetch).
- **Cravings Resisted** — `CravingLogRepository.countCravingsResistedSince(userId, since)` (existing method, already means "logged and not immediately relapsed" per its own doc comment). Displayed percentage = `resisted / (resisted + relapsesInSamePeriod) * 100`, where `relapsesInSamePeriod` is the count of relapse-flagged `JournalEntry`s in the same window — a real ratio, not always 100%, using only data that already exists.
- **Longest Streak** — max gap in days across the sorted sequence `[quitDate, ...relapseFlagged JournalEntry.entryDate, today]`. Computed in `TrackController`, not stored.
- **Trigger Breakdown** (renamed from "Nicotine Product Breakdown" — the rows are `TriggerCategory` values, not product types) — count of craving logs grouped by `TriggerCategory`, horizontal bars, same five categories already defined in `trigger_category.dart`.
- **Recent Activity** — merged feed of craving logs ("Craving logged — {triggerCategory.label}") and relapse-flagged journal entries ("Relapse logged — {triggerCategory.label}"), sorted newest-first, capped at 10. Empty state follows the existing `rewards_badges_locked_hint` pattern (icon + explanatory sentence in a card) rather than a blank screen.

## 4. Profile screen

`ProfileScreen` (new), taking `userId`, the existing `DashboardController` (for `user`/phase state — no refetch), and `onLogout`.

- **Header:** hand-painted background (leaves/hills, same technique as `DashboardBackground`/`_RewardsHeaderBanner` — a `Container`+`Stack` of simple shapes, not an image asset) behind a circular avatar. Avatar is a `CustomPaint`/composited-`Icon` illustration with two variants (male/female) selected by `user.gender` (default female when null). "Edit Profile" (pencil, top-right) opens a dialog to edit **Name only** (per agreed scope) — saved via the existing `UserRepository.saveUser`.
- **Stat chips (3):** Quit Date (`user.quitDate`), Product Type (`user.productType.label`), and a phase-aware third chip: "Days Nicotine-Free" (`NicotineFreeState.nicotineFreeDays`) when in that phase, else "Days Until Quit" (`CountdownState.daysUntilQuit`) — reusing `DashboardController.state`, not recomputing.
- **Settings list (7 rows, icon + label + chevron, matches mockup exactly):**
  - Personal Information → new screen: read-only display of name/email/product type/quit date, plus a male/female avatar picker (the one place gender can be set or corrected after onboarding).
  - My Quit Plan → existing `WeeklyPlanScreen` (already built, Module 4).
  - Notifications → existing `ReminderSettingsScreen` (already built).
  - Privacy & Security → new static-content screen (data-handling summary — what's stored, that it's Firebase-backed, no third-party sharing; no new backend/settings logic).
  - Achievements → existing `RewardsScreen` (already built, Module 8).
  - Help & Support → new static-content screen (FAQ-style content + a mailto/support-contact affordance).
  - About Quit Companion → new static screen (app name/version/short description).
- **Log Out** row (terracotta, icon + text) calls `widget.onLogout`.

## 5. Visual polish & animation (applies to both screens)

Directive from the user: make this as professional, "classy," and animated as the existing design system supports, reusing established techniques rather than introducing a new visual language.

- Both screens reuse `DashboardScreen`'s existing entrance-animation pattern exactly: a `SingleTickerProviderStateMixin` + `AnimationController` driving staggered `FadeTransition`+`SlideTransition` per section (the same `_animated(index, child)` helper, factored out to a small shared widget/mixin so it isn't copy-pasted a third time — the one deliberate shared-code decision in this spec, since it would otherwise be triplicated verbatim).
- Track's stat numbers (Total Cravings, Longest Streak, etc.) count up from 0 on first load via `TweenAnimationBuilder<int>` — cheap, no new dependency.
- Track's Trigger Breakdown bars animate their width in (`TweenAnimationBuilder<double>` per bar, staggered by index) rather than appearing at full width instantly.
- The "This Week" line chart draws in progressively (`CustomPaint` + `AnimationController` driving a 0→1 "reveal fraction" the painter clips to), matching the polish level of a finished product rather than a static line.
- Profile's settings list rows fade/slide in staggered by index (same helper as above).
- Screen transitions: pushing Track/Profile use the same `MaterialPageRoute` as every other Dashboard destination (no custom page-route animation — introducing one here and nowhere else in the app would be inconsistent, not "classy").
- Avatar illustrations, header backgrounds, and any new iconography are hand-painted `CustomPaint`/composited-widget art in the existing sage/terracotta/cream palette — never a placeholder grey box, never an external image asset.
- All of the above must degrade gracefully to instant/static rendering under `flutter test`'s default `pumpAndSettle` semantics — no animation may block widget tests or run indefinitely (mirrors how `_entranceController` is already handled in `DashboardScreen`'s existing tests).

## 6. Testing

Widget tests (fake repositories, this codebase's existing convention):
- Bottom-nav taps reach `TrackScreen`/`ProfileScreen` (mirrors the existing `dashboard_bottom_nav_community` test).
- `TrackController`: correct counts/percentages/streak computation against seeded fake craving logs + journal entries, including zero-data and zero-relapse edge cases.
- Gender-based avatar renders the correct variant, and defaults correctly when `gender == null`.
- Edit Profile name save round-trips through the fake `UserRepository`.
- Log Out invokes `onLogout`.
- Existing Home/Health-Bot/Community nav tests continue passing unmodified (regression guard for the "don't break the other three" requirement).

## Open items for the implementation plan to sequence explicitly

1. Exact `AuthController`/`AuthRepository` logout wiring (noted as unresolved in §2 — needs a direct look at `main.dart`'s current DI shape before committing to one approach).
2. Whether `TrackController` needs its own Firestore-backed "all-time since" query or can reuse `getRecentLogs` with a sufficiently old `since` — implementer's call based on what's cheapest against existing repository interfaces without adding a new method.

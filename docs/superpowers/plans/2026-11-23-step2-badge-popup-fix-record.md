# Step 2 — Badge congratulations pop-up (FR9 / UC7): fix record (2026-11-23)

Resolves the two test issues left pending in the first Step 2 pass (see "PENDING VERIFICATION" in `2026-08-19-module-8-gamification-rewards-implementation-record.md`).

## Issue 1 — account-deletion test blocked by the pop-up

**Test:** `test/app_flow_test.dart` → "deleting an account returns to the welcome screen". It failed with `Bad state: No element` at `ensureVisible(profile_row_privacy_security)`.

**Root cause:**
- The test user's quit date is 2026-01-01, so the first Dashboard load awards **five** badge tiers at once (1, 7, 30, 90, 180 days).
- The listener showed **one modal dialog per badge, back to back**.
- The test never dismissed them, so its Profile-tab tap hit the dialog barrier (the Flutter tap warning confirmed the hit landed on the modal, not the button).
- A real returning user would face the same chain of five blocking modals.

**Related lifecycle defect found:**
- Pending celebrations lived in the app-scoped `GamificationController` and were **not cleared on logout or account deletion**.
- The next account signed in on the device could see the previous user's queued badge (the listener shows anything pending when the Dashboard mounts).

## Issue 2 — small-screen test hang

**Test:** `test/responsive_screens_test.dart` → "portrait 320x640 text 1.5: dashboard" (and every later text-1.5 case). It hung indefinitely, and `--timeout` didn't stop it.

**Root cause** (confirmed with temporary diagnostics, since removed):
- At 1.5× text on a 320×640 screen, the dialog content was taller than the screen. Everything, including the "Keep going" button, was inside one `SingleChildScrollView`.
- The button was laid out at `y = 888–984`, below the visible area.
- Every `tap()` landed off-screen and the dialog never closed.
- The first Step 2 pass had added an **unbounded** `while (button visible) tap()` loop to the test, so it spun forever.

So the root cause was a real UI defect (on a small phone with large text, the only button was hidden below the fold) plus an unsafe test loop.

## Fixes

| File | Change |
| --- | --- |
| `mobile/lib/features/rewards/presentation/widgets/badge_celebration_dialog.dart` | **Pinned action button** below a `Flexible` scrollable body, so it's always on screen. **One dialog for several badges** ("You unlocked N new badges", one row per badge, total points). Compact trophy when screen height < 700. Same theme, keys and copy style. |
| `mobile/lib/features/rewards/presentation/widgets/badge_celebration_listener.dart` | Shows everything pending in one dialog (`takeAllCelebrations`); badges earned while it's open get a later dialog. Still top-route-only and still one-time. |
| `mobile/lib/features/rewards/controllers/gamification_controller.dart` | Added `takeAllCelebrations()` and `clearSession()` (clears queued celebrations and session state). `takeNextCelebration()` kept. |
| `mobile/lib/app/quit_companion_app.dart` | `_logoutToWelcome()` (used by logout **and** account deletion) now calls `GamificationController.clearSession()`, alongside the existing Health-Bot/Dashboard clears. |
| `mobile/test/app_flow_test.dart` | Asserts the combined dialog appears, dismisses it with one tap, asserts it's gone, then continues the unchanged deletion flow. |
| `mobile/test/responsive_screens_test.dart` | Replaced the unbounded loop: exactly one dialog, its button inside the 640 px screen, one tap closes it, no exceptions. A regression now fails fast instead of hanging. |
| `mobile/test/features/rewards/presentation/rewards_screen_test.dart` | `dismissCelebrations` bounded to 3 taps with a failing assertion (it had the same unbounded-loop pattern). |
| `mobile/test/features/rewards/presentation/badge_celebration_test.dart` | Updated from sequential dialogs ("Next badge") to the combined dialog. New: multi-badge dialog content and points total; button on screen and working at 320×640 / 1.5× text. |
| `mobile/test/features/rewards/controllers/gamification_controller_test.dart` | New: `takeAllCelebrations` returns all pending badges once; `clearSession` drops pending celebrations. |

The badge celebration feature is kept: it's still one-time, still shown on Dashboard/Rewards, and badge saving, duplicate prevention, points and streaks are unchanged.

## Verified results (2026-11-23)

- Affected tests (`test/features/rewards`, `test/app_flow_test.dart`, `test/features/dashboard`, `test/responsive_screens_test.dart`): **149 passed, 0 failed**, including all 38 responsive cases.
- **Complete Flutter suite — all 119 test files, with `responsive_screens_test.dart` included again: 805 passed, 0 failed, 0 skipped** (`flutter test --timeout 120s`, about 3.5 minutes). `flutter analyze`: no issues.
- This is the first fully green complete run since the hang appeared. Earlier steps had to exclude `responsive_screens_test.dart`.

## Still manual

Device check on a physical Android phone (not performed):
- A user who has just earned several badges sees **one** dialog.
- "Keep going" is visible without scrolling on a small phone with the largest system font.
- After logout and login as another account, no previous-account badge appears.

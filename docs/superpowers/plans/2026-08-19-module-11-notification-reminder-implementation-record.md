# Module 11 — Notification & Reminder — Implementation Record

**Status: IMPLEMENTED (baseline 2026-08-19; FCM client support revised 2026-11-16).** This closes out the **entire 11-module SDD scope** — every module owned by Sukaina, every module owned by Mehreen, and this final shared/core module.

**Decision history:** The 2026-08-19 sections below preserve the original explicit choice to exclude FCM and build local reminders only. On 2026-11-16 the user reversed that exclusion. The current mobile implementation now requests FCM permission through the reminder settings flow, receives messages, and registers/refreshes/removes the signed-in user's token in a private Firestore subcollection. Earlier statements below describing FCM as excluded are historical, not the current implementation state. A trusted sender/scheduler remains external and is not included.

This module belongs to the **shared/core** ownership row (SDD §2.1, "Notification & Reminder", FR14), not to either named team member individually.

---

## Step 1 — Why this module is required, and the exact FR14 requirement (re-read from the finalized SDD)

**SDD §3, FR14** (verbatim): *"EMA push notifications (3–5/day) — unchanged."* Traced to *"= SRDS FR13"*.

**SRDS FR13** (verbatim, `docs/srds.txt` line 427): *"Push Notifications (EMA) — The system shall send 3 to 5 daily Ecological Momentary Assessment (EMA) prompts via FCM push notifications to remind users to log craving levels, mood, and context."*

**The user's explicit direction for this implementation, overriding the SRDS's literal "via FCM"**: build this with **in-app/local, on-device reminders only** — no Firebase Cloud Messaging, no new backend notification infrastructure. This is a deliberate, explicit product/architecture decision made by the user for this session, not a silent reinterpretation of the spec. The behavioral requirement FR14 actually cares about — periodically nudging the user, 3-5 times a day, to log a craving/mood/context entry — is fully satisfiable without FCM; "via FCM" describes SRDS's original *delivery mechanism* choice, not the requirement's substance.

**What exactly FR14 requires, distilled**:
1. 3 to 5 reminder notifications per day.
2. Purpose: prompt the user to log craving levels, mood, and context (i.e., nudge toward `LogCravingScreen`, Module 3).
3. (SRDS External Interfaces, §3.3.2) device notification permission is required.

**What FR14 does NOT specify**: exact reminder clock times, whether the count is user-configurable, persistence format, or any UI. Those are this module's own scoped decisions (Step 4).

## Step 2 — Requirements satisfied

FR14's core behavior (3-5 daily on-device prompts reminding the user to log a craving/mood/context entry), fully local — no FCM, no backend endpoint, no server-side scheduling.

## Step 3 — Existing architecture inspected before building

- **Every prior module's controller/repository/screen-injection pattern** (`ChangeNotifierProvider` in `main.dart`, an abstract repository/service interface with Fake + real implementations, a controller consuming the interface, a screen consuming the controller) — reused exactly, no new architectural shape invented.
- **`shared_preferences`** was already a project dependency (used by `lib/data/recent_email_store.dart` for recent-login-email suggestions) — reused directly for reminder settings persistence rather than adding a new local-storage dependency.
- **The Dashboard header's bell icon** (`lib/screens/dashboard/widgets/dashboard_header.dart`) was already present but explicitly documented as *"a visual placeholder: notifications aren't implemented, so it's non-functional"* — built in Module 2, specifically anticipating this exact feature. This is the natural, already-prepared entry point, reused rather than inventing a new Quick Access tile (which would have meant altering the approved 3×3 `dashboard 5.png` grid layout that every prior module's tile wiring has kept intact).
- **No existing notification/reminder code of any kind** existed anywhere in the repo before this module — confirmed by grep (no `notification`, `reminder`, `fcm`, `firebase_messaging` hits in `lib/`).

## Step 4 — Design decisions made inline

1. **Local OS-level scheduled notifications (`flutter_local_notifications` + `timezone` + `flutter_timezone`), not a purely in-app banner.** A "reminder" that only appears when the user happens to have the app open already isn't really a reminder — SRDS's own intent (3-5 *daily* prompts) implies something that reaches the user even when the app is closed. `flutter_local_notifications` delivers real OS notification-tray entries, scheduled and fired entirely by the device's own OS — zero backend, zero network call, zero Firebase project involvement. This is the genuine "in-app/local" reading of the requirement, not a weaker substitute. `timezone`/`flutter_timezone` are the standard, minimal companion packages needed to schedule notifications at correct daily *local* wall-clock times (important since the SDD's target audience is Pakistan-based — a naive UTC-only schedule would fire reminders at the wrong local time). All three are pure client-side libraries with no server component — consistent with "no unnecessary backend infrastructure."
2. **Modular delivery-mechanism seam for future FCM.** `ReminderNotificationService` (abstract: `requestPermission()`, `scheduleDailyReminders(times)`, `cancelAllReminders()`) deliberately has zero FCM-shaped concepts (no device tokens, no topics, no server endpoint) — see Step 10 for exactly what a future `FcmReminderNotificationService` implementing this same interface would need to add. `ReminderController` and every UI file depend only on this interface, never on `flutter_local_notifications` directly.
3. **Reminder times: 3/4/5 evenly spread across a fixed 09:00-21:00 waking-hours window, not user-picked clock times.** FR14 specifies only a *count* (3-5/day), never scheduling granularity or specific times. `computeReminderTimes()` (`lib/domain/reminder_schedule_calculator.dart`) is a pure, tested function that slices the window into N equal segments and places a reminder at each segment's midpoint — deterministic, evenly distributed, no clustering at the window edges.
4. **Frequency is user-configurable (3, 4, or 5), enable/disable is user-configurable; individual reminder clock times are not.** This satisfies "reminder frequency/time configuration if required by FR14" at the level FR14 actually specifies (a count within 3-5), without inventing a full custom-scheduling UI FR14 never asked for.
5. **Settings are device-local (`shared_preferences`), not synced via Firestore.** Every other setting in this app lives in a `nicotineUsers/{userId}/...` Firestore document. Reminder settings are different in kind: a scheduled local notification is inherently tied to the one device it was scheduled on. Syncing "enabled: true" to Firestore from device A would not cause device B to actually have any notifications scheduled — it would create a setting that *looks* shared but isn't honored, which is worse than not syncing it at all. Documented explicitly in `ReminderSettingsRepository`'s doc comment.
6. **Inexact scheduling (`AndroidScheduleMode.inexactAllowWhileIdle`), not exact alarms.** Android 12+ gates exact alarms behind a separate, more sensitive permission (`SCHEDULE_EXACT_ALARM`) that requires additional user friction to grant. A wellness check-in reminder does not need to-the-minute precision the way a real alarm clock does — inexact scheduling (the OS may fire it a few minutes late) needs only the standard `POST_NOTIFICATIONS` permission, keeping the permission footprint minimal.
7. **"Handling app restart" is done by re-syncing the schedule every time the Dashboard mounts**, not via a boot-time broadcast receiver (`RECEIVE_BOOT_COMPLETED`). This app has no existing precedent for any startup-time background bootstrapping — every controller loads its own data reactively when its owning screen mounts. Since the Dashboard is the screen a craving-tracking app's user reaches most frequently (immediately after every login), calling `ReminderController.loadSettings()` there — which re-asserts the OS-level schedule if the persisted setting says "enabled" — is a lightweight, idempotent self-healing mechanism that fits the existing architecture instead of adding a new one, at the cost of not guaranteeing recovery on a reboot where the user never reopens the app (an accepted, documented limitation — see Step 9).

## Step 5 — Folder/file plan

New: `lib/models/reminder_settings.dart`; `lib/domain/reminder_schedule_calculator.dart`; `lib/data/reminder_settings_repository.dart` (+fake/`shared_prefs_`), `reminder_notification_service.dart` (+fake/`local_`); `lib/controllers/reminder_controller.dart`; `lib/screens/settings/reminder_settings_screen.dart`. Modified: `dashboard_header.dart` (bell icon wired), `dashboard_screen.dart`, `main.dart`, `android/app/src/main/AndroidManifest.xml` (one new permission), `android/app/build.gradle.kts` (core library desugaring — see Step 6's build-failure note), `pubspec.yaml` (three new dependencies: `flutter_local_notifications`, `timezone`, `flutter_timezone`).

## Step 6 — TDD narrative, layer by layer

**Domain** — `reminder_schedule_calculator_test.dart` (5 cases: exact count returned, every time within the 09:00-21:00 window, strictly increasing and evenly spaced, deterministic, rejects a count outside 3-5). GREEN on first attempt — **5/5 passed**.

**Repository** — `fake_reminder_settings_repository_test.dart` (3 cases: defaults before any save, save/get round-trip, a simulated failure). GREEN on first attempt — **3/3 passed**.

**Controller** — `reminder_controller_test.dart` (8 cases: `loadSettings` re-syncs the schedule when enabled, does nothing to the notification service when disabled; `setEnabled(true)` requests permission → schedules → persists; a denied permission fails cleanly with an error and nothing scheduled/persisted; `setEnabled(false)` cancels and persists; `setDailyFrequency` reschedules when enabled, is a no-op on the notification service when disabled, and silently ignores an out-of-range value). GREEN on first attempt — **8/8 passed**.

**Screen** — `reminder_settings_screen_test.dart` (6 cases) surfaced **one test-authoring issue, not an implementation bug**: `find.textContaining('this device')` matched two legitimate strings on the screen (the toggle's own subtitle and the local-vs-server disclaimer paragraph both mention "this device") — fixed by asserting a more specific substring (`'not sent from a server'`) unique to the disclaimer. Re-ran: **6/6 passed**.

**Real plugin API verification.** Before writing `LocalReminderNotificationService`, the actual installed `flutter_local_notifications` 22.3.0 source (`FlutterLocalNotificationsPlugin.initialize()` and `.zonedSchedule()`) was read directly from the pub cache to confirm the exact named-parameter signatures, rather than guessing from memory of an older API version — the plugin's major-version-22 API takes `settings:`/`id:`/`scheduledDate:`/`notificationDetails:` as named parameters, which an earlier guess (positional arguments, matching some older tutorials) got wrong and `flutter analyze` caught immediately, fixed before any test run.

**A real Gradle build failure, found and fixed** (not caught by `flutter analyze`/`flutter test`, only by the actual `flutter build apk` step — see Step 8 for why this module's build step matters more than any prior module's): the first `flutter build apk --debug` after adding `flutter_local_notifications` failed with `Execution failed for task ':app:checkDebugAarMetadata' ... Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for :app.` Diagnosed as a standard, well-documented Android Gradle requirement — the plugin's Android implementation uses `java.time` APIs that need desugaring support on the consuming app module. **Fixed** by adding `isCoreLibraryDesugaringEnabled = true` to `android/app/build.gradle.kts`'s `compileOptions` block and a `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` entry to its `dependencies` block. Rebuilt: succeeded (161s). This is the exact category of failure `flutter analyze`/`flutter test` structurally cannot catch (it's a native Android build-tool constraint, not a Dart-level issue) — direct evidence for why this module's APK build step was worth treating as load-bearing verification, not a formality.

## Step 7 — Wiring

`dashboard_header.dart`: the previously non-functional, `Opacity`-dimmed bell icon (`Icons.notifications_none_rounded`) is now a real `InkWell` with `onNotificationsTap`, key `dashboard_notifications_button` — no visual redesign, since the mockup (`dashboard 5.png`) already shows an undimmed bell in this exact spot.

`dashboard_screen.dart`: added a required `reminderController` field; `initState` now also calls `widget.reminderController.loadSettings()` (Step 4, decision 7) alongside the existing `controller.loadDashboard(...)` call; a new `_openReminderSettings` navigator method wired to the header's `onNotificationsTap`.

`main.dart`: `ReminderSettingsRepository?`/`ReminderNotificationService?` test-injection fields, a new `ChangeNotifierProvider<ReminderController>` (`SharedPrefsReminderSettingsRepository()`/`LocalReminderNotificationService()` defaults), `context.read<ReminderController>()` passed into `DashboardScreen`.

`AndroidManifest.xml`: added exactly one permission, `android.permission.POST_NOTIFICATIONS` (Android 13+ requirement for any local or push notification) — no `SCHEDULE_EXACT_ALARM`, no `RECEIVE_BOOT_COMPLETED` (Step 4, decisions 6-7 explain why neither is needed).

**Test-file threading:** `dashboard_screen_test.dart` (all 17 pre-existing `DashboardScreen(...)` sites + 1 new test for the bell-icon navigation) and `app_flow_test.dart` (`FakeReminderSettingsRepository()`/`FakeReminderNotificationService()` — same "inject a fake for every eagerly-constructible default" discipline as every prior module, here defensive rather than strictly required since `shared_preferences` already works in this app's test environment via `recent_email_store.dart`'s existing usage).

## Step 8 — Full verification (evidence, not claims)

| Check | Command | Result |
|---|---|---|
| Backend tests | `pytest -q` | Unaffected — **113/113** (this module is Flutter-only) |
| Flutter test suite | `flutter test` (mobile/) | **357 passed** (334 pre-Module-11 + 23 new: 5 schedule-calculator + 3 settings-repository + 8 controller + 6 screen + 1 dashboard-wiring), 0 failed |
| Static analysis | `flutter analyze` (mobile/) | **0 issues** |
| Debug APK build | `flutter build apk --debug` | **Succeeded** on the second attempt, after fixing the core-library-desugaring build failure described in Step 6 — `mobile/build/app/outputs/flutter-apk/app-debug.apk`. This is the first module to add native platform dependencies (three new packages, one new Android manifest permission, one new Gradle config block), so this build result is the real verification that the native/plugin wiring is correct — `flutter analyze`/`flutter test` alone could not have caught the desugaring requirement. |
| Physical-device manual verification | — | **NOT performed** — the user's manual step, per standing instruction. Notably more load-bearing for this module than any prior one: `flutter test` cannot exercise the real `flutter_local_notifications` plugin at all (every test uses `FakeReminderNotificationService`), so genuinely confirming a notification fires at the scheduled time, survives a real device restart/reboot, and requests/handles the OS permission dialog correctly requires an actual device pass — see Step 11 for exact manual steps to run. |

## Step 9 — Manual verification steps (for the user's device pass)

1. Install the debug APK on a physical Android device (API 26+, matching this project's `minSdk`).
2. Log in, reach the Dashboard, tap the bell icon (top-right of the greeting header) → should open "Reminders."
3. Toggle "Craving Check-In Reminders" on → the OS should show a notification-permission prompt (Android 13+) or, on older Android versions, no prompt (permission is granted by default pre-13) — confirm the toggle turns on and a frequency selector (3/4/5) appears.
4. Pick a frequency, e.g. 4 — no visible confirmation is expected beyond the selection highlighting; the real effect is an OS-level schedule, not observable in-app.
5. To confirm real scheduling without waiting hours: temporarily note the device's current time, and (developer-only sanity check, not required for FR14 itself) verify no crash/error occurs and the app remains responsive after toggling — the actual fire time can be confirmed by leaving the app installed and checking the notification tray at one of the computed times (roughly evenly spaced between 09:00 and 21:00 device-local time; for frequency 4 that's approximately 10:30, 13:30, 16:30, 19:30).
6. Force-close and reopen the app (simulates part of "app restart") → reaching the Dashboard again should silently re-sync the schedule (no visible UI change if settings didn't change — this step is really confirming no crash/regression, since the actual OS-level persistence is what's being relied on).
7. Toggle reminders off → confirm no further notifications appear at the previously-scheduled times.
8. Deny the notification permission (Android 13+: via device Settings → Apps → Quit Companion → Notifications → off, then retry the in-app toggle) → confirm the app shows the inline error text and the toggle does not turn on.

## Step 10 — Original FCM integration proposal (historical, 2026-08-19)

If a future decision reverses course and wants real push notifications (e.g., server-triggered reminders, or the cross-cutting badge/restart-plan pushes SDD §2.1 also assigns to this module — *"badge congratulatory pushes from Gamification, restart-plan follow-up pushes from Relapse Prevention & Reflection"*, neither of which is built by this module either, see Step 9 of the Module 8 and Module 5 records for their own explicit FCM exclusions):

1. Add the `firebase_messaging` package and complete its platform setup (Firebase Console messaging config, `google-services.json` already exists in this repo for other Firebase features).
2. Write `FcmReminderNotificationService implements ReminderNotificationService` — `requestPermission()` would call `FirebaseMessaging.instance.requestPermission()` instead of the local plugin's; `scheduleDailyReminders(times)` would instead need to either (a) call a new backend endpoint that schedules server-side sends at those times per-user (requiring the "unnecessary backend infrastructure" this session explicitly declined to build), or (b) keep scheduling client-side but swap the *delivery* of each notification's payload to route through FCM's data-message channel instead of the local plugin — a genuinely different architecture, not a drop-in.
3. **Nothing in `ReminderController`, `ReminderSettingsScreen`, or `ReminderSettings` would need to change** — they depend only on the `ReminderNotificationService` interface. This is the concrete payoff of Step 4, decision 2's modularity requirement.
4. `ReminderSettingsRepository` would likely need to become Firestore-backed at that point (Step 4, decision 5's reasoning flips once notifications are server-triggered rather than device-scheduled — a synced setting *would* then correctly affect delivery regardless of which device is active).

## Step 11 — What was explicitly NOT done in the 2026-08-19 baseline

- **No FCM push notifications** — explicit, deliberate scope exclusion per this session's direction, documented throughout this record, not a gap discovered after the fact.
- **No boot-time rescheduling** (`RECEIVE_BOOT_COMPLETED`) — the schedule only re-syncs when the Dashboard is next opened after a restart, not immediately on device boot. If the OS clears the local-notification schedule on reboot (behavior varies by Android version/OEM) and the user doesn't reopen the app for a while, reminders could silently lag until the next app open. Accepted trade-off (Step 4, decision 7), not hidden.
- **No badge-earned or restart-plan-follow-up push notifications** — SDD §2.1 also assigns these "cross-cutting triggers" to this module, but both Module 8 (Gamification) and Module 5 (Relapse Prevention & Reflection) already independently and explicitly excluded FCM/push from their own implementations; this module doesn't add them either, for the same no-FCM reason.
- **No user-editable individual reminder clock times** — only a 3/4/5 frequency choice within the fixed 09:00-21:00 window (Step 4, decision 3).
- **Physical-device verification** — Step 9's manual steps are written but not run by the agent, per standing instruction; this module in particular cannot be considered fully proven without that pass, since `flutter test` never touches the real plugin.

## Step 12 — FCM client receive/token revision (2026-11-16)

- Added `firebase_messaging` to the mobile app without changing app composition, auth/profile, HealthBot, or tracking/analytics code.
- The existing reminder permission flow requests local-notification and FCM permission. For a signed-in user, the device token is written or refreshed at `nicotineUsers/{uid}/fcmTokens/{tokenId}`; disabling reminders removes the current registered token. Firestore rules deny client reads and scope token writes/deletes to the authenticated owner. Deploy the rules before expecting Firestore registration/removal to succeed.
- Foreground notification payloads are displayed with `flutter_local_notifications`. In the background, notification payloads are handled by the OS; data-only messages are intentionally ignored by the app.
- Local daily schedules remain on-device and unchanged. FCM receipt is not a scheduled sender: this repository does **not** create/send messages, schedule server-side reminders, add badge/restart-plan push triggers, or provision credentials/accounts. A trusted Firebase Admin SDK sender/scheduler must be built and configured separately.
- Remaining setup: enable/configure FCM for the Firebase app, configure Android/iOS platform credentials and APNs as applicable, and deploy Firestore rules. See `mobile/README.md` → **FCM receive support** for the concrete checklist.
- Physical-device verification is still outstanding; focused Flutter token-lifecycle tests cover signed-in registration, refresh, removal, and signed-out behavior.

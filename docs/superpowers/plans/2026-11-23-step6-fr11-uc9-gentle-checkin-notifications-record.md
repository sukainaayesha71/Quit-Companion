# Step 6 — FR11 / UC9 Gentle check-in notifications: implementation record (2026-11-23)

## Requirement and prior state

SRDS UC9's alternative flow: "AI detects high-risk behaviour patterns → gentle check-in prompt". The Module 5 plan (2026-08-15) left it unbuilt because "no such detection logic is specified anywhere" and push infrastructure didn't exist yet. Since then:
- **Module 11** added local reminders (`flutter_local_notifications`). The project decision is that check-ins stay on-device and FCM is reserved for account/recovery events (`badge_earned`, `restart_plan`, `alternative_feedback`).
- **The backend worker** sends FCM scheduled/event notifications and re-scores offline (pending) craving logs.

There was no check-in for high-risk patterns anywhere, mobile or backend.

## Detection rule — reused, not invented

- **High risk** = the existing FR5 prediction stored on each craving log (`relapseRiskScore == high`). Logs with `riskAssessmentPending` (saved offline, placeholder score) never count.
- **Pattern** = WeeklyPlanCalculator's existing rule: **≥ 2 high-risk cravings in the last 7 days** (`weekly_plan_calculator.dart`, "A few intense cravings this week").
- **Evaluated** right after a craving is saved (`CravingLogController`), using the saved log plus the 7-day craving history.

## Scheduling rules (`HighRiskCheckInPolicy`, pure)

1. The new log is high risk and not pending; otherwise skip.
2. The pattern rule is met; otherwise skip.
3. **Relapse exclusion:** skip if a relapse was logged today or yesterday (`lastRelapseDate`, set by Relapse Log). Logging a relapse also **cancels** any pending check-in (`RelapseController` → `onRelapseLogged`).
4. **Settings:** skip unless the existing "Daily reminders" switch (`ReminderSettings.enabled`) is on. The check-in uses the same "Craving Check-In Reminders" channel.
5. **Permission:** skip unless notifications are already allowed. `hasPermission()` only checks — it **never shows a permission prompt**.
6. **Duplicates:**
   - The same triggering log is never re-notified.
   - At most one check-in per 24 h.
   - State is persisted per account in SharedPreferences, so it survives restarts.
   - A fixed notification id (200) means a new schedule replaces rather than stacks.
7. **Timing:** 2 h after the craving (the moment itself is already handled by the HighRiskScreen alternatives). If that lands between 22:00 and 09:00, it moves to 09:00.

## Wording

- Title: **"Checking in on you"**
- Body: **"Some cravings lately have felt strong. How are you doing right now? Logging how you feel or trying a short calming activity can help."**

A test asserts no judgmental or alarming words (relapse, fail, slip, warning, danger, "you should", "don't", risk).

## Preserving existing behaviour

- Daily reminders keep ids 0–4/100/101. `cancelLocalReminders()` (run on every Dashboard re-sync) does **not** touch id 200, so a pending check-in survives re-syncs (tested).
- Turning daily reminders off cancels a pending check-in. Logout and account deletion (`cancelAllReminders`) clear it too.
- FCM, the backend worker and the event notifications are unchanged; no backend code changed in this step.
- The app now provides one shared `ReminderSettingsRepository` / `ReminderNotificationService` / `HighRiskCheckInScheduler` through **lazy** `Provider`s, read by `ReminderController`, `CravingLogController` and `RelapseController` (previously `ReminderController` created its own inline). A first attempt created them eagerly in `build()`. That touched `FirebaseMessaging` before Firebase was needed, broke two `auth_navigation_test` cases and would have re-created the service on every rebuild. It was caught by the full suite and fixed before reporting.

## Files

- New:
  - `mobile/lib/features/reminders/domain/high_risk_checkin_policy.dart`
  - `mobile/lib/features/reminders/data/check_in_state_store.dart`
  - `mobile/lib/features/reminders/data/high_risk_checkin_scheduler.dart`
- Modified:
  - `reminder_notification_service.dart` (+`hasPermission`, `scheduleOneOffNotification`, `cancelNotification`)
  - `local_reminder_notification_service.dart` (implementations; `cancelAllReminders` also cancels id 200)
  - `fake_reminder_notification_service.dart`
  - `reminder_controller.dart` (disable cancels the check-in)
  - `craving_log_controller.dart` (background evaluation after save)
  - `relapse_controller.dart` (cancel on relapse)
  - `app/quit_companion_app.dart` (wiring)
- Tests: `mobile/test/features/reminders/high_risk_checkin_test.dart` (26).

## Known limits

- **Offline cravings:** a craving saved offline is scored later by the backend worker. That late "high" score does not trigger a check-in, because the evaluation runs only on-device at save time.
- **Local-only state:** the cooldown and check-in state live on this device only.
- **Opt-in by default:** check-ins require Daily reminders to be on, which is **off by default**, so users who never enable reminders get none. This was chosen to respect existing settings.
- **Self-reported nicotine use:** `nicotineUsedSinceLastCheckin` on a craving log is not treated as a confirmed relapse. Only Relapse Log is.

## Manual Android checks

1. Enable Daily reminders (grant permission). Log two cravings that score **High** within a week. Then, in a shell, `adb shell dumpsys alarm | grep -i quit` should show a pending alarm. The notification should appear about 2 h later (or at 09:00 if late evening).
2. Log a third high-risk craving soon after: no second notification is scheduled.
3. Before it fires, log a relapse: the pending check-in disappears and no notification arrives.
4. Turn Daily reminders off, or revoke notification permission in system settings, then repeat step 1: no notification and no permission prompt.
5. Read the notification text on the device for tone.

# Step 8 — UC3 Offline craving synchronization: implementation record (2026-11-23)

## What already existed (kept, no new storage)

`OfflineCravingLogRepository` (production craving repository, wrapping `FirestoreCravingLogRepository`):
- **Encrypted, per-account outbox and cache** in `flutter_secure_storage` (`craving.outbox.<uid>`, `craving.cache.<uid>`). Every save goes there first, then is sent.
- **Sync triggers:** after each save, a 15 s retry timer while the app is in use, and on every read (the Dashboard reads on each app open, so reopening the app syncs).
- **Duplicate safety:** Firestore writes use `doc(logId).set(...)`, so a retried write overwrites the same document. An entry leaves the outbox only if it is unchanged since it was sent.
- **Data kept intact:** the codec carries the original timestamp and every field (mood sliders, notes, recovery context, `riskAssessmentPending`).
- **Offline deletion** is queued too. `clearUser` wipes an account's local data on deletion.
- **Pending risk assessments:** `CravingLogController` saves even when risk prediction fails, with `riskAssessmentPending = true`. The backend worker re-scores pending logs later.
- **Live updates:** the repository implements `LiveCravingLogRepository`, so the Dashboard refreshes on local changes.

## Gaps found and fixed

1. **One bad entry blocked the whole queue.** A corrupted or unreadable outbox entry threw on every pass and stopped all entries behind it. It is now skipped (kept, never deleted, logged) and the rest sync. A remote/network failure still stops the pass, because the remaining entries would fail the same way, and the outbox stays intact.
2. **Saves during a running sync waited 15 s.** `flush()` ignored calls while a flush was running. A request during a flush now triggers another pass in the same run.
3. **No signal after syncing.** A successful sync now emits on `watchChanges`, so listening screens (Dashboard) refresh.
4. **No sync status in the UI.** Added the `SyncStatusCravingLogRepository.pendingSyncLogIds()` interface, implemented by the offline repository by reading the existing outbox. `TrackController` exposes `pendingSyncLogIds`, and **Craving History** shows "Saved on this device · waiting to sync" (cloud icon) on unsynced entries. The mark disappears after sync on the next refresh (pull to refresh or reopen). The Log Craving result already says "Craving Saved — Your entry is saved. The risk assessment will update when the service is reachable." when offline.

## Files

- Modified:
  - `mobile/lib/features/craving/data/craving_log_repository.dart` (+`SyncStatusCravingLogRepository`)
  - `mobile/lib/features/craving/data/offline_craving_log_repository.dart` (flush rewrite: per-pass loop, skip unreadable entries, re-run, change event; `pendingSyncLogIds`)
  - `mobile/lib/features/tracking/controllers/track_controller.dart` (`pendingSyncLogIds`)
  - `mobile/lib/features/craving/presentation/screens/craving_history_screen.dart` (waiting-to-sync marker)
- New test: `mobile/test/features/craving/data/offline_craving_sync_test.dart` (10)
- Also corrected the Step 3 record: it wrongly said no repository implements `LiveCravingLogRepository`.

## Tests (automated, no device)

- Offline save: kept locally, readable, marked pending, nothing sent.
- Reconnect: syncs with the identical encoded record (timestamp to the second, notes, sliders), pending cleared, change event emitted.
- App reopen: a new repository instance reads the stored outbox and syncs both entries on first read.
- Duplicates: write applied but acknowledgement lost → entry stays queued → three concurrent flushes plus one more → exactly one server document, nothing pending, one local copy.
- Failure: repeated failed flushes keep the outbox; a later retry syncs.
- Unreadable entry kept but doesn't block a valid one.
- Save during an in-progress sync is sent in the same run.
- Per-account scoping of pending ids.
- End to end: `CravingLogController` with prediction down and server down → success, assessment pending, queued.
- Craving History shows the marker before sync and not after.

The test "server" stores documents by id, matching Firestore `set()` semantics; Firestore itself isn't exercised by unit tests.

## Not verified / limits

- **No airplane-mode test on a physical device was performed in this session.**
- Craving History doesn't auto-refresh when a sync completes in the background. It updates on pull to refresh or reopen (the Dashboard does refresh live).
- Firestore's own offline cache may also queue the same write. Because both use the same document id, the server ends up with one document.
- An unreadable entry stays in the outbox, and is visible as "waiting to sync" if it has an id, until the account's local data is cleared. It can't be repaired automatically.

## Manual Android checks

1. Turn on airplane mode, then log a craving. Expected: the result shows "Craving Saved", and the entry appears on the Dashboard and in Craving History with "waiting to sync".
2. Force-close the app while still offline, reopen it, and confirm the entry is still there.
3. Turn airplane mode off. Within about 15 s (or on the next Dashboard open), pull to refresh in Craving History: the marker is gone. In the Firebase console, `nicotineUsers/<uid>/cravingLogs/<logId>` exists once, with the original timestamp.
4. Repeat with two quick offline entries, then reconnect: both sync, with no duplicates.
5. With the backend worker running, the "assessment pending" entry later shows a real risk level.

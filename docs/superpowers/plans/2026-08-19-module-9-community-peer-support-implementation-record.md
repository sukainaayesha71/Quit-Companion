# Module 9 — Community & Peer Support — Implementation Record

**Status: IMPLEMENTED AND VERIFIED (2026-08-19).** Same inline-decisions style as Modules 7-8 — no separate plan document preceded this one.

This module belongs to **Mehreen Ali's** module list (SDD §2.1, "Community & Peer Support", FR11).

---

## Step 1 — Why this module is required (SDD traceability)

FR11 (SDD §3): "Community forum posting/reply — unchanged" (= SRDS FR10). SRDS §3.2.9 (UC8, "Post in Community Forum") gives the full behavior: navigate to Community, see the public feed, tap "New Post," type a message, optionally pick a category (Milestone, Tip, Question, Motivation), post; the post saves with a timestamp and an anonymized username; other users can like/support or reply; content flagged by a filter is blocked with a notification to the user.

**Approved UI mockup used directly**: `docs/UI_Design/community 10.png` — header illustration, "Community" title + search icon, filter chips (All/Tips/Milestones/Questions/Motivation), post cards (avatar, anonymized username, category pill, relative timestamp, content, like count, Reply link), floating "+" New Post button.

## Step 2 — Requirements satisfied

FR11 in full: public feed (filterable by category), posting with a generated anonymized identity, likes, replies, and a deterministic content filter blocking flagged posts.

## Step 3 — Dependencies on already-built modules

| Need | Reused from |
|---|---|
| Per-user Firestore repository/Fake pattern (adapted) | Every prior module |
| "Community" Quick Access tile (index 4) + bottom-nav item, already scaffolded and disabled | Module 2's `quick_access_grid.dart` / `dashboard_bottom_nav.dart` |
| "No mockup for compose/detail screens — build plain" precedent | Modules 4, 5, 7 |
| Deterministic-keyword-list precedent for the content filter | FR5's rule table, FR7's matcher, FR8's knowledge base |

**Modules 1-8 stayed frozen** — only the same additive Dashboard-wiring touch every prior module made.

## Step 4 — Design decisions made inline

1. **First cross-user, top-level Firestore collection in this app.** Every prior entity lived under `nicotineUsers/{userId}/...` — strictly private per-user data. SRDS UC8 explicitly requires posts "visible to all registered users." **Decision:** a new top-level `communityPosts/{postId}` collection, with `likes/{userId}` and `replies/{replyId}` subcollections per post — the one deliberate exception to this app's private-per-user pattern, documented as such in both `CommunityPostRepository`'s doc comment and `firestore.rules`.
2. **Anonymized username: deterministic, not random, and not a stored profile.** Neither the SDD nor SRDS defines a community-profile entity to read a handle from. A purely random handle per post would break the approved mockup, which shows the *same* username across multiple posts from the same person. **Decision:** `generateAnonymizedUsername(userId)` deterministically derives a stable pseudonym from a simple string hash of the real `userId` (never stored or exposed itself) — same user, same handle, every time, with no new profile entity needed.
3. **Content filter: fixed keyword list, not ML moderation.** SRDS UC8's alternative flow requires blocking flagged content. Consistent with every "AI" feature in this codebase (deterministic, not a trained model), `isContentAllowed()` checks a small, explicitly-flagged-as-incomplete banned-term list — documented as a real scope limitation (not comprehensive profanity coverage), not presented as production moderation.
4. **`likeCount` is derived, never a client-trusted counter.** Storing a mutable `likeCount` field on the post document that any user could write to would be a real security hole (anyone could set it to anything). **Decision:** likes are individual `likes/{userId}` documents (existence = liked); the count is always computed by reading the subcollection, and Firestore rules only allow a user to create/delete *their own* like document.
5. **"Real-time" feed is scoped to reload-on-action, not a live stream.** SRDS UC8 says posts appear "in real time." No other screen in this codebase uses a live Firestore snapshot listener — every existing controller does one-shot `Future`-based loads (`JournalController`, `HealthBotController`, etc.). **Decision:** kept that same architecture; the feed reloads after the current user creates a post or changes the filter, but does not live-stream other users' posts arriving in the background — a documented, deliberate scope limitation, not an oversight.
6. **Replies are flat, not nested threads.** SRDS just says "reply to the post," with no threading depth specified or shown in the mockup. Implemented as a single flat list per post (`CommunityReply`, no parent-reply field), reachable via a dedicated `PostRepliesScreen` — reply-to-a-reply is not built.

## Step 5 — Folder/file plan

New: `lib/models/post_category.dart`, `community_post.dart`, `community_reply.dart`; `lib/domain/anonymized_username_generator.dart`, `content_filter.dart`, `relative_time_formatter.dart`; `lib/data/community_post_repository.dart` (+fake/firestore); `lib/controllers/community_controller.dart`; `lib/screens/community/community_screen.dart`, `new_post_screen.dart`, `post_replies_screen.dart`. Modified: `quick_access_grid.dart`, `dashboard_bottom_nav.dart` (generalized `_navTile` to optionally accept a key/`onTap`, since Community is the first bottom-nav item beyond Home/Health-Bot to become real), `dashboard_screen.dart`, `main.dart`, `firestore.rules`.

## Step 6 — TDD narrative, layer by layer

**Domain helpers** — `anonymized_username_generator_test.dart` (4 cases: deterministic, different users usually differ, never leaks the raw userId, matches the `Word_NN` format), `content_filter_test.dart` (4 cases: allows normal text, blocks a banned term case-insensitively and regardless of punctuation, blank content is rejected), `relative_time_formatter_test.dart` (5 cases: "Just now," minutes, hours — matching the mockup's literal "2h ago" — days, and a fallback to a short date beyond a week). All three GREEN on first implementation attempt — **13/13 passed**, no logic bugs at this layer.

**Repository** — `fake_community_post_repository_test.dart` (6 cases: newest-first ordering, category filtering, like/unlike affecting both `hasLiked` and the computed count, reply ordering, a simulated failure). GREEN on first attempt — **6/6 passed**.

**Controller** — `community_controller_test.dart` (6 cases: `loadFeed` populates posts and the current user's liked-set; `setFilter` reloads scoped to a category; `createPost` with clean content saves under a generated handle and reloads the feed; `createPost` with blocked content is rejected with an error, nothing saved; `toggleLike` flips state and the local like count both ways; `loadReplies`/`addReply` round-trip). GREEN on first attempt — **6/6 passed**.

**Screens** — `new_post_screen_test.dart` (4 cases) and `post_replies_screen_test.dart` (3 cases) both passed on the first attempt (7/7). `community_screen_test.dart` (6 cases: layout/content rendering, empty state, filter-chip narrowing, like toggling, opening `NewPostScreen`, opening `PostRepliesScreen`) surfaced **one real bug**: the first test run failed with `Found 0 widgets with text "2h ago"` — `_PostCard` was calling `formatRelativeTime(post.timestamp, now: DateTime.now())` directly instead of using the controller's injected `now()` clock, so the test's fixed `fixedNow` had no effect on what the widget actually rendered (the real wall-clock time made "2h ago" never match). **Root cause diagnosed, fixed**: both `community_screen.dart` and `post_replies_screen.dart` were changed to thread `controller.now()` through to every `formatRelativeTime` call instead of reading the system clock directly — the same "inject the clock, never call `DateTime.now()` inside a widget" discipline every other controller/screen pair in this codebase already follows, which this one had briefly missed. Re-ran: **6/6 passed**.

## Step 7 — Wiring

`quick_access_grid.dart`: added `onCommunityTap`; tile index 4 ("Community") enabled, unconditionally (no phase gate — peer support is relevant in both phases).

`dashboard_bottom_nav.dart`: generalized `_navTile` to optionally take a `Key`/`onTap` (previously every non-Home/non-Health-Bot tile was purely decorative `Opacity`, with no tap handling at all) — the "Community" bottom-nav item is now the second real destination in that bar besides Home and the center Health-Bot button.

`dashboard_screen.dart` / `main.dart`: identical pattern to every prior module — `communityController` field, `_openCommunity` navigator method, a `ChangeNotifierProvider<CommunityController>` in `main.dart` (`FirestoreCommunityPostRepository()` default).

**Test-file threading:** `dashboard_screen_test.dart` (all 14 pre-existing `DashboardScreen(...)` sites + 2 new tests for both Community entry points) and `app_flow_test.dart` (`FakeCommunityPostRepository()` — same eager-Firestore-construction reason as every prior module's Fake-injection fix).

`firestore.rules`: added the new top-level `communityPosts` block with `likes`/`replies` subcollections (see Step 4, decision 1/4 for the access-model reasoning) — the first rules block in this file that is NOT nested under `nicotineUsers/{userId}`.

## Step 8 — Full verification (evidence, not claims)

| Check | Command | Result |
|---|---|---|
| Backend tests | (unaffected — Flutter-only module) | Still 113/113 |
| Flutter test suite | `flutter test` (mobile/) | **317 passed** (277 pre-Module-9 + 40 new: 13 domain + 6 repository + 6 controller + 13 screens + 2 dashboard-wiring), 0 failed |
| Static analysis | `flutter analyze` (mobile/) | **0 issues** |
| Debug APK build | `flutter build apk --debug` | Run at the end of this step — see the chat summary for the final result |
| Physical-device manual verification | — | **NOT performed** — user's manual step |
| Firestore rules deployment | — | New top-level `communityPosts` rule block added to source; **not deployed** |

## Step 9 — What is still explicitly NOT done

- **No live/real-time multi-user feed updates** — the feed reloads on the current user's own actions (post, filter change) only, not via a Firestore snapshot listener picking up other users' posts as they arrive (Step 4, decision 5).
- **No nested reply threads** — replies are a flat list per post, not reply-to-a-reply (Step 4, decision 6).
- **No "support" reaction distinct from "like"** — SRDS mentions "like, support" as two reaction types; only a single toggleable like was built.
- **Content filter is a small, explicitly incomplete keyword list**, not production-grade moderation (Step 4, decision 3).
- **No post/reply edit or delete** — Firestore rules only grant `create` (and `read`) on posts/replies; no update/delete path exists in the repository interface or rules.
- **Physical-device verification and Firestore rules deployment** — as above.

# Module 10 — Knowledge Hub & Education — Implementation Record

**Status: IMPLEMENTED AND VERIFIED (2026-08-19).** Same inline-decisions style as Modules 7-9 — no separate plan document preceded this one.

This module belongs to **Mehreen Ali's** module list (SDD §2.1, "Knowledge Hub & Education", FR13) — her **last** module; only the shared Notification & Reminder (FR14) module remains after this one across the entire 11-module SDD scope.

---

## Step 1 — Why this module is required (SDD traceability)

FR13 (SDD §3): "Knowledge Hub educational content — unchanged" (= SRDS FR12). SRDS Module 9's description is the operative spec: *"Provides a curated library of educational content about the health effects of nicotine, the science of addiction, and the documented health benefits of quitting at various milestones. Content includes articles, short informational videos, and verified health facts sourced from WHO, CDC, and peer-reviewed medical research. The content is organized by topic and displayed in a clean, easy-to-browse format."*

**Approved UI mockup used directly**: `docs/UI_Design/knowledge hub 14.png` — "Knowledge Hub" title + search icon, a book-stack illustration, filter chips (All/Withdrawal/Health Benefits/Science of Addiction), and a 2-column grid of 6 article cards (icon, title, "4 min read," one card showing a bookmark indicator).

**Note on a corrupted SRDS table row**: while researching this module, the SRDS's raw shall-statement table (around line 403) had a row labeled "Knowledge Hub & Education" whose text was actually a verbatim description of Health-Bot behavior (disclaimer, "shall not suggest medications," etc.) — an evident copy/paste or table-extraction error in the source document, not a real requirement for this module. The SDD's own FR13 restatement and the SRDS's separate Module 9 prose description (both quoted above) were used instead, since they're internally consistent and match the approved mockup; the garbled table row was not treated as authoritative.

## Step 2 — Requirements satisfied

FR13's article-content half: a fixed, categorized library of educational articles, browsable/filterable by topic, with per-article bookmarking (implied by the mockup's bookmark icon, not separately specified in either document).

## Step 3 — Dependencies on already-built modules

| Need | Reused from |
|---|---|
| "Fixed content library, no live advisor" precedent | FR7's `habitAlternativeLibrary` (Module 7), FR8's knowledge base (Module 6) |
| Existence-as-boolean subcollection pattern for a per-user toggle | Module 9's `likes/{userId}` subcollection |
| "No mockup for compose/detail screens — build plain" precedent | Modules 4, 5, 7, 9 |
| "Knowledge Hub" Quick Access tile (index 7), already scaffolded and disabled | Module 2's `quick_access_grid.dart` |

**Modules 1-9 stayed frozen** — only the same additive Dashboard-wiring touch every prior module made.

## Step 4 — Design decisions made inline

1. **"Videos" are explicitly out of scope.** SRDS names "short informational videos" as part of the content mix. This repo has no video-playback dependency (`video_player` or equivalent), no video asset files, and — consistent with every prior module's finding — no image/video assets exist anywhere in the project at all. **Decision:** build the article/text-content half only; videos are a real, acknowledged gap, not silently dropped (see Step 9).
2. **No entity is defined for article content anywhere in the SDD/SRDS** (unlike `HabitAlternative`, which at least has a class-diagram entry). **Decision:** `KnowledgeArticle` is a new, purely presentational model with no inherited shape — mirrors Module 7's `HabitAlternative` precedent for "a fixed library the SDD names conceptually but never schemas."
3. **Category assignment for each article title was inferred, not given.** The mockup shows 6 titles and 3 category filter chips but doesn't label which article belongs to which category. **Decision:** assigned by the article's actual subject matter — "Why Do I Feel Anxious?" → Withdrawal; "Lungs at Day 3" / "Health Benefits" / "Your Heart at Day 7" → Health Benefits (all are recovery-milestone content); "Your Brain on Cravings" / "The Science of Addiction" → Science of Addiction. A reasoned, documented mapping, not arbitrary.
4. **Article body content is fixed, generic public-health information** — same posture as FR7/FR8's content: no specific named-study citations (none exist to cite honestly), no medication/dosage claims, phrased as general WHO/CDC-style public health information rather than claiming a specific clinical source this project cannot actually verify.
5. **Bookmarking is a new, undocumented-by-spec feature**, inferred entirely from the mockup's bookmark icon on one card. **Decision:** implemented as a private per-user `articleBookmarks/{articleId}` subcollection (existence = bookmarked) — the normal nicotineUsers/{userId}/... pattern, since bookmarks (unlike Module 9's posts) are never shared with other users.
6. **The article library itself needs no repository** — like Module 7's `habitAlternativeLibrary`, it's a compile-time Dart constant (`knowledgeArticleLibrary`), not fetched from Firestore. Only the per-user bookmark state needs persistence.

## Step 5 — Folder/file plan

New: `lib/models/knowledge_article.dart`; `lib/data/knowledge_article_library.dart`, `article_bookmark_repository.dart` (+fake/firestore); `lib/controllers/knowledge_hub_controller.dart`; `lib/screens/knowledge/knowledge_hub_screen.dart`, `article_detail_screen.dart`. Modified: `quick_access_grid.dart`, `dashboard_screen.dart`, `main.dart`, `firestore.rules`.

## Step 6 — TDD narrative, layer by layer

**Repository** — `fake_article_bookmark_repository_test.dart` (5 cases: empty for a new user, set/get round-trip, unset removes it, bookmarks scoped per user, a simulated failure). GREEN on first attempt — **5/5 passed**.

**Controller** — `knowledge_hub_controller_test.dart` (4 cases: `loadArticles` populates the full fixed library plus any prior bookmarks; `setFilter` narrows `filteredArticles` and `null` restores everything; `toggleBookmark` flips state and persists both directions; the loaded-status path). GREEN on first attempt — **4/4 passed**.

**Screens** — `article_detail_screen_test.dart` (3 cases: renders title/read-time/body, the bookmark button toggles, back navigation) passed on the first attempt (3/3). `knowledge_hub_screen_test.dart` (4 cases) surfaced **two real test-authoring issues, not implementation bugs**:
- First failure: `find.text('Health Benefits')` matched 2 widgets — the "Health Benefits" filter chip label and the article literally titled "Health Benefits" (verbatim from the approved mockup). Same category of collision Module 6's suggested-chip test and Module 10's own filter/article-title overlap hit — fixed by asserting `findsNWidgets(2)` with a comment explaining why two matches are correct, not one.
- Second failure: `find.text('Why Do I Feel Anxious?')` (a row-2 article) found nothing — the 2-column, 6-item grid is taller than Flutter's default 800×600 test surface, so `GridView.builder` never built the off-screen cards at all (not a scroll-visibility issue `ensureVisible` could fix, since the widgets weren't in the tree to find). **Fixed** by enlarging the test viewport (`tester.view.physicalSize`/`devicePixelRatio`, reset via `addTearDown`) to a taller size that fits the full library — a test-infrastructure fix, not a production code change; the real screen scrolls correctly on an actual device, this was purely a fixed-size test-surface artifact. Re-ran: **4/4 passed**.

## Step 7 — Wiring

`quick_access_grid.dart`: added `onKnowledgeHubTap`; tile index 7 ("Knowledge Hub") enabled, unconditionally (no phase gate — educational content is relevant regardless of phase). No bottom-nav entry point exists for this module (not present in the nav item list at all, unlike Health-Bot/Community).

`dashboard_screen.dart` / `main.dart`: identical pattern to every prior module — `knowledgeHubController` field, `_openKnowledgeHub` navigator method, a `ChangeNotifierProvider<KnowledgeHubController>` in `main.dart` (`FirestoreArticleBookmarkRepository()` default).

**Test-file threading:** `dashboard_screen_test.dart` (all 16 pre-existing `DashboardScreen(...)` sites + 1 new test for the Knowledge Hub tile) and `app_flow_test.dart` (`FakeArticleBookmarkRepository()` — same eager-Firestore-construction reason as every prior module's Fake-injection fix).

`firestore.rules`: added `articleBookmarks` as a normal private per-user subcollection block (not a top-level collection like Module 9's `communityPosts` — bookmarks are never shared).

## Step 8 — Full verification (evidence, not claims)

| Check | Command | Result |
|---|---|---|
| Backend tests | (unaffected — Flutter-only module) | Still 113/113 |
| Flutter test suite | `flutter test` (mobile/) | **334 passed** (317 pre-Module-10 + 17 new: 5 repository + 4 controller + 3 detail-screen + 4 hub-screen + 1 dashboard-wiring), 0 failed |
| Static analysis | `flutter analyze` (mobile/) | **0 issues** |
| Debug APK build | `flutter build apk --debug` | Run at the end of this step — see the chat summary for the final result |
| Physical-device manual verification | — | **NOT performed** — user's manual step |
| Firestore rules deployment | — | New `articleBookmarks` rule block added to source; **not deployed** |

## Step 9 — What is still explicitly NOT done

- **No video content** — SRDS names "short informational videos" as part of the content mix; this repo has no video-playback infrastructure or assets of any kind (Step 4, decision 1).
- **No "verified health facts" as a distinct content type separate from articles** — folded into article bodies rather than built as its own card type, since the mockup shows only one card style.
- **Category assignment is a reasoned inference, not a spec-given mapping** (Step 4, decision 3) — worth a real content-team review if this were shipped for real.
- **No search functionality** — the search icon in the header is decorative/non-functional, same precedent as Module 9's search icon.
- **Physical-device verification and Firestore rules deployment** — as above.

---

## Milestone note

This closes out **all five of Mehreen Ali's SDD-assigned modules** (Alternatives & Habit Replacement, Health-Bot, Gamification & Rewards, Community & Peer Support, Knowledge Hub & Education) alongside Sukaina's five, for **10 of the 11 total SDD modules complete**. Only the shared **Notification & Reminder (FR14)** module remains.

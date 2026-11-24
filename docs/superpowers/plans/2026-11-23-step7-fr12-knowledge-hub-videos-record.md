# Step 7 — FR12 Knowledge Hub educational videos: implementation record (2026-11-23)

## Prior state

- Knowledge Hub had 16 bundled articles in 5 categories, a category filter, "Saved Articles" and Firestore bookmarks.
- There were **no videos** anywhere. The Module 10 record says "No video content built (no video infra in repo)".

## Approach

- **External links only**: no player plugin and no downloads. YouTube links open the YouTube app when installed, otherwise the browser. CDC page links open the browser on CDC's own video player. This reuses `url_launcher` (Step 4) and the existing Android `<queries>` for https.
- Knowledge Hub gets an **Articles / Videos** switch. Articles is the default, and its grid, filters, Saved Articles and bookmarks are unchanged. Videos lists entries grouped under the four required topics.
- Videos are **not bookmarkable**, to keep the existing Firestore bookmark data and rules untouched.

## Verified video list (2026-11-23)

All entries are from the CDC (U.S. Centers for Disease Control and Prevention). For YouTube entries:
- the id was copied from the CDC page that embeds or links it, never constructed;
- YouTube's oEmbed API returned the exact title, and the author "Centers for Disease Control and Prevention (CDC)".

| Topic | Title | Link | Verified via |
| --- | --- | --- | --- |
| Health benefits | Benefits of Quitting Over Time | cdc.gov/tobacco/about/benefits-of-quitting.html | Page HTTP 200; hosts CDC's animated benefits video (cdc-osh-cessation-over-time.mp4) |
| Health benefits | Tiffany R.: Surprising Things About Quitting | youtube `QmVEbwVA_ck` | CDC Tiffany story page + oEmbed |
| Health benefits | Tiffany R.: You Don't Quit Just for Yourself | youtube `kyLhO4vGcGY` | CDC Tiffany story page + oEmbed |
| Cravings & withdrawal | Tips From Former Smokers: Cessation Tips | youtube `d6iS44aHy4s` | CDC "Tips For Quitting" page (under "Distract yourself") + oEmbed |
| Cravings & withdrawal | Tiffany R.: How I Quit Smoking | youtube `6OZehKDHsj0` | CDC Tiffany story page + oEmbed |
| Relapse prevention | James F.: "No, I Won't Buy You Smokes" | youtube `_MlDuDWLo0U` | CDC "Tips For Quitting" page + oEmbed |
| Relapse prevention | John B.: Don't Quit Quitting | cdc.gov/tobacco/campaign/tips/stories/john-b.html#john-videos | Story page fetched; hosts the video in CDC's player |
| Coping | Beatrice R.: "I Told Everyone I Stopped Smoking" | youtube `PVuRNZP5igo` | CDC "Tips For Quitting" page + oEmbed |
| Coping | Tiffany R.'s Decision | youtube `26_rxunCRXU` | CDC Tiffany story page + oEmbed |

**Descriptions** only restate the official title or CDC page caption. Most videos are former-smoker testimonials (the CDC Tips campaign), not clinical instruction, and the descriptions say so rather than overstating them.

**Not included:**
- **WHO videos.** WHO's "How to quit tobacco smoking" page and the 2019 World No Tobacco Day video page exposed no video URL, and the WHO EMRO video page returned HTTP 502. No WHO link could be verified, so none was added rather than guessing.
- **Direct CDC .mp4 files.** CDC blocked command-line requests from this network (HTTP 403 even for HTML pages that load in a browser), so the raw file URLs couldn't be confirmed. The hosting pages are linked instead.

## Files

- New:
  - `mobile/lib/features/knowledge/models/knowledge_video.dart`
  - `mobile/lib/features/knowledge/data/knowledge_video_library.dart`
  - Test: `mobile/test/features/knowledge/presentation/knowledge_videos_test.dart` (9)
- Modified:
  - `knowledge_hub_controller.dart` (`videos`, `videosByTopic`)
  - `knowledge_hub_screen.dart` (Articles/Videos switch, video list and cards, `openUrl` injection, error snackbar)

## Manual Android checks

1. Knowledge Hub opens on Articles, as before. Filters, Saved Articles, bookmarks and article detail all work.
2. Tap **Videos**: four topic headings and 9 cards are shown.
3. Tap a YouTube card: the YouTube app (or browser) plays the CDC video. Tap "Benefits of Quitting Over Time" or "John B.": the CDC page opens in the browser with its player.
4. Airplane mode: tapping a card shows the "Could not open the video" message or the browser's offline page. The app doesn't crash.
5. Re-check that all 9 links still play before submission (CDC occasionally reorganizes pages).

# Step 10 — FR10 Community post validation: implementation record (2026-11-23)

## Prior state

- **Client checks:** `CommunityController.createPost` / `addReply` ran only the deterministic content filter (`isContentAllowed`, which also rejected blank text), then trimmed and redacted contact details.
  - The reply screen ignored blank input silently.
  - The new-post screen required a category but had no content message and no length limit.
- **Firestore rules:** `communityPosts` create and `replies` create checked only `auth != null` and `userId == auth.uid`. There were no field or length checks.
- **Requirements:** no maximum length is defined in the SRDS-derived docs or the code (the SRDS PDF isn't in the repo).
  - **Decision (project owner, 2026-11-23): 2000 characters**, matching the existing Health-Bot input limit (`backend/app/healthbot/router.py`, `max_length=2000`).
  - This is documented as a technical safety cap, not an SRDS figure.

## Changes

### App
- New `lib/features/community/domain/community_post_validator.dart`, shared by the screens and the controller:
  - **empty:** blank after trimming, or containing only zero-width/invisible characters;
  - **tooLong:** more than 2000 characters after trimming, counted in UTF-16 units, which are never fewer than the rules' character count;
  - **invalidCharacters:** control characters other than tab/newline/CR, or broken (unpaired) surrogates.
  - Specific messages, e.g. "Write something before posting.", "Your post is too long — the limit is 2000 characters (currently 2050).", "…contains characters that can't be shared…".
- `CommunityController`:
  - Validates first, then runs the existing content filter.
  - Rejects an empty `userId`, and an empty `postId` for replies.
  - **Re-validates the exact stored text after contact-detail redaction**, because `[email removed]` can push a post over the limit, which the rules would then reject.
- `NewPostScreen`: an inline `errorText` on the content field, plus a `0/2000` counter with `MaxLengthEnforcement.none`, so typed or pasted text is never silently truncated. Content and category errors can show together, and the error clears on edit.
- `PostRepliesScreen`: an inline error instead of silently ignoring a blank reply, and a counter that appears only above 1800 characters.

### Firestore rules (`mobile/firestore.rules`) — strengthened, never weakened
- **`communityPosts` create:**
  - the existing auth and owner checks;
  - **exactly** the fields the app writes (`userId`, `anonymizedUsername`, `content`, `category`, `timestamp`; `hasOnly` + `hasAll`);
  - content is a string of 1–2000 characters containing at least one visible character (not whitespace or zero-width);
  - category in milestone/tip/question/motivation;
  - `anonymizedUsername` a string of 1–60 characters;
  - `timestamp` a string of 10–40 characters.
- **`replies` create:** the same, without category.
- **Unchanged:** read rules, the likes subcollection (own uid only), default-deny, and no client update or delete. Rules apply to writes only, so **existing posts and replies are never re-validated** and stay readable. A test seeds a 2500-character legacy post with an extra field and confirms it can still be read.
- No new collections; same data shape. Deletion still goes through the backend Admin SDK.

## Tests

- **Dart** — `test/features/community/community_validation_test.dart` (17):
  - validator: valid text and emoji, empty/whitespace/invisible, the 2000 vs 2001 boundary, control characters and surrogates, messages;
  - controller: valid save trimmed; 2000 accepted, 2001 rejected and not saved; empty/whitespace/invalid rejected; missing user; content filter preserved; redaction pushing 1992 to 2001 is caught;
  - replies validated; valid reply and likes still work;
  - screens: whitespace message; over-long message with counter, not truncated, not posted; combined errors; valid post returns to the feed; reply blank message, counter near the limit, valid reply sends.
- **Firestore rules** — `test/firestore_rules/rules.test.mjs` (13), run on the **local emulator** (`demo-quit-companion`):
  - valid post; 2000 allowed / 2001 rejected; empty / whitespace / zero-width rejected; missing fields; malformed types, unknown category, extra field (`likeCount`); ownership and unauthenticated create still denied;
  - legacy posts readable; likes own-uid only; no client update/delete;
  - valid reply; invalid or impersonating replies rejected.
- **Results:** community Dart tests 50/50 (33 existing + 17 new), rules tests 13/13.

## Manual checks

1. **Deploy the rules** (not done here; it changes the live project): `firebase deploy --only firestore:rules --project quit-companion` from `mobile/`. Then check the Rules tab in the Firebase console.
2. On a device:
   - post normal text, then a post with emoji;
   - try a blank post, a post of only spaces, and pasting a 2001+ character text: an inline message appears and nothing is posted;
   - reply blank (message) and reply normally;
   - like and unlike;
   - confirm older posts still show.
3. Optional: try a direct Firestore write without a category from the Firebase console's Rules Playground. It should be denied.

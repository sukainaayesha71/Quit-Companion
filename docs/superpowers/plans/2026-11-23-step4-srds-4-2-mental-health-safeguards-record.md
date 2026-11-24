# Step 4 — SRDS 4.2 Mental Health Safeguards: implementation record (2026-11-23)

## Scope

1. Crisis Support screen with verified Pakistan and international helplines.
2. Reachable from Profile and Health-Bot.
3. Gentle professional-help prompt after repeated high anxiety/sadness ratings.
4. Supportive, non-judgmental, non-diagnostic wording.
5. Existing Health-Bot disclaimers, emergency referrals and behaviour preserved.

## Existing pieces checked first

- **Health-Bot emergencies:** the backend (`backend/app/healthbot/service.py`, `EMERGENCY_KEYWORDS`) and the local pre-check return a fixed referral ("This sounds like it could be a medical emergency. Please seek emergency medical care immediately."). It contained no helpline numbers and no link to act on. Unchanged.
- **Health-Bot disclaimer** ("Not a substitute for medical advice...", re-shown on every visit): unchanged.
- **Help & Support** (Profile): FAQ plus a support email only. There was no helpline screen anywhere in the app, so this is not a duplicate.
- **Mood data:** the Log Craving form stores 0–10 `moodAnxious` / `moodSad` slider ratings on every log. Older logs have null ratings. Journal mood is a single categorical pick, so the rule uses the craving sliders only.
- The SRDS PDF is not in the repo; requirements are taken from the user's Step 4 brief.

## Helpline verification (2026-11-23)

| Helpline | Number | Hours shown | Verified against |
| --- | --- | --- | --- |
| Rescue 1122 (Pakistan emergency) | 1122 | 24/7 | rescue.gov.pk; Find A Helpline Pakistan "Emergency Services" link |
| Umang Pakistan | 0311-7786264 | "Listed as 24/7 (hours may vary). Normal call charges may apply." | Express Tribune, 10 Oct 2024; Umang's official X profile. **umang.com.pk was down** (empty directory listing), and worldhotlines.org lists shorter hours, hence the hedged wording |
| Rozan Counseling Helpline | 0304-111-1741 | Mon–Fri 9:00–17:00 (Ramadan 10:00–18:00) | rozan.org/counseling-services (official); Find A Helpline |
| Find A Helpline | website | varies | findahelpline.com/about (ThroughLine, IASP partner, 175+ countries) |
| 988 Lifeline (USA) | 988, call/text | 24/7 | 988lifeline.org (official) |
| Samaritans (UK & Ireland) | 116 123 | 24/7, free | samaritans.org (official) |

Not included: Taskeen (0316-8275336), which has only one source; the old Rozan toll-free number 0800-22-444, which is not on Rozan's own site.
**Re-verify Umang before submission** if umang.com.pk comes back online.

## Design

- `lib/features/crisis_support/data/crisis_helplines.dart` — the list, with a `source` field per entry (audit only, not shown in the UI) and a do-not-edit-without-reverifying note.
- `.../data/helpline_launcher.dart` — `HelplineLauncher` interface; `UrlHelplineLauncher` uses `url_launcher` (`tel:`, `sms:`, external browser). If the dialer can't open, the screen copies the number to the clipboard and says so.
- `.../presentation/screens/crisis_support_screen.dart` — intro card, an "immediate danger → 1122 / local emergency number" notice, Pakistan and outside-Pakistan sections, and a footer stating the app is not a crisis service and doesn't contact anyone.
- **Entry points:**
  - Profile → new "Crisis Support" row (above Help & Support).
  - Health-Bot → app-bar button, available even before the disclaimer is accepted.
  - Health-Bot → "Get crisis support" link under every emergency reply. The original referral text is kept verbatim.
- **Prompt rule** (`.../domain/professional_support_check.dart`): at least 3 craving logs in the last 14 days with Anxious or Sad rated ≥ 8. Evaluated after a craving is saved (the new log included). A history lookup failure (e.g. offline) means no prompt and never blocks the save. Cooldown: 7 days after the prompt was shown (in memory, so it resets on app restart).
- **Prompt UI** (`.../widgets/professional_support_prompt.dart`), shown on Log Craving after submission and before the existing high-risk redirect, which then continues unchanged. The copy describes only what the user rated, normalizes it ("common while quitting"), suggests a counsellor, doctor or someone they trust, and offers "See support options" or "Not now". No condition names, no diagnosis. A test asserts the copy contains none of: depress, disorder, diagnos, illness, "you have".

## Other changes

- `pubspec.yaml`: added `url_launcher ^6.3.3` (Flutter's official package) — the app had no way to place calls.
- `android/app/src/main/AndroidManifest.xml`: `<queries>` for DIAL/tel, SENDTO/sms, VIEW/https (Android 11+ package visibility).
- `CravingLogController`: `suggestProfessionalSupport`, `markProfessionalSupportPromptShown()`, an injectable `ProfessionalSupportCheck`.

## Tests added

- `test/features/crisis_support/professional_support_check_test.dart` — rule thresholds, window, null ratings, inclusive 8; controller: raised on the 3rd high rating, never for normal ratings, 7-day cooldown, offline lookup never blocks saving.
- `test/features/crisis_support/crisis_support_screen_test.dart` — data integrity (source, digits-only dial numbers, required Pakistan entries), all cards and notices render, Call/Text/Website targets, clipboard fallback, 320×640 at 1.5× text.
- `profile_screen_test.dart` — Crisis Support row navigation.
- `health_bot_screen_test.dart` — app-bar button before the disclaimer; emergency reply keeps its text, adds a link only on emergency bubbles, and the link navigates.
- `log_craving_screen_test.dart` — prompt after repeated high ratings with a non-diagnostic copy check; "See support options" opens Crisis Support; "Not now" resumes the normal result; no prompt without repeated ratings.

## Manual Android verification still required

- Tap each Call button: the dialer opens pre-filled (no call is placed automatically). Tap 988 Text: the SMS app opens. Tap Website: the browser opens.
- Health-Bot: the app-bar icon works before "I Understand"; send "I want to end my life" → emergency bubble → "Get crisis support".
- Log three cravings with Anxious or Sad at 8+ → the prompt appears after the third, and not again until 7 days pass (or the app restarts).
- Check layout with a large system font on a small phone.

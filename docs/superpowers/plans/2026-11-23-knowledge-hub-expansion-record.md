# Knowledge Hub expansion: implementation record (2026-11-23)

Owner-approved plan. Decisions: categories = four reader groups + Health Risks; reading time calculated from length. No Firebase rules, credentials, configuration or unrelated modules changed. No Git operations or deployment.

## Requirements basis

- No SRDS document is in the repo. The Knowledge Hub code quotes SRDS Module 9 / FR13: "a curated library of educational content about the health effects of nicotine, the science of addiction, and the documented health benefits of quitting at various milestones… sourced from WHO, CDC, and peer-reviewed medical research".
- Bookmarks are a required feature (`docs/FEATURE_AUDIT.md`).
- The hub layout follows `docs/UI_Design/knowledge hub 14.png`.

## What changed

**Content** (`mobile/lib/features/knowledge/data/`)
- **21 new original articles** (`knowledge_article_library_expanded.dart`) → **37 articles in total** (16 existing + 21 new).

  | Category | Articles | New | Topics |
  | --- | --- | --- | --- |
  | Addiction & Recovery | 10 | 4 | how nicotine affects the brain and body; milestones from 24 hours to 1 year; withdrawal symptoms; how long nicotine affects you |
  | Cravings & Relapse | 8 | 6 | sudden cravings; 5-minute techniques; personal triggers; slips and relapse; stress without nicotine; healthy habits and alternatives |
  | Health & Wellness | 9 | 6 | lung health; heart and circulation; sleep; mental health; exercise and nutrition; anxiety and irritability |
  | Motivation & Lifestyle | 5 | 5 | staying motivated; achievable goals; celebrating milestones; financial benefits; a nicotine-free lifestyle |
  | Health Risks | 5 | 0 | existing harms-of-use articles, re-filed |

- **Sourcing:**
  - every factual statement comes from a trusted page that was fetched and read on 2026-11-23, and each article lists its sources in a code comment and links them in `resources`;
  - written in original words, with no medicine dosages or diagnoses;
  - covers vaping and other nicotine products where the sources do.
- **Where sources gave no figure, none is stated.** No verified page gives a nicotine clearance time (the NCI dictionary page is JavaScript-rendered and couldn't be read), so that article explains what *is* documented instead of giving a number. No prices or savings figures are given either; the app calculates the user's own.
- **The 16 existing articles** keep their text and IDs unchanged, so **existing bookmarks still work**. They're re-filed into the new categories and each gains a summary and trusted links.

**External resources** (`knowledge_resource_library.dart`)
- **45 distinct links** from WHO (3), CDC (10), NHS (5), Smokefree.gov (25) and NCI (2).
- Each was requested and returned **HTTP 200 directly (no redirect) with a page title matching the topic**, re-checked against the final code on 2026-11-23: 45/45.
- Candidate pages that returned 404 or redirected (13) were dropped, not guessed.
- 17 general links form the hub's **Links** view.

**Model and controller**
- `KnowledgeArticle` gains `summary`, `resources` and `matches(query)`.
- `readTimeMinutes` is calculated as words ÷ 200, rounded up, with a minimum of 1.
- New `KnowledgeResource` and `ResourceOrganization` (label and allowed host).
- The controller gains `query` / `setQuery` (combined with the category and Saved filters) and `resources`.

**UI** (existing theme and layout kept)
- **Hub:** the search icon (previously decorative) opens a working search field. Five category chips. Cards show the title, a two-line summary and reading time. A third toggle, **Links**, lists external resources grouped by organisation, each tagged **External**, with an explanation that they open in the browser and aren't part of Quit Companion.
- **Article detail:** a summary line, a "Learn more from trusted sources" section with External-tagged links that open in the browser (via the existing launcher), and a **medical disclaimer** on every article.
- **New:** `presentation/widgets/external_resource_tile.dart`.

## Tests

- Updated 3 existing test files for the new categories, calculated reading time and summary field.
- New `test/features/knowledge/knowledge_expansion_test.dart` (13 tests):
  - 37 articles with unique IDs, and all 16 original IDs kept (bookmark safety);
  - every category populated; every article has a summary and at least one resource;
  - every link is https on its organisation's own host;
  - no dosages in article text;
  - the reading-time formula;
  - search across title/summary/body, combined with the category filter, plus the empty state;
  - bookmarks on old and new articles;
  - the hub search field;
  - the Links view (External tag; tapping opens the URL);
  - article detail (summary, External links that open, disclaimer).

**Results**

| Check | Result |
| --- | --- |
| `test/features/knowledge` | **37 passed, 0 failed** |
| Live link check (all URLs in the shipped code) | **45/45 HTTP 200**, no redirects, titles match |
| Full `flutter analyze` | No issues |
| Full Flutter suite (123 files) | **863 passed, 0 failed, 0 skipped**, exit code 0 |

## Not verified / remaining

- **No clinical review:** the content has been sourced and checked against the linked pages, but no clinician has reviewed it.
- **Links can change:** external pages can move or change later; re-run the link check before release.
- **Installed, not yet checked on the phone:** debug APK built 2026-11-24 00:01:53 (contains the new articles and "Learn more" section); installed on the vivo V2022 with `adb install -r` ("Success", 00:03:51; data kept). Owner-checked on the phone (2026-11-24): **search works and the Links tab works**. Not yet reported: category chips, Saved Articles, and the article detail's "Learn more" links and disclaimer. There's no backend log evidence for any of this, because the Knowledge Hub runs entirely on the device.

# Dashboard Background Illustration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Dashboard's flat placeholder background with the illustrated sunrise/countryside scene from the approved reference art, cropped directly out of `docs/UI_Design/dashboard 5.png` into two static PNG assets, layered behind the scrollable content card.

**Architecture:** A one-off Python/Pillow script crops the reference image into `dashboard_bg_top.png` (sky: sun, rays, clouds, birds) and `dashboard_bg_bottom.png` (hills, path, flowers, trees). `DashboardScreen`'s existing background `Stack` (already has `Positioned` slots keyed `dashboard_background_top`/`dashboard_background_bottom`) swaps its bottom slot from a flat gradient `DecoratedBox` to an `Image`, mirroring the top slot's existing pattern exactly (`BoxFit.fitWidth`, no forced height, `IgnorePointer`). No new widgets, no `CustomPainter`, no state/data changes — pure asset + two-line widget swap.

**Tech Stack:** Flutter/Dart, Python 3 + Pillow (build-time only, not shipped), `flutter_test`.

## Global Constraints

- Source of truth for crop regions and final look: `docs/UI_Design/dashboard 5.png` (768×1376 px, RGBA).
- Background images are static and non-interactive — always wrapped in `IgnorePointer`, matching the existing top-layer pattern.
- Background stays fixed behind the scrollable content (`Stack` with background `Positioned` layers below a scrolling `SafeArea`/`SingleChildScrollView`) — do not make the background itself scroll.
- Reuse the existing `Positioned` keys `dashboard_background_top` / `dashboard_background_bottom` — `dashboard_screen_test.dart:242-243` already asserts on them.
- No new pubspec dependencies — Pillow runs standalone via `python`, outside the Flutter build.

---

### Task 1: Crop the reference art into top/bottom background assets

**Files:**
- Create (script, run once, not committed): `C:\Users\PMYLS\AppData\Local\Temp\claude\C--Users-PMYLS-Quit-Companion-backend\13acbef4-1aaf-451b-971d-c2385af97032\scratchpad\crop_dashboard_bg.py` (or the current session's scratchpad directory — never commit this script)
- Create (asset): `mobile/assets/images/dashboard_bg_bottom.png`
- Modify (asset, overwrite): `mobile/assets/images/dashboard_bg_top.png`

**Interfaces:**
- Produces: two PNG files at `mobile/assets/images/dashboard_bg_top.png` (crop rows 0–820 of the 768×1376 reference) and `mobile/assets/images/dashboard_bg_bottom.png` (crop rows 560–1376), both full width (768 px). The 260 px row overlap (560–820) is intentional and harmless — in the running app both images sit behind the content card, so only the exposed margins above/below the card are ever visible; the overlap guarantees full coverage regardless of device aspect ratio.

- [ ] **Step 1: Write the crop script**

```python
# crop_dashboard_bg.py (scratchpad — not committed)
# Run this script with its working directory set to the repo/worktree root
# you are implementing in — all paths below are relative to that root, so
# the cropped assets land in YOUR checkout, not some other clone/worktree.
from PIL import Image

SRC = "docs/UI_Design/dashboard 5.png"
TOP_OUT = "mobile/assets/images/dashboard_bg_top.png"
BOTTOM_OUT = "mobile/assets/images/dashboard_bg_bottom.png"

im = Image.open(SRC).convert("RGBA")
width, height = im.size
assert (width, height) == (768, 1376), f"unexpected reference size: {im.size}"

top = im.crop((0, 0, width, 820))
bottom = im.crop((0, 560, width, height))

top.save(TOP_OUT)
bottom.save(BOTTOM_OUT)
print("top:", top.size, "bottom:", bottom.size)
```

- [ ] **Step 2: Run the script**

Save the script to your scratchpad directory, then run it with the repo/worktree root as the working directory, e.g.:
`cd <repo-or-worktree-root> && python "<path-to-scratchpad>/crop_dashboard_bg.py"`
Expected output: `top: (768, 820) bottom: (768, 816)`

- [ ] **Step 3: Verify the crops visually**

Read both `mobile/assets/images/dashboard_bg_top.png` and `mobile/assets/images/dashboard_bg_bottom.png` with the Read tool and confirm: the top image shows the peach sky gradient with the sun, rays, clouds, and birds; the bottom image shows the green rolling hills, winding path, flowers, and trees. Neither should be a flat/blank crop (the current `dashboard_bg_top.png` placeholder is a 768×61 flat sliver — confirm the new one is visibly different and 820 px tall).

- [ ] **Step 4: Commit**

```bash
git add mobile/assets/images/dashboard_bg_top.png mobile/assets/images/dashboard_bg_bottom.png
git commit -m "chore(dashboard): crop sunrise background art from reference image"
```

---

### Task 2: Register the new asset in pubspec.yaml

**Files:**
- Modify: `mobile/pubspec.yaml:84` (asset list, right after the existing `dashboard_bg_top.png` line)

**Interfaces:**
- Consumes: `mobile/assets/images/dashboard_bg_bottom.png` produced by Task 1.
- Produces: asset available to `AssetImage('assets/images/dashboard_bg_bottom.png')` in Task 3.

- [ ] **Step 1: Add the asset entry**

In `mobile/pubspec.yaml`, immediately after the line `    - assets/images/dashboard_bg_top.png` add:

```yaml
    - assets/images/dashboard_bg_bottom.png
```

- [ ] **Step 2: Verify pub get succeeds**

Run: `flutter pub get` (from `mobile/`)
Expected: completes with no errors (asset registration doesn't need a version bump, just needs to be listed and present on disk).

- [ ] **Step 3: Commit**

```bash
git add mobile/pubspec.yaml
git commit -m "chore(dashboard): register dashboard_bg_bottom.png asset"
```

---

### Task 3: Extend the widget test to lock in the Image-based bottom background

**Files:**
- Modify: `mobile/test/screens/dashboard_screen_test.dart:242-243`

**Interfaces:**
- Consumes: `Key('dashboard_background_top')`, `Key('dashboard_background_bottom')` (already present in `dashboard_screen.dart`), `Image`/`AssetImage` from `flutter/material.dart` (already imported in this test file).

- [ ] **Step 1: Write the failing assertions**

Replace lines 242-243:

```dart
    expect(find.byKey(const Key('dashboard_background_top')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_background_bottom')), findsOneWidget);
```

with:

```dart
    expect(find.byKey(const Key('dashboard_background_top')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_background_bottom')), findsOneWidget);

    final topImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('dashboard_background_top')),
        matching: find.byType(Image),
      ),
    );
    expect((topImage.image as AssetImage).assetName, 'assets/images/dashboard_bg_top.png');

    final bottomImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('dashboard_background_bottom')),
        matching: find.byType(Image),
      ),
    );
    expect((bottomImage.image as AssetImage).assetName, 'assets/images/dashboard_bg_bottom.png');
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/screens/dashboard_screen_test.dart` (from `mobile/`)
Expected: FAIL — no `Image` descendant found under `dashboard_background_bottom` (it's currently a `DecoratedBox` gradient, not an `Image`).

- [ ] **Step 3: Commit the test**

```bash
git add mobile/test/screens/dashboard_screen_test.dart
git commit -m "test(dashboard): assert bottom background renders the illustrated asset"
```

---

### Task 4: Swap the bottom background from a flat gradient to the illustrated Image

**Files:**
- Modify: `mobile/lib/screens/dashboard/dashboard_screen.dart:163-180`

**Interfaces:**
- Consumes: `assets/images/dashboard_bg_bottom.png` (Task 1/2).
- Produces: no change to the public `DashboardScreen` API — purely internal `build()` change.

- [ ] **Step 1: Replace the bottom Positioned block**

In `mobile/lib/screens/dashboard/dashboard_screen.dart`, replace:

```dart
          Positioned(
            key: const Key('dashboard_background_bottom'),
            bottom: 0,
            left: 0,
            right: 0,
            height: 160,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.heroHill],
                  ),
                ),
              ),
            ),
          ),
```

with:

```dart
          Positioned(
            key: const Key('dashboard_background_bottom'),
            bottom: 0,
            left: 0,
            right: 0,
            child: const IgnorePointer(
              child: Image(
                image: AssetImage('assets/images/dashboard_bg_bottom.png'),
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
```

This mirrors the existing top layer exactly (no forced `height`, `BoxFit.fitWidth`, `IgnorePointer`) so both bands scale consistently by width and reveal their full illustrated content behind the card.

- [ ] **Step 2: Check for now-unused imports/references**

`AppColors.heroHill` was only used in the block just removed — confirm with a search that `dashboard_screen.dart` has no other reference to `heroHill` (it doesn't; `AppColors` itself stays imported since `AppColors.background`, `.textPrimary`, `.error` are still used elsewhere in the file, so no import line needs removing).

- [ ] **Step 3: Run the test to verify it passes**

Run: `flutter test test/screens/dashboard_screen_test.dart` (from `mobile/`)
Expected: PASS, including the two new assertions from Task 3.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(dashboard): render illustrated sunrise background behind content card"
```

---

### Task 5: Run the full test suite and visually verify against the reference

**Files:** none (verification only)

- [ ] **Step 1: Run the full mobile test suite**

Run: `flutter test` (from `mobile/`)
Expected: PASS, no regressions in other dashboard/widget tests.

- [ ] **Step 2: Launch the app and screenshot the Dashboard**

Use the `run` skill (or `flutter run` on an emulator/simulator) to launch the app, navigate to the Dashboard screen, and capture a screenshot.

- [ ] **Step 3: Compare against the reference**

Place the screenshot side-by-side (mentally or via the Read tool) against `docs/UI_Design/dashboard 5.png` and confirm:
- Sun, rays, clouds, birds visible above/behind the content card at the top.
- Rolling green hills, winding path, flower details, trees visible below/behind the content card and behind the bottom nav.
- Cards/text remain clearly readable against the illustration (no contrast regression).
- No visible seam/gap between the top and bottom background images behind the card.
- Scrolling the dashboard content does not move the background (it stays fixed).

- [ ] **Step 4: Report the result to the user**

Share the screenshot and a one-line summary of the comparison so the user can confirm the match before this work is considered done (per their original request).

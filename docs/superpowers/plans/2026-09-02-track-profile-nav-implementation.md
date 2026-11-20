# Track & Profile Bottom-Nav Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the two dead bottom-nav icons (Track, Profile) to real, data-backed, animated screens matching the approved mockups, add the one new `gender` field they need, and keep every existing test passing.

**Architecture:** Two new screens (`TrackScreen`, `ProfileScreen`) pushed from `DashboardScreen` exactly like Health-Bot/Community already are. Two new controllers (`TrackController` for read-only stat aggregation, `ProfileController` for the two profile mutations) follow this codebase's existing `ChangeNotifier` + fake-repository-backed pattern. One new onboarding step (`GenderSelectionScreen`) is inserted into `main.dart`'s existing linear `_Step` state machine. All new illustrations are hand-painted `CustomPaint`/composited-widget art (no new image assets), matching the precedent set by `DashboardBackground` and `RewardsScreen`'s illustrations. All new animation reuses `TweenAnimationBuilder`/`AnimationController` — no new package.

**Tech Stack:** Flutter/Dart, `provider` (already a dependency) — nothing else new.

**Spec:** `docs/superpowers/specs/2026-09-02-track-profile-nav-design.md`

## Global Constraints

- No new third-party packages, no new image assets for illustrations — every new visual is `CustomPaint`/`Icon`/`Container` composition in `AppColors`' sage/terracotta/cream palette.
- Every stat shown must trace to a real, already-persisted source. No fabricated data.
- `OnboardingScaffold`/`OnboardingHeaderIllustration` (used by 3 already-verified, frozen onboarding screens) are **not modified** — `GenderSelectionScreen` gets its own small self-contained layout instead, to keep zero blast radius on that frozen code.
- Every new interactive widget gets a `Key(...)` following this codebase's existing convention (e.g. `dashboard_bottom_nav_community`).
- Animations must fully settle under `tester.pumpAndSettle()` — no indefinitely-repeating (`..repeat()`) controllers on new widgets.
- Run `flutter test` after every task from `mobile/` and confirm the full suite is green before moving to the next task — this codebase has ~20+ existing test files that must keep passing throughout.

---

## Task 1: Gender model + NicotineUser field + copyWith(name, gender) + Firestore persistence

**Files:**
- Create: `mobile/lib/models/gender.dart`
- Modify: `mobile/lib/models/nicotine_user.dart`
- Modify: `mobile/lib/data/firestore_user_repository.dart`
- Test: `mobile/test/models/nicotine_user_test.dart`

**Interfaces:**
- Produces: `enum Gender { male, female }`; `NicotineUser.gender` (nullable); `NicotineUser.copyWith({..., String? name, Gender? gender})` — note `copyWith` today silently ignores `name` entirely (it always re-passes the original `name`), so adding a real `name` override is a required, not cosmetic, part of this task.

- [ ] **Step 1: Write the failing test**

Add to `mobile/test/models/nicotine_user_test.dart` (new `import 'package:quit_companion/models/gender.dart';` at top):

```dart
  test('copyWith can override name and gender', () {
    const user = NicotineUser(userId: 'u1', email: 'a@b.com', name: 'Mehreen');

    final renamed = user.copyWith(name: 'Sukaina', gender: Gender.male);

    expect(renamed.name, 'Sukaina');
    expect(renamed.gender, Gender.male);
    expect(renamed.userId, 'u1'); // unrelated fields preserved
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `mobile/`): `flutter test test/models/nicotine_user_test.dart`
Expected: FAIL — `Gender` and `copyWith(name: ..., gender: ...)` don't exist yet (compile error).

- [ ] **Step 3: Create the Gender enum**

```dart
// mobile/lib/models/gender.dart
enum Gender { male, female }
```

- [ ] **Step 4: Add the field and fix copyWith on NicotineUser**

In `mobile/lib/models/nicotine_user.dart`, add the import and field, and fix `copyWith`:

```dart
import 'gender.dart';
import 'product_type.dart';
import 'quit_strategy.dart';

class NicotineUser {
  final String userId;
  final String email;
  final String? name;
  final Gender? gender;
  final ProductType? productType;
  // ...unchanged fields...

  const NicotineUser({
    required this.userId,
    required this.email,
    this.name,
    this.gender,
    this.productType,
    // ...unchanged...
  });

  NicotineUser copyWith({
    String? name,
    Gender? gender,
    ProductType? productType,
    // ...unchanged params...
  }) {
    return NicotineUser(
      userId: userId,
      email: email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      productType: productType ?? this.productType,
      // ...unchanged...
    );
  }
}
```

(Keep every other existing field/param exactly as-is — only `name` and `gender` are new/changed.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/models/nicotine_user_test.dart`
Expected: PASS (both the new test and the pre-existing `copyWith only overrides the given fields` test).

- [ ] **Step 6: Persist gender in Firestore**

In `mobile/lib/data/firestore_user_repository.dart`, add the import and field to both `saveUser` and `getUser`:

```dart
import '../models/gender.dart';
// ...

  Future<void> saveUser(NicotineUser user) async {
    await _users.doc(user.userId).set({
      'email': user.email,
      'name': user.name,
      'gender': user.gender?.name,
      'productType': user.productType?.name,
      // ...unchanged...
    });
  }

  Future<NicotineUser?> getUser(String userId) async {
    final doc = await _users.doc(userId).get();
    final data = doc.data();
    if (data == null) return null;

    return NicotineUser(
      userId: userId,
      email: data['email'] as String,
      name: data['name'] as String?,
      gender: _parseGender(data['gender'] as String?),
      productType: _parseProductType(data['productType'] as String?),
      // ...unchanged...
    );
  }

  Gender? _parseGender(String? name) =>
      name == null ? null : Gender.values.firstWhere((v) => v.name == name);
```

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: PASS (no regressions — `FakeUserRepository` needs no change, it stores whole objects).

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/models/gender.dart mobile/lib/models/nicotine_user.dart mobile/lib/data/firestore_user_repository.dart mobile/test/models/nicotine_user_test.dart
git commit -m "feat(profile): add Gender field to NicotineUser"
```

---

## Task 2: AuthController.logout()

**Files:**
- Modify: `mobile/lib/controllers/auth_controller.dart`
- Test: `mobile/test/controllers/auth_controller_test.dart` (create if it doesn't already exist — check first with the Glob/search tool; if it exists, add to it following its existing style)

**Interfaces:**
- Produces: `Future<void> AuthController.logout()` — calls the repository, clears `userId`, resets `status` to `AuthStatus.idle`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/auth_controller.dart';
import 'package:quit_companion/data/fake_auth_repository.dart';

void main() {
  test('logout clears the current user id', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository);
    await controller.register(email: 'a@b.com', password: 'password1');
    expect(controller.userId, isNotNull);

    await controller.logout();

    expect(controller.userId, isNull);
    expect(repository.currentUserId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/auth_controller_test.dart`
Expected: FAIL — `logout` is not defined on `AuthController`.

- [ ] **Step 3: Implement logout**

In `mobile/lib/controllers/auth_controller.dart`, add:

```dart
  Future<void> logout() async {
    await _authRepository.logout();
    userId = null;
    status = AuthStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/auth_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/controllers/auth_controller.dart mobile/test/controllers/auth_controller_test.dart
git commit -m "feat(auth): add AuthController.logout()"
```

---

## Task 3: OnboardingController.recordGender()

**Files:**
- Modify: `mobile/lib/controllers/onboarding_controller.dart`
- Test: `mobile/test/controllers/onboarding_controller_test.dart` (extend existing file)

**Interfaces:**
- Consumes: `NicotineUser.copyWith({Gender? gender})` (Task 1).
- Produces: `void OnboardingController.recordGender(Gender gender)`.

- [ ] **Step 1: Write the failing test**

Add to the existing onboarding controller test file (mirror its existing `recordConsent`-style test):

```dart
  test('recordGender stores gender on the working user', () {
    final controller = OnboardingController(FakeUserRepository(), QuitDateCalculator());
    controller.startOnboarding(userId: 'u1', email: 'a@b.com');

    controller.recordGender(Gender.female);

    expect(controller.workingUser!.gender, Gender.female);
  });
```

(Add `import 'package:quit_companion/models/gender.dart';` at the top.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/onboarding_controller_test.dart`
Expected: FAIL — `recordGender` not defined.

- [ ] **Step 3: Implement recordGender**

In `mobile/lib/controllers/onboarding_controller.dart`:

```dart
import '../models/gender.dart';
// ...

  void recordGender(Gender gender) {
    _workingUser = _requireWorkingUser().copyWith(gender: gender);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/onboarding_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/controllers/onboarding_controller.dart mobile/test/controllers/onboarding_controller_test.dart
git commit -m "feat(onboarding): add recordGender"
```

---

## Task 4: GenderSelectionScreen (new onboarding step, self-contained — no changes to OnboardingScaffold)

**Files:**
- Create: `mobile/lib/screens/onboarding/gender_selection_screen.dart`
- Test: `mobile/test/screens/onboarding/gender_selection_screen_test.dart`

**Interfaces:**
- Consumes: `Gender` enum (Task 1).
- Produces: `GenderSelectionScreen({required VoidCallback onBack, required void Function(Gender) onContinue, Gender? initialSelection})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/screens/onboarding/gender_selection_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/models/gender.dart';
import 'package:quit_companion/screens/onboarding/gender_selection_screen.dart';

void main() {
  testWidgets('selecting a gender enables Continue and reports the choice', (tester) async {
    Gender? selected;
    await tester.pumpWidget(MaterialApp(
      home: GenderSelectionScreen(
        onBack: () {},
        onContinue: (g) => selected = g,
      ),
    ));

    expect(find.byKey(const Key('gender_continue_button')), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byKey(const Key('gender_continue_button')));
    expect(button.onPressed, isNull); // disabled until a selection is made

    await tester.tap(find.byKey(const Key('gender_option_female')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('gender_continue_button')));
    await tester.pump();

    expect(selected, Gender.female);
  });

  testWidgets('back button invokes onBack', (tester) async {
    var backTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: GenderSelectionScreen(onBack: () => backTapped = true, onContinue: (_) {}),
    ));

    await tester.tap(find.byKey(const Key('onboarding_back_link')));
    await tester.pump();

    expect(backTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/onboarding/gender_selection_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement GenderSelectionScreen**

```dart
// mobile/lib/screens/onboarding/gender_selection_screen.dart
import 'package:flutter/material.dart';
import '../../models/gender.dart';
import '../../theme/app_theme.dart';
import 'widgets/onboarding_back_link.dart';
import 'widgets/onboarding_progress_bar.dart';

class _GenderOption {
  final Gender gender;
  final String label;
  final IconData icon;
  const _GenderOption(this.gender, this.label, this.icon);
}

const _options = [
  _GenderOption(Gender.female, 'Female', Icons.face_3_outlined),
  _GenderOption(Gender.male, 'Male', Icons.face_6_outlined),
];

/// New first onboarding step (before Product Selection): lets Profile's
/// avatar reflect the user later. Deliberately does NOT reuse
/// OnboardingScaffold/OnboardingHeaderIllustration (both frozen, already
/// device-verified for the 3 screens after this one) — this screen builds
/// its own header illustration instead, so nothing about those shared
/// widgets changes for this feature.
class GenderSelectionScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(Gender) onContinue;
  final Gender? initialSelection;

  const GenderSelectionScreen({super.key, required this.onBack, required this.onContinue, this.initialSelection});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  Gender? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _GenderHeaderIllustration(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnboardingBackLink(onTap: widget.onBack),
                    const SizedBox(height: 18),
                    const OnboardingProgressBar(currentStep: 1, totalSteps: 5),
                    const SizedBox(height: 20),
                    Text('Tell us about yourself', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text(
                      "This helps us personalize your avatar. You can change it later in your profile.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    for (final option in _options) ...[
                      _GenderOptionRow(
                        option: option,
                        selected: _selected == option.gender,
                        onTap: () => setState(() => _selected = option.gender),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      key: const Key('gender_continue_button'),
                      onPressed: _selected == null ? null : () => widget.onContinue(_selected!),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderOptionRow extends StatelessWidget {
  final _GenderOption option;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOptionRow({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('gender_option_${option.gender.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.terracotta : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(option.icon, color: selected ? AppColors.terracotta : AppColors.sageDark, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(option.label, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}

/// Flat, hand-painted "welcome" header — two abstract person silhouettes
/// on a sage banner, echoing the avatar shapes Profile uses later. No new
/// image asset (same reasoning as DashboardBackground/RewardsScreen).
class _GenderHeaderIllustration extends StatelessWidget {
  const _GenderHeaderIllustration();

  Widget _silhouette(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Container(
          width: 52,
          height: 40,
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('gender_header_illustration'),
      width: double.infinity,
      height: 160,
      color: AppColors.sage,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _silhouette(AppColors.terracottaLight),
          const SizedBox(width: 16),
          _silhouette(Colors.white),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/onboarding/gender_selection_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/onboarding/gender_selection_screen.dart mobile/test/screens/onboarding/gender_selection_screen_test.dart
git commit -m "feat(onboarding): add Gender selection screen"
```

---

## Task 5: Wire Gender step into main.dart's onboarding flow

**Files:**
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/screens/onboarding/product_selection_screen.dart` (bump `step`/`totalSteps`)
- Modify: `mobile/lib/screens/onboarding/product_quantity_screen.dart` (bump `step`/`totalSteps`)
- Modify: `mobile/lib/screens/onboarding/goal_selection_screen.dart` (bump `step`/`totalSteps`)
- Test: `mobile/test/app_flow_test.dart` (existing end-to-end onboarding test — extend the registration flow to tap through the new Gender step)

**Interfaces:**
- Consumes: `GenderSelectionScreen` (Task 4), `OnboardingController.recordGender` (Task 3).

- [ ] **Step 1: Find and read the existing registration flow test**

Search `mobile/test/app_flow_test.dart` for the sequence that currently taps through Consent → Product Selection → Quantity → Goal after registering. This step's test change inserts one more tap in that exact sequence (selecting a gender option and tapping Continue) right after Consent and before the Product Selection tap. Read the file first to match its exact existing helper/tap style before editing — do not guess at helper names.

- [ ] **Step 2: Run the existing test to confirm current baseline passes**

Run: `flutter test test/app_flow_test.dart`
Expected: PASS (baseline, before this task's changes).

- [ ] **Step 3: Update the `_Step` enum and `_buildStep` switch in main.dart**

```dart
enum _Step {
  welcome, register, login, phoneEntry, phoneOtp, consent,
  gender, productSelection, quantity, goal, complete, loggedIn,
}
```

Change the consent case's destination and add the new gender case (insert right after the existing `case _Step.consent:` block):

```dart
      case _Step.consent:
        return ConsentScreen(onContinue: () => setState(() => _step = _Step.gender));
      case _Step.gender:
        return GenderSelectionScreen(
          onBack: () => setState(() => _step = _Step.consent),
          onContinue: (gender) {
            context.read<OnboardingController>().recordGender(gender);
            setState(() => _step = _Step.productSelection);
          },
        );
      case _Step.productSelection:
        return ProductSelectionScreen(
          initialSelection: _selectedProductType,
          onBack: () => setState(() => _step = _Step.gender),
          onContinue: (type) => setState(() {
            _selectedProductType = type;
            _step = _Step.quantity;
          }),
        );
```

Add the import: `import 'screens/onboarding/gender_selection_screen.dart';`

Also update `_onPhoneVerified`'s new-user branch, which currently jumps straight to consent:

```dart
      context.read<OnboardingController>().startOnboarding(userId: userId, email: '');
      setState(() => _step = _Step.consent);
```

This stays unchanged — it already lands on consent, which now flows into gender automatically via the case above. No further edit needed there.

- [ ] **Step 4: Bump step numbers in the three shifted screens**

`product_selection_screen.dart`: `step: 1` → `step: 2`, `totalSteps: 4` → `totalSteps: 5`.
`product_quantity_screen.dart`: `step: 2` → `step: 3`, `totalSteps: 4` → `totalSteps: 5`.
`goal_selection_screen.dart`: `step: 3` → `step: 4`, `totalSteps: 4` → `totalSteps: 5`.

- [ ] **Step 5: Update app_flow_test.dart**

Add the gender-selection tap into the existing tap sequence, immediately after whatever taps/pumps the test currently uses to get past Consent, and before its Product Selection tap:

```dart
    await tester.tap(find.byKey(const Key('gender_option_female')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gender_continue_button')));
    await tester.pumpAndSettle();
```

(Match the exact `pump`/`pumpAndSettle` calls the surrounding test already uses for its other step transitions — read the file to confirm which is used at that point in the sequence.)

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: PASS — including `app_flow_test.dart` and the three onboarding widget tests (which don't assert exact segment counts, confirmed during planning, so the step-number bump doesn't break them).

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/main.dart mobile/lib/screens/onboarding/product_selection_screen.dart mobile/lib/screens/onboarding/product_quantity_screen.dart mobile/lib/screens/onboarding/goal_selection_screen.dart mobile/test/app_flow_test.dart
git commit -m "feat(onboarding): insert Gender step into the registration flow"
```

---

## Task 6: Shared staggered entrance-animation widget (extracted from DashboardScreen)

**Files:**
- Create: `mobile/lib/widgets/staggered_entrance.dart`
- Modify: `mobile/lib/screens/dashboard/dashboard_screen.dart` (use the new widget instead of its private `_animated` helper — behavior-identical refactor)
- Test: `mobile/test/widgets/staggered_entrance_test.dart`

**Interfaces:**
- Produces: `StaggeredEntrance({required int index, required Animation<double> parent, required Widget child})` — a `FadeTransition`+`SlideTransition` pair driven by an `Interval` computed from `index`, identical math to `DashboardScreen._animated`.
- Also produces: `StaggeredEntranceController` (a small `StatefulWidget` mixin-free helper is unnecessary — instead, document that callers own their own `AnimationController` with `SingleTickerProviderStateMixin` and pass it in as `parent`, exactly like `DashboardScreen` already does). This task only extracts the per-child transition, not the controller itself, so `DashboardScreen`'s controller lifecycle (`initState`/`dispose`/`_hasAnimatedIn` gating) is untouched.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/widgets/staggered_entrance_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/widgets/staggered_entrance.dart';

void main() {
  testWidgets('fades and settles child into view as the parent animation completes', (tester) async {
    final controller = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 500));
    await tester.pumpWidget(MaterialApp(
      home: StaggeredEntrance(index: 0, parent: controller, child: const Text('hello')),
    ));

    final opacityAtStart = tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
    expect(opacityAtStart, 0);

    controller.value = 1.0;
    await tester.pump();

    final opacityAtEnd = tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
    expect(opacityAtEnd, 1);
    expect(find.text('hello'), findsOneWidget);

    controller.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/staggered_entrance_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement StaggeredEntrance**

```dart
// mobile/lib/widgets/staggered_entrance.dart
import 'package:flutter/material.dart';

/// Shared staggered fade+slide-in transition, used by every screen with a
/// multi-section entrance animation (Dashboard, Track, Profile). [index]
/// controls the stagger offset — section 0 starts immediately, each
/// following section starts 0.1 later in [parent]'s 0..1 timeline, same
/// math DashboardScreen originally used inline.
class StaggeredEntrance extends StatelessWidget {
  final int index;
  final Animation<double> parent;
  final Widget child;

  const StaggeredEntrance({super.key, required this.index, required this.parent, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final animation = CurvedAnimation(
      parent: parent,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/staggered_entrance_test.dart`
Expected: PASS.

- [ ] **Step 5: Refactor DashboardScreen to use it (no behavior change)**

In `mobile/lib/screens/dashboard/dashboard_screen.dart`, replace the private `_animated` method body with a call to the new widget, and replace every `_animated(i, ...)` call site with `StaggeredEntrance(index: i, parent: _entranceController, child: ...)`:

```dart
import '../../widgets/staggered_entrance.dart';
// ...
  // Delete the private _animated method entirely.
```

Replace each call, e.g.:
```dart
                    StaggeredEntrance(index: 0, parent: _entranceController, child: DashboardHeader(name: controller.user?.name, onNotificationsTap: () => _openReminderSettings(context))),
```
(...and the same substitution for every other `_animated(N, ...)` call site in the file.)

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: PASS — `dashboard_screen_test.dart`'s existing tests are behavior-agnostic to this internal refactor.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/widgets/staggered_entrance.dart mobile/lib/screens/dashboard/dashboard_screen.dart mobile/test/widgets/staggered_entrance_test.dart
git commit -m "refactor(dashboard): extract StaggeredEntrance for reuse by Track/Profile"
```

---

## Task 7: Wire DashboardBottomNav's Track/Profile taps

**Files:**
- Modify: `mobile/lib/screens/dashboard/widgets/dashboard_bottom_nav.dart`
- Test: create `mobile/test/screens/dashboard_bottom_nav_test.dart` (no such file exists yet — this is the first dedicated test for this widget)

**Interfaces:**
- Produces: `DashboardBottomNav` now requires `onTrackTap`/`onProfileTap` in addition to the existing `onHealthBotTap`/`onCommunityTap`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/screens/dashboard_bottom_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/dashboard/widgets/dashboard_bottom_nav.dart';

void main() {
  Widget buildNav({
    VoidCallback? onTrackTap,
    VoidCallback? onProfileTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: DashboardBottomNav(
          onHealthBotTap: () {},
          onCommunityTap: () {},
          onTrackTap: onTrackTap ?? () {},
          onProfileTap: onProfileTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('tapping Track invokes onTrackTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildNav(onTrackTap: () => tapped = true));

    await tester.tap(find.byKey(const Key('dashboard_bottom_nav_track')));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tapping Profile invokes onProfileTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildNav(onProfileTap: () => tapped = true));

    await tester.tap(find.byKey(const Key('dashboard_bottom_nav_profile')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/dashboard_bottom_nav_test.dart`
Expected: FAIL — `onTrackTap`/`onProfileTap` params and their keys don't exist yet.

- [ ] **Step 3: Implement the wiring**

In `mobile/lib/screens/dashboard/widgets/dashboard_bottom_nav.dart`:

```dart
class DashboardBottomNav extends StatelessWidget {
  final VoidCallback onHealthBotTap;
  final VoidCallback onCommunityTap;
  final VoidCallback onTrackTap;
  final VoidCallback onProfileTap;

  const DashboardBottomNav({
    super.key,
    required this.onHealthBotTap,
    required this.onCommunityTap,
    required this.onTrackTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _navTile(_navItems[0], active: true)),
          Expanded(
            child: _navTile(_navItems[1], active: true, key: const Key('dashboard_bottom_nav_track'), onTap: onTrackTap),
          ),
          Expanded(child: _HealthBotTile(onTap: onHealthBotTap)),
          Expanded(
            child: _navTile(_navItems[2], active: true, key: const Key('dashboard_bottom_nav_community'), onTap: onCommunityTap),
          ),
          Expanded(
            child: _navTile(_navItems[3], active: true, key: const Key('dashboard_bottom_nav_profile'), onTap: onProfileTap),
          ),
        ],
      ),
    );
  }

  // ...rest of the file (_navTile, _HealthBotTile) unchanged...
}
```

Also update the class doc comment (currently claims "Only 'Home' maps to a real screen... Track/Profile have no screens yet") since it's now stale — replace it with a comment reflecting that all five destinations are real.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/dashboard_bottom_nav_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: FAIL at this point — `dashboard_screen_test.dart` and any other caller of `DashboardBottomNav`/`DashboardScreen` won't compile yet because `DashboardScreen` doesn't pass the two new required callbacks down. This is expected and resolved in Task 14. Confirm the failure is exactly a missing-named-argument compile error in `dashboard_screen.dart`, not something else.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/dashboard/widgets/dashboard_bottom_nav.dart mobile/test/screens/dashboard_bottom_nav_test.dart
git commit -m "feat(dashboard): wire Track/Profile bottom-nav taps"
```

---

## Task 8: ProfileController

**Files:**
- Create: `mobile/lib/controllers/profile_controller.dart`
- Test: `mobile/test/controllers/profile_controller_test.dart`

**Interfaces:**
- Consumes: `UserRepository` (existing), `NicotineUser.copyWith(name:, gender:)` (Task 1).
- Produces: `ProfileController(UserRepository)`; `enum ProfileEditStatus { idle, saving, success, error }`; `Future<bool> updateName(NicotineUser user, String name)`; `Future<bool> updateGender(NicotineUser user, Gender gender)`; fields `status`, `errorMessage`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/controllers/profile_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/profile_controller.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/models/gender.dart';
import 'package:quit_companion/models/nicotine_user.dart';

void main() {
  test('updateName saves the trimmed name and reports success', () async {
    final repository = FakeUserRepository();
    const user = NicotineUser(userId: 'u1', email: 'a@b.com', name: 'Old Name');
    final controller = ProfileController(repository);

    final result = await controller.updateName(user, '  New Name  ');

    expect(result, isTrue);
    expect(controller.status, ProfileEditStatus.success);
    final saved = await repository.getUser('u1');
    expect(saved!.name, 'New Name');
  });

  test('updateName rejects an empty name', () async {
    final repository = FakeUserRepository();
    const user = NicotineUser(userId: 'u1', email: 'a@b.com', name: 'Old Name');
    final controller = ProfileController(repository);

    final result = await controller.updateName(user, '   ');

    expect(result, isFalse);
    expect(controller.status, ProfileEditStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  test('updateGender saves the selected gender', () async {
    final repository = FakeUserRepository();
    const user = NicotineUser(userId: 'u1', email: 'a@b.com');
    final controller = ProfileController(repository);

    final result = await controller.updateGender(user, Gender.male);

    expect(result, isTrue);
    final saved = await repository.getUser('u1');
    expect(saved!.gender, Gender.male);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/profile_controller_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement ProfileController**

```dart
// mobile/lib/controllers/profile_controller.dart
import 'package:flutter/foundation.dart';
import '../data/user_repository.dart';
import '../models/gender.dart';
import '../models/nicotine_user.dart';

enum ProfileEditStatus { idle, saving, success, error }

/// Owns Profile's two user-editable mutations (display name, avatar
/// gender). Read-side data (quit date, product type, phase) is already
/// loaded by DashboardController and reused as-is — this controller never
/// fetches the user itself, only saves an updated copy the caller already
/// holds, then the caller re-triggers DashboardController.loadDashboard to
/// refresh the shared instance (same pattern DashboardController.logUsage
/// already uses for its own save-then-reload).
class ProfileController extends ChangeNotifier {
  final UserRepository _userRepository;

  ProfileController(this._userRepository);

  ProfileEditStatus status = ProfileEditStatus.idle;
  String? errorMessage;

  Future<bool> updateName(NicotineUser user, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      errorMessage = 'Name cannot be empty.';
      status = ProfileEditStatus.error;
      notifyListeners();
      return false;
    }
    status = ProfileEditStatus.saving;
    errorMessage = null;
    notifyListeners();
    try {
      await _userRepository.saveUser(user.copyWith(name: trimmed));
      status = ProfileEditStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not save your name. Check your connection and try again.';
      status = ProfileEditStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGender(NicotineUser user, Gender gender) async {
    status = ProfileEditStatus.saving;
    errorMessage = null;
    notifyListeners();
    try {
      await _userRepository.saveUser(user.copyWith(gender: gender));
      status = ProfileEditStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not save your avatar. Check your connection and try again.';
      status = ProfileEditStatus.error;
      notifyListeners();
      return false;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/profile_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/controllers/profile_controller.dart mobile/test/controllers/profile_controller_test.dart
git commit -m "feat(profile): add ProfileController"
```

---

## Task 9: Longest-streak domain calculator

**Files:**
- Create: `mobile/lib/domain/longest_streak_calculator.dart`
- Test: `mobile/test/domain/longest_streak_calculator_test.dart`

**Interfaces:**
- Produces: `int computeLongestStreakDays({required DateTime quitDate, required List<DateTime> relapseDates, required DateTime today})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/domain/longest_streak_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/domain/longest_streak_calculator.dart';

void main() {
  test('with no relapses, the streak is the full span from quitDate to today', () {
    final result = computeLongestStreakDays(
      quitDate: DateTime(2026, 8, 1),
      relapseDates: [],
      today: DateTime(2026, 8, 11),
    );
    expect(result, 10);
  });

  test('takes the longest gap across multiple relapses', () {
    final result = computeLongestStreakDays(
      quitDate: DateTime(2026, 8, 1),
      relapseDates: [DateTime(2026, 8, 3), DateTime(2026, 8, 20)],
      today: DateTime(2026, 8, 25),
    );
    // Gaps: quitDate->relapse1 = 2, relapse1->relapse2 = 17, relapse2->today = 5.
    expect(result, 17);
  });

  test('unsorted relapse dates are handled correctly', () {
    final result = computeLongestStreakDays(
      quitDate: DateTime(2026, 8, 1),
      relapseDates: [DateTime(2026, 8, 20), DateTime(2026, 8, 3)],
      today: DateTime(2026, 8, 25),
    );
    expect(result, 17);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/longest_streak_calculator_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement the calculator**

```dart
// mobile/lib/domain/longest_streak_calculator.dart
/// Longest smoke-free gap across the user's whole history: the largest
/// difference in days between consecutive points in
/// [quitDate, ...sorted relapseDates, today]. Relapses are the only
/// negative signal the app persists (JournalEntry.relapseFlag,
/// RelapseController) — this deliberately does not treat a merely-logged
/// craving as breaking a streak, since logging a craving is itself the
/// coping action, not evidence of relapse.
int computeLongestStreakDays({
  required DateTime quitDate,
  required List<DateTime> relapseDates,
  required DateTime today,
}) {
  DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  final points = [dateOnly(quitDate), ...relapseDates.map(dateOnly), dateOnly(today)]..sort();

  var longest = 0;
  for (var i = 1; i < points.length; i++) {
    final gap = points[i].difference(points[i - 1]).inDays;
    if (gap > longest) longest = gap;
  }
  return longest;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/longest_streak_calculator_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/domain/longest_streak_calculator.dart mobile/test/domain/longest_streak_calculator_test.dart
git commit -m "feat(track): add longest-streak calculator"
```

---

## Task 10: TrackController

**Files:**
- Create: `mobile/lib/controllers/track_controller.dart`
- Test: `mobile/test/controllers/track_controller_test.dart`

**Interfaces:**
- Consumes: `CravingLogRepository` (existing: `getRecentLogs`, `countCravingsResistedSince`), `JournalRepository` (existing: `getEntries`), `UserRepository` (existing: `getUser`), `computeLongestStreakDays` (Task 9).
- Produces:
  ```dart
  enum TrackStatus { idle, loading, loaded, error }
  class TrackActivityItem {
    final DateTime date;
    final String title;
    final String subtitle;
    final bool isRelapse;
  }
  class TrackController extends ChangeNotifier {
    TrackStatus status;
    String? errorMessage;
    int totalCravingsLogged;
    int cravingsResisted;
    double? resistedPercent; // null when there's no data yet (avoid a misleading 0%/100%)
    int longestStreakDays;
    Map<TriggerCategory, int> triggerBreakdown;
    List<TrackActivityItem> recentActivity; // newest first, capped at 10
    Future<void> loadTrack(String userId);
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/controllers/track_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/track_controller.dart';
import 'package:quit_companion/data/fake_craving_log_repository.dart';
import 'package:quit_companion/data/fake_journal_repository.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/models/craving_log.dart';
import 'package:quit_companion/models/journal_entry.dart';
import 'package:quit_companion/models/mood.dart';
import 'package:quit_companion/models/nicotine_user.dart';
import 'package:quit_companion/models/relapse_risk_level.dart';
import 'package:quit_companion/models/trigger_category.dart';

void main() {
  final fixedToday = DateTime(2026, 9, 2);

  CravingLog log(String id, DateTime ts, TriggerCategory trigger) => CravingLog(
        logId: id,
        userId: 'u1',
        cravingIntensity: 5,
        mood: Mood.stressed,
        triggerCategory: trigger,
        locationContext: 'Home',
        activity: 'Home',
        timestamp: ts,
        relapseRiskScore: RelapseRiskLevel.low,
      );

  test('aggregates cravings, resisted percent, streak, breakdown, and activity', () async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(NicotineUser(userId: 'u1', email: 'a@b.com', quitDate: DateTime(2026, 8, 1)));

    final cravingLogRepository = FakeCravingLogRepository();
    await cravingLogRepository.logCraving(log('c1', DateTime(2026, 8, 5), TriggerCategory.stress));
    await cravingLogRepository.logCraving(log('c2', DateTime(2026, 8, 6), TriggerCategory.stress));
    await cravingLogRepository.logCraving(log('c3', DateTime(2026, 8, 22), TriggerCategory.boredom));

    final journalRepository = FakeJournalRepository();
    await journalRepository.saveEntry(JournalEntry(
      entryId: 'r1',
      userId: 'u1',
      entryDate: DateTime(2026, 8, 10),
      relapseFlag: true,
      triggerCategory: TriggerCategory.socialPressure,
    ));

    final controller = TrackController(cravingLogRepository, journalRepository, userRepository, now: () => fixedToday);
    await controller.loadTrack('u1');

    expect(controller.status, TrackStatus.loaded);
    expect(controller.totalCravingsLogged, 3);
    expect(controller.cravingsResisted, 3);
    expect(controller.resistedPercent, closeTo(0.75, 0.001)); // 3 resisted / (3 resisted + 1 relapse)
    expect(controller.longestStreakDays, 12); // quitDate(8/1)->relapse(8/10) = 9, relapse(8/10)->today(9/2) = 23d... see note below
    expect(controller.triggerBreakdown[TriggerCategory.stress], 2);
    expect(controller.triggerBreakdown[TriggerCategory.boredom], 1);
    expect(controller.recentActivity.first.isRelapse, isFalse); // c3 (8/22) is the most recent event, before the relapse-dated 8/10 entry
  });

  test('resistedPercent is null with no craving or relapse data at all', () async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(NicotineUser(userId: 'u1', email: 'a@b.com', quitDate: DateTime(2026, 8, 1)));
    final controller = TrackController(FakeCravingLogRepository(), FakeJournalRepository(), userRepository, now: () => fixedToday);

    await controller.loadTrack('u1');

    expect(controller.resistedPercent, isNull);
    expect(controller.totalCravingsLogged, 0);
  });
}
```

*(Note: the exact longest-streak expected value in the first test must be computed and corrected against `computeLongestStreakDays`'s real behavior before this test is finalized — recompute by hand from the same three points `[2026-08-01, 2026-08-10, 2026-09-02]`: gaps are 9 and 23, so the correct expectation is `23`, not `12`. Fix the test's expected value to `23` — this parenthetical itself is not something to leave in the file; write the corrected literal `23` directly in the assertion.)*

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/track_controller_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement TrackController**

```dart
// mobile/lib/controllers/track_controller.dart
import 'package:flutter/foundation.dart';
import '../data/craving_log_repository.dart';
import '../data/journal_repository.dart';
import '../data/user_repository.dart';
import '../domain/longest_streak_calculator.dart';
import '../models/trigger_category.dart';

enum TrackStatus { idle, loading, loaded, error }

class TrackActivityItem {
  final DateTime date;
  final String title;
  final String subtitle;
  final bool isRelapse;

  const TrackActivityItem({required this.date, required this.title, required this.subtitle, required this.isRelapse});
}

const _triggerLabels = {
  TriggerCategory.stress: 'Stress',
  TriggerCategory.afterMeal: 'After Meal',
  TriggerCategory.socialPressure: 'Social Pressure',
  TriggerCategory.boredom: 'Boredom',
  TriggerCategory.other: 'Other',
};

/// Aggregates Track screen stats from data Modules 3/5 already persist —
/// no new Firestore collection, no fabricated metrics. See
/// docs/superpowers/specs/2026-09-02-track-profile-nav-design.md §3.
class TrackController extends ChangeNotifier {
  final CravingLogRepository _cravingLogRepository;
  final JournalRepository _journalRepository;
  final UserRepository _userRepository;
  final DateTime Function() now;

  TrackController(
    this._cravingLogRepository,
    this._journalRepository,
    this._userRepository, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  TrackStatus status = TrackStatus.idle;
  String? errorMessage;
  int totalCravingsLogged = 0;
  int cravingsResisted = 0;
  double? resistedPercent;
  int longestStreakDays = 0;
  Map<TriggerCategory, int> triggerBreakdown = {};
  List<TrackActivityItem> recentActivity = [];

  Future<void> loadTrack(String userId) async {
    status = TrackStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final user = await _userRepository.getUser(userId);
      if (user == null || user.quitDate == null) {
        errorMessage = 'Your quit plan is not set up yet.';
        status = TrackStatus.error;
        notifyListeners();
        return;
      }
      final quitDate = user.quitDate!;
      final cravingLogs = await _cravingLogRepository.getRecentLogs(userId, quitDate);
      final resisted = await _cravingLogRepository.countCravingsResistedSince(userId, quitDate);
      final journalEntries = await _journalRepository.getEntries(userId);
      final relapses = journalEntries.where((e) => e.relapseFlag && !e.entryDate.isBefore(quitDate)).toList();

      totalCravingsLogged = cravingLogs.length;
      cravingsResisted = resisted;
      final universe = resisted + relapses.length;
      resistedPercent = universe == 0 ? null : resisted / universe;
      longestStreakDays = computeLongestStreakDays(
        quitDate: quitDate,
        relapseDates: [for (final r in relapses) r.entryDate],
        today: now(),
      );

      triggerBreakdown = {for (final t in TriggerCategory.values) t: 0};
      for (final log in cravingLogs) {
        triggerBreakdown[log.triggerCategory] = (triggerBreakdown[log.triggerCategory] ?? 0) + 1;
      }

      final activity = <TrackActivityItem>[
        for (final log in cravingLogs)
          TrackActivityItem(
            date: log.timestamp,
            title: 'Craving logged',
            subtitle: _triggerLabels[log.triggerCategory]!,
            isRelapse: false,
          ),
        for (final r in relapses)
          TrackActivityItem(
            date: r.entryDate,
            title: 'Relapse logged',
            subtitle: r.triggerCategory != null ? _triggerLabels[r.triggerCategory]! : 'No trigger noted',
            isRelapse: true,
          ),
      ]..sort((a, b) => b.date.compareTo(a.date));
      recentActivity = activity.take(10).toList();

      status = TrackStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('TrackController.loadTrack failed: $e');
      errorMessage = 'Could not load your progress. Check your connection and try again.';
      status = TrackStatus.error;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/track_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full test suite and commit**

Run: `flutter test`

```bash
git add mobile/lib/controllers/track_controller.dart mobile/test/controllers/track_controller_test.dart
git commit -m "feat(track): add TrackController"
```

---

## Task 11: Profile avatar + header background illustrations

**Files:**
- Create: `mobile/lib/screens/profile/widgets/profile_avatar.dart`
- Create: `mobile/lib/screens/profile/widgets/profile_header_background.dart`
- Test: `mobile/test/screens/profile/widgets/profile_avatar_test.dart`

**Interfaces:**
- Produces: `ProfileAvatar({required Gender? gender, double size = 96})` (defaults to female when `gender == null`, matching the design decision); `ProfileHeaderBackground` (pure decorative, no params).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/screens/profile/widgets/profile_avatar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/models/gender.dart';
import 'package:quit_companion/screens/profile/widgets/profile_avatar.dart';

void main() {
  testWidgets('renders the male-keyed avatar for Gender.male', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileAvatar(gender: Gender.male)));
    expect(find.byKey(const Key('profile_avatar_male')), findsOneWidget);
  });

  testWidgets('defaults to the female-keyed avatar when gender is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileAvatar(gender: null)));
    expect(find.byKey(const Key('profile_avatar_female')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/profile/widgets/profile_avatar_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement both widgets**

```dart
// mobile/lib/screens/profile/widgets/profile_avatar.dart
import 'package:flutter/material.dart';
import '../../../models/gender.dart';
import '../../../theme/app_theme.dart';

/// Hand-painted circular avatar (no image asset) — a simple flat
/// head+shoulders silhouette, hair shape distinguishing the two variants.
/// Defaults to female when [gender] is null (matches the mockup's only
/// existing illustration, and the app's only pre-gender-field users).
class ProfileAvatar extends StatelessWidget {
  final Gender? gender;
  final double size;

  const ProfileAvatar({super.key, required this.gender, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final isMale = gender == Gender.male;
    return Container(
      key: Key(isMale ? 'profile_avatar_male' : 'profile_avatar_female'),
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size(size, size),
        painter: _AvatarPainter(isMale: isMale),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final bool isMale;
  _AvatarPainter({required this.isMale});

  @override
  void paint(Canvas canvas, Size size) {
    final skinPaint = Paint()..color = AppColors.terracottaLight;
    final hairPaint = Paint()..color = isMale ? AppColors.textPrimary.withValues(alpha: 0.75) : AppColors.sageDark;
    final shirtPaint = Paint()..color = isMale ? AppColors.sage : Colors.white;

    canvas.drawCircle(size.center(Offset.zero), size.width / 2, Paint()..color = AppColors.sageLight);

    // Shoulders/shirt.
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.62, size.width * 0.8, size.height * 0.6),
      3.14159,
      3.14159,
      true,
      shirtPaint,
    );

    // Face.
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.42), size.width * 0.22, skinPaint);

    // Hair — a fuller arc for the female variant (longer hair), a short cap for male.
    final hairHeight = isMale ? size.height * 0.16 : size.height * 0.34;
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.24, size.height * 0.14, size.width * 0.52, hairHeight * 1.6),
      3.14159,
      3.14159,
      true,
      hairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) => oldDelegate.isMale != isMale;
}
```

```dart
// mobile/lib/screens/profile/widgets/profile_header_background.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Flat sage banner with a couple of leaf accents, echoing the mockup's
/// hand-painted greenery — same hand-painted-not-cropped approach as
/// DashboardBackground/RewardsScreen's illustrations.
class ProfileHeaderBackground extends StatelessWidget {
  const ProfileHeaderBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profile_header_background'),
      color: AppColors.sage,
      child: Stack(
        children: [
          Positioned(top: -10, left: -10, child: Icon(Icons.eco, size: 64, color: AppColors.sageDark.withValues(alpha: 0.4))),
          Positioned(top: 10, right: -14, child: Icon(Icons.eco, size: 80, color: AppColors.sageDark.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/profile/widgets/profile_avatar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/profile/widgets/profile_avatar.dart mobile/lib/screens/profile/widgets/profile_header_background.dart mobile/test/screens/profile/widgets/profile_avatar_test.dart
git commit -m "feat(profile): add hand-painted avatar and header background"
```

---

## Task 12: ProfileScreen

> **Execution-order note (added post-hoc during the whole-branch review):**
> despite its number, this task was actually dispatched *after* Tasks 13-14,
> since `ProfileScreen` links out to `PersonalInformationScreen`/
> `PrivacySecurityScreen`/`HelpSupportScreen`/`AboutScreen`, which only exist
> once those tasks' output files land. The sketch below (and its
> `_weeklyPlanControllerPlaceholder`-shaped gap) was written before that
> dependency was resolved; the real `ProfileScreen` signature closes the gap
> by taking `aiPlanController`/`reminderController`/`gamificationController`
> as real constructor params — mirroring `DashboardScreen`'s existing
> controller-injection pattern — rather than leaving them as placeholders.
> See the "Known follow-up baked into Task 12" note near the end of this
> document for the same callout in context.

**Files:**
- Create: `mobile/lib/screens/profile/profile_screen.dart`
- Test: `mobile/test/screens/profile/profile_screen_test.dart`

**Interfaces:**
- Consumes: `DashboardController` (existing, for `user`/`state`), `ProfileController` (Task 8), `ProfileAvatar`/`ProfileHeaderBackground` (Task 11), `StaggeredEntrance` (Task 6). Screens it links to: `WeeklyPlanScreen`, `ReminderSettingsScreen`, `RewardsScreen` (all existing), plus `PersonalInformationScreen`/`PrivacySecurityScreen`/`HelpSupportScreen`/`AboutScreen` (Tasks 13-14).
- Produces (as first sketched, before the dependency on Tasks 13-14 was resolved — see note above for the real signature): `ProfileScreen({required String userId, required DashboardController dashboardController, required ProfileController profileController, required VoidCallback onLogout})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/screens/profile/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/dashboard_controller.dart';
import 'package:quit_companion/controllers/profile_controller.dart';
import 'package:quit_companion/data/fake_craving_log_repository.dart';
import 'package:quit_companion/data/fake_usage_log_repository.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/models/nicotine_user.dart';
import 'package:quit_companion/models/product_type.dart';
import 'package:quit_companion/models/quit_strategy.dart';
import 'package:quit_companion/screens/profile/profile_screen.dart';

void main() {
  final fixedToday = DateTime(2026, 9, 2);

  Future<DashboardController> buildLoadedController(FakeUserRepository userRepository) async {
    await userRepository.saveUser(NicotineUser(
      userId: 'u1',
      email: 'a@b.com',
      name: 'Mehreen',
      productType: ProductType.cigarettes,
      quitStrategy: QuitStrategy.coldTurkey,
      quitDate: DateTime(2026, 8, 1),
      baselineDailyUsage: 10,
    ));
    final controller = DashboardController(
      userRepository,
      FakeUsageLogRepository(),
      FakeCravingLogRepository(),
      DashboardStateCalculator(now: () => fixedToday),
      now: () => fixedToday,
    );
    await controller.loadDashboard('u1');
    return controller;
  }

  testWidgets('shows the user name, product type, and Log Out triggers onLogout', (tester) async {
    final userRepository = FakeUserRepository();
    final dashboardController = await buildLoadedController(userRepository);
    var loggedOut = false;

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        userId: 'u1',
        dashboardController: dashboardController,
        profileController: ProfileController(userRepository),
        onLogout: () => loggedOut = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mehreen'), findsOneWidget);
    expect(find.byKey(const Key('profile_avatar_female')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('profile_log_out_button')));
    await tester.tap(find.byKey(const Key('profile_log_out_button')));
    await tester.pump();

    expect(loggedOut, isTrue);
  });

  testWidgets('editing the name saves through ProfileController', (tester) async {
    final userRepository = FakeUserRepository();
    final dashboardController = await buildLoadedController(userRepository);
    final profileController = ProfileController(userRepository);

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        userId: 'u1',
        dashboardController: dashboardController,
        profileController: profileController,
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile_edit_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile_edit_name_field')), 'Sukaina');
    await tester.tap(find.byKey(const Key('profile_edit_save_button')));
    await tester.pumpAndSettle();

    final saved = await userRepository.getUser('u1');
    expect(saved!.name, 'Sukaina');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/profile/profile_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement ProfileScreen**

```dart
// mobile/lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../domain/dashboard_state_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staggered_entrance.dart';
import '../goals/weekly_plan_screen.dart';
import '../rewards/rewards_screen.dart';
import '../settings/reminder_settings_screen.dart';
import 'about_screen.dart';
import 'help_support_screen.dart';
import 'personal_information_screen.dart';
import 'privacy_security_screen.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/profile_header_background.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final DashboardController dashboardController;
  final ProfileController profileController;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.dashboardController,
    required this.profileController,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _openEditName() async {
    final user = widget.dashboardController.user;
    if (user == null) return;
    final controller = TextEditingController(text: user.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          key: const Key('profile_edit_name_field'),
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            key: const Key('profile_edit_save_button'),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;
    final success = await widget.profileController.updateName(user, newName);
    if (success && mounted) {
      await widget.dashboardController.loadDashboard(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.dashboardController.user;
    final state = widget.dashboardController.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredEntrance(
                index: 0,
                parent: _entranceController,
                child: _ProfileHeader(
                  name: user?.name ?? 'there',
                  gender: user?.gender,
                  onEditTap: _openEditName,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaggeredEntrance(
                      index: 1,
                      parent: _entranceController,
                      child: _StatChipsRow(
                        quitDate: user?.quitDate,
                        productType: user?.productType,
                        thirdChip: state is NicotineFreeState
                            ? _StatChipData(icon: Icons.local_fire_department_rounded, label: 'Days Nicotine-Free', value: '${state.nicotineFreeDays}')
                            : state is CountdownState
                                ? _StatChipData(icon: Icons.hourglass_bottom_rounded, label: 'Days Until Quit', value: '${state.daysUntilQuit}')
                                : const _StatChipData(icon: Icons.local_fire_department_rounded, label: 'Days Nicotine-Free', value: '-'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (final (i, row) in _settingsRows(context).indexed)
                      StaggeredEntrance(
                        index: 2 + i,
                        parent: _entranceController,
                        child: Padding(padding: const EdgeInsets.only(bottom: 12), child: row),
                      ),
                    const SizedBox(height: 12),
                    StaggeredEntrance(
                      index: 2 + _settingsRows(context).length,
                      parent: _entranceController,
                      child: Center(
                        child: TextButton.icon(
                          key: const Key('profile_log_out_button'),
                          onPressed: widget.onLogout,
                          style: TextButton.styleFrom(foregroundColor: AppColors.terracotta),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Log Out'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _settingsRows(BuildContext context) {
    final user = widget.dashboardController.user;
    return [
      _SettingsRow(
        key: const Key('profile_row_personal_information'),
        icon: Icons.person_outline_rounded,
        label: 'Personal Information',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PersonalInformationScreen(
            userId: widget.userId,
            dashboardController: widget.dashboardController,
            profileController: widget.profileController,
          ),
        )),
      ),
      _SettingsRow(
        key: const Key('profile_row_my_quit_plan'),
        icon: Icons.assignment_outlined,
        label: 'My Quit Plan',
        onTap: user == null
            ? null
            : () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => WeeklyPlanScreen(userId: widget.userId, controller: _weeklyPlanControllerPlaceholder))),
      ),
      _SettingsRow(
        key: const Key('profile_row_notifications'),
        icon: Icons.notifications_none_rounded,
        label: 'Notifications',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReminderSettingsScreen(controller: _reminderControllerPlaceholder))),
      ),
      _SettingsRow(
        key: const Key('profile_row_privacy_security'),
        icon: Icons.lock_outline_rounded,
        label: 'Privacy & Security',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacySecurityScreen())),
      ),
      _SettingsRow(
        key: const Key('profile_row_achievements'),
        icon: Icons.emoji_events_outlined,
        label: 'Achievements',
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => RewardsScreen(userId: widget.userId, controller: _gamificationControllerPlaceholder))),
      ),
      _SettingsRow(
        key: const Key('profile_row_help_support'),
        icon: Icons.help_outline_rounded,
        label: 'Help & Support',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
      ),
      _SettingsRow(
        key: const Key('profile_row_about'),
        icon: Icons.info_outline_rounded,
        label: 'About Quit Companion',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
      ),
    ];
  }
}
```

**IMPORTANT — resolve before writing this file for real:** the sketch above references `_weeklyPlanControllerPlaceholder`, `_reminderControllerPlaceholder`, and `_gamificationControllerPlaceholder`, which do not exist — this is because `WeeklyPlanScreen`/`ReminderSettingsScreen`/`RewardsScreen` need their own already-built controllers (`AiPlanController`, `ReminderController`, `GamificationController`), which `ProfileScreen` doesn't currently receive. Before implementing this step, add three more required constructor parameters to `ProfileScreen` — `required AiPlanController aiPlanController`, `required ReminderController reminderController`, `required GamificationController gamificationController` — and pass those straight through in place of the three placeholders above (this mirrors exactly how `DashboardScreen` already receives and forwards these same controllers to the same three screens). Update this task's test file's `ProfileScreen(...)` construction to pass all three (reuse the same `build*Controller()` helper style already established in `dashboard_screen_test.dart`), and update Task 14's `DashboardScreen._openProfile` call site accordingly.

Now the two small supporting private widgets in the same file:

```dart
class _StatChipData {
  final IconData icon;
  final String label;
  final String value;
  const _StatChipData({required this.icon, required this.label, required this.value});
}

class _StatChipsRow extends StatelessWidget {
  final DateTime? quitDate;
  final ProductType? productType;
  final _StatChipData thirdChip;

  const _StatChipsRow({required this.quitDate, required this.productType, required this.thirdChip});

  static const _productLabels = {
    ProductType.vape: 'Vape',
    ProductType.cigarettes: 'Cigarette',
    ProductType.pouches: 'Pouches',
    ProductType.hookah: 'Hookah',
  };

  String _formatDate(DateTime? date) => date == null ? '-' : '${date.month}/${date.day}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final chips = [
      _StatChipData(icon: Icons.calendar_today_outlined, label: 'Quit Date', value: _formatDate(quitDate)),
      _StatChipData(icon: Icons.smoking_rooms_outlined, label: 'Product Type', value: productType == null ? '-' : _productLabels[productType]!),
      thirdChip,
    ];
    return Row(
      children: [
        for (final chip in chips) ...[
          Expanded(child: _StatChip(data: chip)),
          if (chip != chips.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final _StatChipData data;
  const _StatChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.sageLight, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(data.icon, color: AppColors.sageDark, size: 20),
          const SizedBox(height: 6),
          Text(data.value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(data.label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SettingsRow({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.sageLight, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: AppColors.sageDark, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final Gender? gender;
  final VoidCallback onEditTap;
  final VoidCallback onBack;

  const _ProfileHeader({required this.name, required this.gender, required this.onEditTap, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      child: SizedBox(
        height: 210,
        child: Stack(
          children: [
            const Positioned.fill(child: ProfileHeaderBackground()),
            Positioned(
              top: 12,
              left: 8,
              child: IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: TextButton.icon(
                key: const Key('profile_edit_button'),
                onPressed: onEditTap,
                style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Profile'),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  ProfileAvatar(gender: gender, size: 84),
                  const SizedBox(height: 10),
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Add the missing imports at the top of the file: `import '../../controllers/ai_plan_controller.dart';`, `import '../../controllers/gamification_controller.dart';`, `import '../../controllers/reminder_controller.dart';`, `import '../../models/gender.dart';`, `import '../../models/product_type.dart';`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/profile/profile_screen_test.dart`
Expected: PASS (after fixing the test's `ProfileScreen(...)` construction to also pass the three added controller params, per the note above).

- [ ] **Step 5: Run the full test suite and commit**

Run: `flutter test`

```bash
git add mobile/lib/screens/profile/profile_screen.dart mobile/test/screens/profile/profile_screen_test.dart
git commit -m "feat(profile): add ProfileScreen"
```

---

## Task 13: PersonalInformationScreen (with gender/avatar correction)

**Files:**
- Create: `mobile/lib/screens/profile/personal_information_screen.dart`
- Test: `mobile/test/screens/profile/personal_information_screen_test.dart`

**Interfaces:**
- Consumes: `DashboardController`, `ProfileController.updateGender` (Task 8), `ProfileAvatar` (Task 11).
- Produces: `PersonalInformationScreen({required String userId, required DashboardController dashboardController, required ProfileController profileController})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/screens/profile/personal_information_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/dashboard_controller.dart';
import 'package:quit_companion/controllers/profile_controller.dart';
import 'package:quit_companion/data/fake_craving_log_repository.dart';
import 'package:quit_companion/data/fake_usage_log_repository.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/models/nicotine_user.dart';
import 'package:quit_companion/models/product_type.dart';
import 'package:quit_companion/screens/profile/personal_information_screen.dart';

void main() {
  testWidgets('shows email/product type and lets the user pick an avatar gender', (tester) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(const NicotineUser(userId: 'u1', email: 'a@b.com', productType: ProductType.vape));
    final dashboardController = DashboardController(
      userRepository, FakeUsageLogRepository(), FakeCravingLogRepository(), DashboardStateCalculator(),
    );
    await dashboardController.loadDashboard('u1');
    final profileController = ProfileController(userRepository);

    await tester.pumpWidget(MaterialApp(
      home: PersonalInformationScreen(userId: 'u1', dashboardController: dashboardController, profileController: profileController),
    ));
    await tester.pumpAndSettle();

    expect(find.text('a@b.com'), findsOneWidget);
    expect(find.text('Vape'), findsOneWidget);

    await tester.tap(find.byKey(const Key('personal_info_avatar_male')));
    await tester.pumpAndSettle();

    final saved = await userRepository.getUser('u1');
    expect(saved!.gender.toString(), contains('male'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/profile/personal_information_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement PersonalInformationScreen**

```dart
// mobile/lib/screens/profile/personal_information_screen.dart
import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../models/gender.dart';
import '../../models/product_type.dart';
import '../../theme/app_theme.dart';
import 'widgets/profile_avatar.dart';

const _productLabels = {
  ProductType.vape: 'Vape',
  ProductType.cigarettes: 'Cigarettes',
  ProductType.pouches: 'Pouches',
  ProductType.hookah: 'Hookah',
};

class PersonalInformationScreen extends StatefulWidget {
  final String userId;
  final DashboardController dashboardController;
  final ProfileController profileController;

  const PersonalInformationScreen({
    super.key,
    required this.userId,
    required this.dashboardController,
    required this.profileController,
  });

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  Future<void> _pickGender(Gender gender) async {
    final user = widget.dashboardController.user;
    if (user == null) return;
    final success = await widget.profileController.updateGender(user, gender);
    if (success && mounted) {
      await widget.dashboardController.loadDashboard(widget.userId);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.dashboardController.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Information')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        key: const Key('personal_info_avatar_female'),
                        onTap: () => _pickGender(Gender.female),
                        borderRadius: BorderRadius.circular(48),
                        child: Opacity(
                          opacity: user?.gender == Gender.male ? 0.4 : 1,
                          child: const ProfileAvatar(gender: Gender.female, size: 72),
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        key: const Key('personal_info_avatar_male'),
                        onTap: () => _pickGender(Gender.male),
                        borderRadius: BorderRadius.circular(48),
                        child: Opacity(
                          opacity: user?.gender == Gender.male ? 1 : 0.4,
                          child: const ProfileAvatar(gender: Gender.male, size: 72),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap to change your avatar', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _InfoRow(label: 'Name', value: user?.name ?? '-'),
            _InfoRow(label: 'Email', value: user?.email ?? '-'),
            _InfoRow(label: 'Product Type', value: user?.productType == null ? '-' : _productLabels[user!.productType]!),
            _InfoRow(
              label: 'Quit Date',
              value: user?.quitDate == null ? '-' : '${user!.quitDate!.month}/${user.quitDate!.day}/${user.quitDate!.year}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/profile/personal_information_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/profile/personal_information_screen.dart mobile/test/screens/profile/personal_information_screen_test.dart
git commit -m "feat(profile): add Personal Information screen with avatar picker"
```

---

## Task 14: PrivacySecurityScreen, HelpSupportScreen, AboutScreen (static content screens)

**Files:**
- Create: `mobile/lib/screens/profile/privacy_security_screen.dart`
- Create: `mobile/lib/screens/profile/help_support_screen.dart`
- Create: `mobile/lib/screens/profile/about_screen.dart`
- Test: `mobile/test/screens/profile/static_profile_screens_test.dart` (one file covering all three — they're small enough that a reviewer would accept/reject all three together)

**Interfaces:**
- Produces: `PrivacySecurityScreen()`, `HelpSupportScreen()`, `AboutScreen()` — all zero-argument `StatelessWidget`s with an `AppBar` + static content, no controller dependencies.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/screens/profile/static_profile_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/profile/about_screen.dart';
import 'package:quit_companion/screens/profile/help_support_screen.dart';
import 'package:quit_companion/screens/profile/privacy_security_screen.dart';

void main() {
  testWidgets('PrivacySecurityScreen renders its title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacySecurityScreen()));
    expect(find.text('Privacy & Security'), findsWidgets);
  });

  testWidgets('HelpSupportScreen renders its title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
    expect(find.text('Help & Support'), findsWidgets);
  });

  testWidgets('AboutScreen renders the app name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    expect(find.text('Quit Companion'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/profile/static_profile_screens_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement the three screens**

```dart
// mobile/lib/screens/profile/privacy_security_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      backgroundColor: AppColors.background,
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Your data — quit plan, craving logs, journal entries, and community posts — is stored securely in '
            'your personal Firebase account and is never shared with third parties. You can request account '
            'deletion at any time from Help & Support.',
            style: TextStyle(color: AppColors.textPrimary, height: 1.5),
          ),
        ),
      ),
    );
  }
}
```

```dart
// mobile/lib/screens/profile/help_support_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _FaqTile(question: 'How is my Quit Day calculated?', answer: 'Based on the quit strategy you chose during onboarding — cold turkey, gradual reduction, or a specific target date.'),
            _FaqTile(question: 'Can I change my quit plan later?', answer: 'Your quit date and strategy are set once during onboarding. Reach out below if you need it reset.'),
            _FaqTile(question: 'Need more help?', answer: 'Email support@quitcompanion.app and we\'ll get back to you.'),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(answer, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}
```

```dart
// mobile/lib/screens/profile/about_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      backgroundColor: AppColors.background,
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quit Companion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Version 1.0.0', style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text(
                'Quit Companion helps you track cravings, follow a personalized quit plan, and celebrate your '
                'nicotine-free milestones — one day at a time.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/profile/static_profile_screens_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/profile/privacy_security_screen.dart mobile/lib/screens/profile/help_support_screen.dart mobile/lib/screens/profile/about_screen.dart mobile/test/screens/profile/static_profile_screens_test.dart
git commit -m "feat(profile): add Privacy & Security, Help & Support, About screens"
```

---

## Task 15: Animated Track stat tile + animated trigger-breakdown bars

**Files:**
- Create: `mobile/lib/screens/track/widgets/track_stat_tile.dart`
- Create: `mobile/lib/screens/track/widgets/trigger_breakdown_card.dart`
- Test: `mobile/test/screens/track/widgets/track_stat_tile_test.dart`
- Test: `mobile/test/screens/track/widgets/trigger_breakdown_card_test.dart`

**Interfaces:**
- Produces: `TrackStatTile({required IconData icon, required Color iconColor, required int value, required String label, String Function(int)? formatter, Key? valueKey})`; `TriggerBreakdownCard({required Map<TriggerCategory, int> counts})`.

- [ ] **Step 1: Write the failing tests**

```dart
// mobile/test/screens/track/widgets/track_stat_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/track/widgets/track_stat_tile.dart';

void main() {
  testWidgets('counts up to the target value and settles', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TrackStatTile(icon: Icons.local_fire_department, iconColor: Colors.red, value: 25, label: 'Longest Streak'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    expect(find.text('Longest Streak'), findsOneWidget);
  });
}
```

```dart
// mobile/test/screens/track/widgets/trigger_breakdown_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/models/trigger_category.dart';
import 'package:quit_companion/screens/track/widgets/trigger_breakdown_card.dart';

void main() {
  testWidgets('renders one row per trigger with its label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TriggerBreakdownCard(counts: {
        TriggerCategory.stress: 5,
        TriggerCategory.boredom: 2,
        TriggerCategory.afterMeal: 0,
        TriggerCategory.socialPressure: 0,
        TriggerCategory.other: 1,
      }),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Boredom'), findsOneWidget);
    expect(find.text('Trigger Breakdown'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/track/widgets/track_stat_tile_test.dart test/screens/track/widgets/trigger_breakdown_card_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement TrackStatTile**

```dart
// mobile/lib/screens/track/widgets/track_stat_tile.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Animated count-up stat tile (Total Cravings / Cravings Resisted /
/// Longest Streak). Counts from 0 to [value] once on first build.
class TrackStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;
  final String Function(int)? formatter;
  final Key? valueKey;

  const TrackStatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.formatter,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            key: valueKey,
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, animatedValue, _) => Text(
              formatter != null ? formatter!(animatedValue) : '$animatedValue',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement TriggerBreakdownCard**

```dart
// mobile/lib/screens/track/widgets/trigger_breakdown_card.dart
import 'package:flutter/material.dart';
import '../../../models/trigger_category.dart';
import '../../../theme/app_theme.dart';

const _triggerLabels = {
  TriggerCategory.stress: 'Stress',
  TriggerCategory.afterMeal: 'After Meal',
  TriggerCategory.socialPressure: 'Social Pressure',
  TriggerCategory.boredom: 'Boredom',
  TriggerCategory.other: 'Other',
};

/// Horizontal bar breakdown of craving trigger categories. Renamed from
/// the mockup's "Nicotine Product Breakdown" — the rows are trigger
/// categories, not products (see design spec §3). Each bar animates its
/// width in on first build, staggered by index via differing durations.
class TriggerBreakdownCard extends StatelessWidget {
  final Map<TriggerCategory, int> counts;

  const TriggerBreakdownCard({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final entries = TriggerCategory.values.map((t) => MapEntry(t, counts[t] ?? 0)).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trigger Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          for (final (i, entry) in entries.indexed) ...[
            _BreakdownRow(label: _triggerLabels[entry.key]!, fraction: entry.value / maxCount, delayMs: 500 + i * 120),
            if (entry.key != entries.last.key) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double fraction;
  final int delayMs;

  const _BreakdownRow({required this.label, required this.fraction, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 14,
              color: AppColors.border,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: Duration(milliseconds: delayMs),
                curve: Curves.easeOut,
                builder: (context, width, _) => FractionallySizedBox(
                  widthFactor: width.clamp(0, 1),
                  child: Container(color: AppColors.terracotta),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/screens/track/widgets/track_stat_tile_test.dart test/screens/track/widgets/trigger_breakdown_card_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/track/widgets/track_stat_tile.dart mobile/lib/screens/track/widgets/trigger_breakdown_card.dart mobile/test/screens/track/widgets/track_stat_tile_test.dart mobile/test/screens/track/widgets/trigger_breakdown_card_test.dart
git commit -m "feat(track): add animated stat tile and trigger breakdown widgets"
```

---

## Task 16: Recent Activity card + animated weekly-chart reveal wrapper

**Files:**
- Create: `mobile/lib/screens/track/widgets/recent_activity_card.dart`
- Create: `mobile/lib/screens/track/widgets/revealing_line_chart.dart`
- Test: `mobile/test/screens/track/widgets/recent_activity_card_test.dart`
- Test: `mobile/test/screens/track/widgets/revealing_line_chart_test.dart`

**Interfaces:**
- Consumes: `TrackActivityItem` (Task 10), `WeeklyTrendChartPainter` (existing, unmodified).
- Produces: `RecentActivityCard({required List<TrackActivityItem> items})`; `RevealingLineChart({required List<int> values})`.

- [ ] **Step 1: Write the failing tests**

```dart
// mobile/test/screens/track/widgets/recent_activity_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/track_controller.dart';
import 'package:quit_companion/screens/track/widgets/recent_activity_card.dart';

void main() {
  testWidgets('lists each activity item', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RecentActivityCard(items: [
        TrackActivityItem(date: DateTime(2026, 8, 22), title: 'Craving logged', subtitle: 'Boredom', isRelapse: false),
        TrackActivityItem(date: DateTime(2026, 8, 10), title: 'Relapse logged', subtitle: 'Social Pressure', isRelapse: true),
      ]),
    ));

    expect(find.text('Craving logged'), findsOneWidget);
    expect(find.text('Relapse logged'), findsOneWidget);
  });

  testWidgets('shows an empty-state hint with no activity', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RecentActivityCard(items: [])));

    expect(find.byKey(const Key('track_recent_activity_empty')), findsOneWidget);
  });
}
```

```dart
// mobile/test/screens/track/widgets/revealing_line_chart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/screens/track/widgets/revealing_line_chart.dart';

void main() {
  testWidgets('renders and settles without error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(height: 120, width: 300, child: RevealingLineChart(values: const [1, 2, 3, 4, 3, 2, 1])),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(RevealingLineChart), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/track/widgets/recent_activity_card_test.dart test/screens/track/widgets/revealing_line_chart_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement RecentActivityCard**

```dart
// mobile/lib/screens/track/widgets/recent_activity_card.dart
import 'package:flutter/material.dart';
import '../../../controllers/track_controller.dart';
import '../../../theme/app_theme.dart';

class RecentActivityCard extends StatelessWidget {
  final List<TrackActivityItem> items;
  const RecentActivityCard({super.key, required this.items});

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Row(
              key: const Key('track_recent_activity_empty'),
              children: const [
                Icon(Icons.history, color: AppColors.textSecondary, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Log a craving to start building your activity history.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            )
          else
            for (final item in items) ...[
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: item.isRelapse ? AppColors.terracottaLight : AppColors.sageLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isRelapse ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: item.isRelapse ? AppColors.terracottaDark : AppColors.sageDark,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(_formatDate(item.date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              if (item != items.last) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
            ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement RevealingLineChart**

```dart
// mobile/lib/screens/track/widgets/revealing_line_chart.dart
import 'package:flutter/material.dart';
import '../../dashboard/widgets/weekly_trend_chart_painter.dart';

/// Wraps the existing (unmodified) WeeklyTrendChartPainter with a
/// left-to-right reveal animation on first build — the chart itself is
/// reused as-is, only how much of it is clipped-visible animates.
class RevealingLineChart extends StatefulWidget {
  final List<int> values;
  const RevealingLineChart({super.key, required this.values});

  @override
  State<RevealingLineChart> createState() => _RevealingLineChartState();
}

class _RevealingLineChartState extends State<RevealingLineChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ClipRect(
        clipper: _RevealClipper(_controller.value),
        child: child,
      ),
      child: CustomPaint(painter: WeeklyTrendChartPainter(widget.values), size: Size.infinite),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double fraction;
  _RevealClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _RevealClipper oldClipper) => oldClipper.fraction != fraction;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/screens/track/widgets/recent_activity_card_test.dart test/screens/track/widgets/revealing_line_chart_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/track/widgets/recent_activity_card.dart mobile/lib/screens/track/widgets/revealing_line_chart.dart mobile/test/screens/track/widgets/recent_activity_card_test.dart mobile/test/screens/track/widgets/revealing_line_chart_test.dart
git commit -m "feat(track): add recent activity card and animated chart reveal"
```

---

## Task 17: TrackScreen

**Files:**
- Create: `mobile/lib/screens/track/track_screen.dart`
- Test: `mobile/test/screens/track/track_screen_test.dart`

**Interfaces:**
- Consumes: `TrackController` (Task 10), `DashboardController.weeklyTrend` (existing), `TrackStatTile`/`TriggerBreakdownCard` (Task 15), `RecentActivityCard`/`RevealingLineChart` (Task 16), `StaggeredEntrance` (Task 6).
- Produces: `TrackScreen({required String userId, required TrackController trackController, required DashboardController dashboardController})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/screens/track/track_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/dashboard_controller.dart';
import 'package:quit_companion/controllers/track_controller.dart';
import 'package:quit_companion/data/fake_craving_log_repository.dart';
import 'package:quit_companion/data/fake_journal_repository.dart';
import 'package:quit_companion/data/fake_usage_log_repository.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/domain/dashboard_state_calculator.dart';
import 'package:quit_companion/models/nicotine_user.dart';
import 'package:quit_companion/models/quit_strategy.dart';
import 'package:quit_companion/screens/track/track_screen.dart';

void main() {
  testWidgets('loads and shows the stat tiles', (tester) async {
    final userRepository = FakeUserRepository();
    await userRepository.saveUser(NicotineUser(
      userId: 'u1',
      email: 'a@b.com',
      quitStrategy: QuitStrategy.coldTurkey,
      quitDate: DateTime(2026, 8, 1),
      baselineDailyUsage: 10,
    ));
    final cravingLogRepository = FakeCravingLogRepository();
    final dashboardController = DashboardController(
      userRepository, FakeUsageLogRepository(), cravingLogRepository, DashboardStateCalculator(),
    );
    await dashboardController.loadDashboard('u1');
    final trackController = TrackController(cravingLogRepository, FakeJournalRepository(), userRepository);

    await tester.pumpWidget(MaterialApp(
      home: TrackScreen(userId: 'u1', trackController: trackController, dashboardController: dashboardController),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Track Your Progress'), findsOneWidget);
    expect(find.byKey(const Key('track_total_cravings_tile')), findsOneWidget);
    expect(find.byKey(const Key('track_resisted_tile')), findsOneWidget);
    expect(find.byKey(const Key('track_longest_streak_tile')), findsOneWidget);
    expect(find.text('Trigger Breakdown'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/track/track_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement TrackScreen**

```dart
// mobile/lib/screens/track/track_screen.dart
import 'package:flutter/material.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/track_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/staggered_entrance.dart';
import 'widgets/recent_activity_card.dart';
import 'widgets/revealing_line_chart.dart';
import 'widgets/track_stat_tile.dart';
import 'widgets/trigger_breakdown_card.dart';

class TrackScreen extends StatefulWidget {
  final String userId;
  final TrackController trackController;
  final DashboardController dashboardController;

  const TrackScreen({super.key, required this.userId, required this.trackController, required this.dashboardController});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  bool _hasAnimatedIn = false;

  @override
  void initState() {
    super.initState();
    widget.trackController.addListener(_onChanged);
    Future.microtask(() => widget.trackController.loadTrack(widget.userId));
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_hasAnimatedIn && widget.trackController.status == TrackStatus.loaded) {
      _hasAnimatedIn = true;
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    widget.trackController.removeListener(_onChanged);
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.trackController;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Track Your Progress')),
      body: SafeArea(
        child: _buildBody(controller),
      ),
    );
  }

  Widget _buildBody(TrackController controller) {
    if (controller.status == TrackStatus.loading || controller.status == TrackStatus.idle) {
      return const Center(key: Key('track_loading'), child: CircularProgressIndicator());
    }
    if (controller.status == TrackStatus.error) {
      return Center(
        child: Text(
          controller.errorMessage ?? 'Something went wrong.',
          key: const Key('track_error_text'),
          style: const TextStyle(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            parent: _entranceController,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This Week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  SizedBox(height: 120, child: RevealingLineChart(values: widget.dashboardController.weeklyTrend)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 1,
            parent: _entranceController,
            child: Row(
              children: [
                Expanded(
                  child: TrackStatTile(
                    valueKey: const Key('track_total_cravings_tile'),
                    icon: Icons.local_fire_department_outlined,
                    iconColor: AppColors.terracotta,
                    value: controller.totalCravingsLogged,
                    label: 'Total Cravings\nLogged',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TrackStatTile(
                    valueKey: const Key('track_resisted_tile'),
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.sageDark,
                    value: ((controller.resistedPercent ?? 0) * 100).round(),
                    formatter: (v) => controller.resistedPercent == null ? '-' : '$v%',
                    label: 'Cravings\nResisted',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TrackStatTile(
                    valueKey: const Key('track_longest_streak_tile'),
                    icon: Icons.emoji_events_outlined,
                    iconColor: AppColors.terracotta,
                    value: controller.longestStreakDays,
                    formatter: (v) => '$v day${v == 1 ? '' : 's'}',
                    label: 'Longest\nStreak',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(index: 2, parent: _entranceController, child: TriggerBreakdownCard(counts: controller.triggerBreakdown)),
          const SizedBox(height: 16),
          StaggeredEntrance(index: 3, parent: _entranceController, child: RecentActivityCard(items: controller.recentActivity)),
        ],
      ),
    );
  }
}
```

*(Note: the test above pumps immediately with `pumpAndSettle`, which will wait through both the async `loadTrack` microtask and the entrance animation — same pattern already proven in `dashboard_screen_test.dart`.)*

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/track/track_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full test suite and commit**

Run: `flutter test`

```bash
git add mobile/lib/screens/track/track_screen.dart mobile/test/screens/track/track_screen_test.dart
git commit -m "feat(track): add TrackScreen"
```

---

## Task 18: Wire DashboardScreen to Track/Profile and add onLogout

**Files:**
- Modify: `mobile/lib/screens/dashboard/dashboard_screen.dart`
- Modify: `mobile/test/screens/dashboard_screen_test.dart` (all 22 call sites)

**Interfaces:**
- Consumes: `TrackScreen`/`TrackController` (Tasks 10, 17), `ProfileScreen`/`ProfileController` (Tasks 8, 12).
- Produces: `DashboardScreen` now additionally requires `trackController`, `profileController`, `onLogout`.

- [ ] **Step 1: Add the new required params and wiring to DashboardScreen**

In `mobile/lib/screens/dashboard/dashboard_screen.dart`:

```dart
import '../../controllers/profile_controller.dart';
import '../../controllers/track_controller.dart';
import '../profile/profile_screen.dart';
import '../track/track_screen.dart';
// ...

class DashboardScreen extends StatefulWidget {
  final String userId;
  final DashboardController controller;
  // ...existing fields...
  final TrackController trackController;
  final ProfileController profileController;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.controller,
    // ...existing required params...
    required this.trackController,
    required this.profileController,
    required this.onLogout,
  });
  // ...
```

In `build()`'s `bottomNavigationBar`:

```dart
      bottomNavigationBar: DashboardBottomNav(
        onHealthBotTap: () => _openHealthBot(context),
        onCommunityTap: () => _openCommunity(context),
        onTrackTap: () => _openTrack(context),
        onProfileTap: () => _openProfile(context),
      ),
```

New methods alongside the other `_open*` methods:

```dart
  void _openTrack(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackScreen(userId: widget.userId, trackController: widget.trackController, dashboardController: widget.controller),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: widget.userId,
          dashboardController: widget.controller,
          profileController: widget.profileController,
          aiPlanController: widget.aiPlanController,
          reminderController: widget.reminderController,
          gamificationController: widget.gamificationController,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }
```

(`aiPlanController`, `reminderController`, `gamificationController` are already existing `DashboardScreen` fields per Task 12's resolved `ProfileScreen` signature — no new params needed for those three, only the three listed above.)

- [ ] **Step 2: Update all 22 call sites in dashboard_screen_test.dart**

Add the following near the top of the test file's helper functions (alongside `buildController`, `buildCravingLogController`, etc.):

```dart
  TrackController buildTrackController() {
    return TrackController(FakeCravingLogRepository(), FakeJournalRepository(), FakeUserRepository());
  }

  ProfileController buildProfileController() {
    return ProfileController(FakeUserRepository());
  }
```

Add the two new imports: `import 'package:quit_companion/controllers/profile_controller.dart';` and `import 'package:quit_companion/controllers/track_controller.dart';`.

Then, since every one of the 22 `DashboardScreen(...)` constructions in this file ends with the identical line `reminderController: buildReminderController(),`, use a single find-and-replace-all across the file changing:

```
reminderController: buildReminderController(),
        ),
```

to:

```
reminderController: buildReminderController(),
          trackController: buildTrackController(),
          profileController: buildProfileController(),
          onLogout: () {},
        ),
```

(Match the file's actual existing indentation exactly — confirm by reading a couple of the 22 call sites first, since indentation may vary slightly between single-line and multi-line test bodies.)

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS — this also resolves the compile failure Task 7 deliberately left behind.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/screens/dashboard/dashboard_screen.dart mobile/test/screens/dashboard_screen_test.dart
git commit -m "feat(dashboard): wire Track/Profile navigation and onLogout"
```

---

## Task 19: Wire main.dart (providers + onLogout)

**Files:**
- Modify: `mobile/lib/main.dart`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Add the two new providers**

In the `MultiProvider`'s `providers` list in `mobile/lib/main.dart`, add (near the other craving/journal/user-backed controllers):

```dart
        ChangeNotifierProvider(
          create: (_) => TrackController(resolvedCravingLogRepository, resolvedJournalRepository, resolvedUserRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileController(resolvedUserRepository),
        ),
```

Add imports: `import 'controllers/profile_controller.dart';` and `import 'controllers/track_controller.dart';`.

- [ ] **Step 2: Pass them into DashboardScreen and wire onLogout**

In `_buildStep`'s `case _Step.loggedIn:`:

```dart
      case _Step.loggedIn:
        return DashboardScreen(
          userId: _loggedInUserId ?? '',
          controller: context.read<DashboardController>(),
          cravingLogController: context.read<CravingLogController>(),
          aiPlanController: context.read<AiPlanController>(),
          journalController: context.read<JournalController>(),
          relapseController: context.read<RelapseController>(),
          healthBotController: context.read<HealthBotController>(),
          alternativesController: context.read<AlternativesController>(),
          gamificationController: context.read<GamificationController>(),
          communityController: context.read<CommunityController>(),
          knowledgeHubController: context.read<KnowledgeHubController>(),
          reminderController: context.read<ReminderController>(),
          trackController: context.read<TrackController>(),
          profileController: context.read<ProfileController>(),
          onLogout: () async {
            await context.read<AuthController>().logout();
            setState(() => _step = _Step.welcome);
          },
        );
```

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Manually verify on a device/emulator (per this project's UI-change convention)**

Run: `flutter run` (from `mobile/`), sign in, and confirm:
- Tapping Track opens the Track screen with real stats and an animated chart/bars.
- Tapping Profile opens the Profile screen showing the signed-in user's name and the correct-gender avatar.
- Editing the name in Profile updates the Dashboard's greeting after returning.
- Log Out returns to the Welcome screen.
- Home, Health-Bot, and Community still work exactly as before.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/main.dart
git commit -m "feat(dashboard): register TrackController/ProfileController and wire logout"
```

---

## Self-Review Notes

- **Spec coverage:** Every §1-§5 item in the design spec maps to a task above — data model (Task 1), navigation (Tasks 7, 18-19), Track (Tasks 9-10, 15-17), Profile (Tasks 8, 11-14), animation/polish (Tasks 6, 15-17 all use `TweenAnimationBuilder`/`StaggeredEntrance`), testing (a test file in every task).
- **Type consistency:** `TrackActivityItem`, `TrackStatus`, `ProfileEditStatus`, `Gender` are each defined exactly once (Tasks 1, 8, 10) and referenced with identical names/shapes in every later task.
- **Known follow-up baked into Task 12:** `ProfileScreen`'s real signature needs three more controller params than its first sketch shows (`aiPlanController`, `reminderController`, `gamificationController`) — called out explicitly inline rather than silently glossed over, since `WeeklyPlanScreen`/`ReminderSettingsScreen`/`RewardsScreen` all require their own controllers that `ProfileScreen` has no other way to obtain.
- **Task 10's test:** the longest-streak expected value needs hand-verification against `computeLongestStreakDays`'s real output (flagged inline as `23`, not `12`) — confirm this arithmetic when writing the test, don't copy the flagged parenthetical into the file.

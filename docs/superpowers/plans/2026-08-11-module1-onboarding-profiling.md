# Module 1 — User Onboarding & Profiling — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first vertical slice of Quit-Companion per SDD `docs/Quit_Companion_SDD.md` §2.1 Module 1 (Sukaina, "User Onboarding & Profiling"): a user can register/login (FR1), give explicit consent (FR15), enter onboarding profile data (FR2), and select a Quit Strategy that computes and persists a Quit Day / reduction schedule (FR3, §7.1).

**Architecture:** Flutter client only (per SDD §2 — Firebase/FastAPI backend unchanged). Layered: pure-Dart `models` + `domain` (no Flutter/Firebase deps, fully unit-testable) → `data` repository interfaces with an in-memory `Fake*` implementation used everywhere in this phase, and a `Firebase*` implementation written against the same interface but **not wired into the app** until real Firebase project credentials exist (see Global Constraints) → `controllers` (ChangeNotifier) → `screens` (Provider-wired widgets).

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5 (already installed, verified via `flutter --version`), `provider` for state management (no state-management choice specified in SDD; provider is the minimal, Flutter-team-recommended option). `firebase_core`/`firebase_auth`/`cloud_firestore` added as dependencies for the Firebase-backed repositories but not initialized/wired in `main.dart` this phase.

## Global Constraints

- Product type restricted to Vape, Cigarettes, or Pouches only — no Hookah (SDD FR2).
- No system-assumed default duration for Gradual/Date-Based; `selectedTargetDate` is always required from the user (SDD FR3, §7.1).
- `reductionSchedule` is GRADUAL-only, a linear taper from `baselineDailyUsage` to 0 by `quitDate` (SDD §6).
- Canonical entity name is `NicotineUser` (SDD §6) — the Dart class is named `NicotineUser`, not `User`.
- FR15 consent must occur before profile data (FR2) is collected — this phase places the Consent screen immediately after account registration/login and before the onboarding data screen.
- **Known blocker, not resolved in this phase:** live Firebase Auth/Firestore requires a real Firebase project (`flutterfire configure`, API keys). No such project exists yet. This phase builds `FirebaseAuthRepository`/`FirestoreUserRepository` against the same interfaces as the fakes so they can be dropped in later without touching controllers/screens, but `main.dart` wires the fakes by default. This is flagged to the user in the final report, not silently worked around.
- Do not modify `docs/Quit_Companion_SDD.md` or other requirements docs in this plan.

---

## File Structure

```
mobile/                              # Flutter client (new top-level folder)
  pubspec.yaml
  lib/
    main.dart                        # MultiProvider root, wires Fake repos, drives the flow
    models/
      product_type.dart              # enum ProductType
      quit_strategy.dart             # enum QuitStrategy
      nicotine_user.dart             # NicotineUser entity (SDD §6)
    domain/
      quit_date_calculator.dart      # Determine_Quit_Date + linear taper (SDD §7.1)
    data/
      auth_repository.dart           # AuthRepository interface + AuthException
      fake_auth_repository.dart
      firebase_auth_repository.dart  # not wired into main.dart this phase
      user_repository.dart           # UserRepository interface
      fake_user_repository.dart
      firestore_user_repository.dart # not wired into main.dart this phase
    controllers/
      auth_controller.dart           # FR1: register/login validation + state
      onboarding_controller.dart     # FR2/FR3/FR15: profile + consent + quit-strategy submit
    screens/
      consent/consent_screen.dart            # FR15
      auth/register_screen.dart              # FR1
      auth/login_screen.dart                 # FR1
      onboarding/onboarding_data_screen.dart # FR2
      onboarding/quit_strategy_screen.dart   # FR3
      onboarding/onboarding_complete_screen.dart
  test/
    models/nicotine_user_test.dart
    domain/quit_date_calculator_test.dart
    controllers/auth_controller_test.dart
    controllers/onboarding_controller_test.dart
    screens/consent_screen_test.dart
    screens/register_screen_test.dart
    screens/quit_strategy_screen_test.dart
    app_flow_test.dart                       # end-to-end: register -> consent -> profile -> strategy -> complete
```

---

### Task 1: Flutter project scaffold

**Files:**
- Create: `mobile/` (via `flutter create`)

**Interfaces:** None (infrastructure only).

- [x] **Step 1: Create the Flutter project**

Run from the repo root:
```bash
flutter create --project-name quit_companion --org com.quitcompanion --platforms android,ios mobile
```

- [x] **Step 2: Remove the default counter-app template code**

Delete the generated `mobile/lib/main.dart` body and `mobile/test/widget_test.dart` — they'll be replaced by later tasks.

- [x] **Step 3: Add dependencies**

Edit `mobile/pubspec.yaml`, add under `dependencies:`
```yaml
  provider: ^6.1.2
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
```

- [x] **Step 4: Fetch packages**

Run: `cd mobile && flutter pub get`
Expected: resolves without error (network permitting — if pub.dev is unreachable in this environment, note it and proceed; later tasks' unit/widget tests don't require the Firebase packages to be initialized).

- [x] **Step 5: Verify the toolchain works**

Run: `cd mobile && flutter analyze`
Expected: no errors (warnings about the now-empty `main.dart` are fine until Task 9).

---

### Task 2: Domain models (`ProductType`, `QuitStrategy`, `NicotineUser`)

**Files:**
- Create: `mobile/lib/models/product_type.dart`
- Create: `mobile/lib/models/quit_strategy.dart`
- Create: `mobile/lib/models/nicotine_user.dart`
- Test: `mobile/test/models/nicotine_user_test.dart`

**Interfaces:**
- Produces: `enum ProductType { vape, cigarettes, pouches }`; `enum QuitStrategy { coldTurkey, gradual, dateBased }`; `class NicotineUser` with fields `userId, email, productType, baselineDailyUsage, costPerUnit, primaryMotivation, personalChallenges, pastQuitAttempts, hasConsented, quitStrategy, quitDate, reductionSchedule, lastRelapseDate` and a `copyWith(...)` method.

- [x] **Step 1: Write the failing test**

```dart
// mobile/test/models/nicotine_user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/models/nicotine_user.dart';
import 'package:quit_companion/models/product_type.dart';
import 'package:quit_companion/models/quit_strategy.dart';

void main() {
  test('NicotineUser starts with no consent and no strategy by default', () {
    const user = NicotineUser(userId: 'u1', email: 'a@b.com');

    expect(user.hasConsented, isFalse);
    expect(user.quitStrategy, isNull);
    expect(user.quitDate, isNull);
  });

  test('copyWith only overrides the given fields', () {
    const user = NicotineUser(userId: 'u1', email: 'a@b.com');

    final withProfile = user.copyWith(
      productType: ProductType.cigarettes,
      baselineDailyUsage: 10,
      costPerUnit: 25,
    );

    expect(withProfile.userId, 'u1');
    expect(withProfile.email, 'a@b.com');
    expect(withProfile.productType, ProductType.cigarettes);
    expect(withProfile.baselineDailyUsage, 10);
    expect(withProfile.costPerUnit, 25);
    expect(withProfile.hasConsented, isFalse);

    final withConsent = withProfile.copyWith(hasConsented: true);
    expect(withConsent.hasConsented, isTrue);
    expect(withConsent.productType, ProductType.cigarettes); // unrelated fields preserved

    final withStrategy = withConsent.copyWith(
      quitStrategy: QuitStrategy.gradual,
      quitDate: DateTime(2026, 9, 1),
      reductionSchedule: {DateTime(2026, 8, 20): 5.0},
    );
    expect(withStrategy.quitStrategy, QuitStrategy.gradual);
    expect(withStrategy.quitDate, DateTime(2026, 9, 1));
    expect(withStrategy.reductionSchedule, {DateTime(2026, 8, 20): 5.0});
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/models/nicotine_user_test.dart`
Expected: FAIL — `package:quit_companion/models/nicotine_user.dart` not found.

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/models/product_type.dart
enum ProductType { vape, cigarettes, pouches }
```

```dart
// mobile/lib/models/quit_strategy.dart
enum QuitStrategy { coldTurkey, gradual, dateBased }
```

```dart
// mobile/lib/models/nicotine_user.dart
import 'product_type.dart';
import 'quit_strategy.dart';

/// Canonical entity name per SDD §6 (resolves SRDS's User/NicotineUser naming conflict).
class NicotineUser {
  final String userId;
  final String email;
  final ProductType? productType;
  final double? baselineDailyUsage;
  final double? costPerUnit;
  final String? primaryMotivation;
  final String? personalChallenges;
  final String? pastQuitAttempts;
  final bool hasConsented;
  final QuitStrategy? quitStrategy;
  final DateTime? quitDate;
  final Map<DateTime, double>? reductionSchedule;
  final DateTime? lastRelapseDate;

  const NicotineUser({
    required this.userId,
    required this.email,
    this.productType,
    this.baselineDailyUsage,
    this.costPerUnit,
    this.primaryMotivation,
    this.personalChallenges,
    this.pastQuitAttempts,
    this.hasConsented = false,
    this.quitStrategy,
    this.quitDate,
    this.reductionSchedule,
    this.lastRelapseDate,
  });

  NicotineUser copyWith({
    ProductType? productType,
    double? baselineDailyUsage,
    double? costPerUnit,
    String? primaryMotivation,
    String? personalChallenges,
    String? pastQuitAttempts,
    bool? hasConsented,
    QuitStrategy? quitStrategy,
    DateTime? quitDate,
    Map<DateTime, double>? reductionSchedule,
    DateTime? lastRelapseDate,
  }) {
    return NicotineUser(
      userId: userId,
      email: email,
      productType: productType ?? this.productType,
      baselineDailyUsage: baselineDailyUsage ?? this.baselineDailyUsage,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      primaryMotivation: primaryMotivation ?? this.primaryMotivation,
      personalChallenges: personalChallenges ?? this.personalChallenges,
      pastQuitAttempts: pastQuitAttempts ?? this.pastQuitAttempts,
      hasConsented: hasConsented ?? this.hasConsented,
      quitStrategy: quitStrategy ?? this.quitStrategy,
      quitDate: quitDate ?? this.quitDate,
      reductionSchedule: reductionSchedule ?? this.reductionSchedule,
      lastRelapseDate: lastRelapseDate ?? this.lastRelapseDate,
    );
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/models/nicotine_user_test.dart`
Expected: PASS (2 tests)

---

### Task 3: `QuitDateCalculator` — SDD §7.1 `Determine_Quit_Date` + linear taper

**Files:**
- Create: `mobile/lib/domain/quit_date_calculator.dart`
- Test: `mobile/test/domain/quit_date_calculator_test.dart`

**Interfaces:**
- Consumes: `QuitStrategy` (Task 2).
- Produces: `class QuitDateCalculator` with constructor `QuitDateCalculator({DateTime Function()? now})` and method `({DateTime quitDate, Map<DateTime, double>? reductionSchedule}) determineQuitDate({required QuitStrategy quitStrategy, required double baselineDailyUsage, DateTime? selectedTargetDate})`. Throws `ArgumentError` when `selectedTargetDate` is missing or not strictly after today.

- [x] **Step 1: Write the failing test**

```dart
// mobile/test/domain/quit_date_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/domain/quit_date_calculator.dart';
import 'package:quit_companion/models/quit_strategy.dart';

void main() {
  final fixedToday = DateTime(2026, 8, 11);
  QuitDateCalculator calculator() => QuitDateCalculator(now: () => fixedToday);

  test('COLD_TURKEY sets quitDate to today and no reduction schedule', () {
    final result = calculator().determineQuitDate(
      quitStrategy: QuitStrategy.coldTurkey,
      baselineDailyUsage: 10,
    );

    expect(result.quitDate, fixedToday);
    expect(result.reductionSchedule, isNull);
  });

  test('DATE_BASED requires selectedTargetDate', () {
    expect(
      () => calculator().determineQuitDate(
        quitStrategy: QuitStrategy.dateBased,
        baselineDailyUsage: 10,
      ),
      throwsArgumentError,
    );
  });

  test('DATE_BASED rejects a target date that is not in the future', () {
    expect(
      () => calculator().determineQuitDate(
        quitStrategy: QuitStrategy.dateBased,
        baselineDailyUsage: 10,
        selectedTargetDate: fixedToday,
      ),
      throwsArgumentError,
    );
  });

  test('DATE_BASED uses the selected date with no reduction schedule', () {
    final target = DateTime(2026, 9, 1);
    final result = calculator().determineQuitDate(
      quitStrategy: QuitStrategy.dateBased,
      baselineDailyUsage: 10,
      selectedTargetDate: target,
    );

    expect(result.quitDate, target);
    expect(result.reductionSchedule, isNull);
  });

  test('GRADUAL requires selectedTargetDate', () {
    expect(
      () => calculator().determineQuitDate(
        quitStrategy: QuitStrategy.gradual,
        baselineDailyUsage: 10,
      ),
      throwsArgumentError,
    );
  });

  test('GRADUAL builds a linear taper from baseline to 0 by quitDate', () {
    final target = fixedToday.add(const Duration(days: 5));
    final result = calculator().determineQuitDate(
      quitStrategy: QuitStrategy.gradual,
      baselineDailyUsage: 10,
      selectedTargetDate: target,
    );

    expect(result.quitDate, target);
    final schedule = result.reductionSchedule!;
    expect(schedule.length, 6); // day 0 (today) through day 5 (quitDate), inclusive
    expect(schedule[fixedToday], 10.0);
    expect(schedule[fixedToday.add(const Duration(days: 1))], 8.0);
    expect(schedule[target], 0.0);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/domain/quit_date_calculator_test.dart`
Expected: FAIL — file not found.

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/domain/quit_date_calculator.dart
import '../models/quit_strategy.dart';

/// Implements SDD §7.1 Determine_Quit_Date and the linear-taper
/// reductionSchedule described in SDD §6 (GRADUAL only).
class QuitDateCalculator {
  final DateTime Function() now;

  QuitDateCalculator({DateTime Function()? now}) : now = now ?? DateTime.now;

  ({DateTime quitDate, Map<DateTime, double>? reductionSchedule}) determineQuitDate({
    required QuitStrategy quitStrategy,
    required double baselineDailyUsage,
    DateTime? selectedTargetDate,
  }) {
    final today = _dateOnly(now());
    switch (quitStrategy) {
      case QuitStrategy.coldTurkey:
        return (quitDate: today, reductionSchedule: null);
      case QuitStrategy.dateBased:
        final target = _requireFutureTargetDate(selectedTargetDate, today);
        return (quitDate: target, reductionSchedule: null);
      case QuitStrategy.gradual:
        final target = _requireFutureTargetDate(selectedTargetDate, today);
        final schedule = _buildLinearTaper(baselineDailyUsage, today, target);
        return (quitDate: target, reductionSchedule: schedule);
    }
  }

  DateTime _requireFutureTargetDate(DateTime? selectedTargetDate, DateTime today) {
    if (selectedTargetDate == null) {
      throw ArgumentError(
        'selectedTargetDate is required for this quit strategy — no default duration exists (SDD FR3).',
      );
    }
    final target = _dateOnly(selectedTargetDate);
    if (!target.isAfter(today)) {
      throw ArgumentError('selectedTargetDate must be after today.');
    }
    return target;
  }

  Map<DateTime, double> _buildLinearTaper(double baselineDailyUsage, DateTime today, DateTime quitDate) {
    final totalDays = quitDate.difference(today).inDays;
    final schedule = <DateTime, double>{};
    for (var d = 0; d <= totalDays; d++) {
      final date = today.add(Duration(days: d));
      schedule[date] = baselineDailyUsage * (totalDays - d) / totalDays;
    }
    return schedule;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/domain/quit_date_calculator_test.dart`
Expected: PASS (6 tests)

---

### Task 4: Repository interfaces + fakes (`AuthRepository`, `UserRepository`)

**Files:**
- Create: `mobile/lib/data/auth_repository.dart`
- Create: `mobile/lib/data/fake_auth_repository.dart`
- Create: `mobile/lib/data/user_repository.dart`
- Create: `mobile/lib/data/fake_user_repository.dart`

**Interfaces:**
- Produces: `abstract class AuthRepository { Future<String> registerWithEmailPassword({required String email, required String password}); Future<String> loginWithEmailPassword({required String email, required String password}); Future<void> logout(); String? get currentUserId; }`, `class AuthException implements Exception { final String message; }`, `class FakeAuthRepository implements AuthRepository`, `abstract class UserRepository { Future<void> saveUser(NicotineUser user); Future<NicotineUser?> getUser(String userId); }`, `class FakeUserRepository implements UserRepository`.

No standalone test file for this task — these are exercised through the controller tests in Tasks 5–6 (that's where their contract matters). This is infrastructure with no independent business logic to unit-test in isolation.

- [x] **Step 1: Write `auth_repository.dart` and `fake_auth_repository.dart`**

```dart
// mobile/lib/data/auth_repository.dart
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<String> registerWithEmailPassword({required String email, required String password});
  Future<String> loginWithEmailPassword({required String email, required String password});
  Future<void> logout();
  String? get currentUserId;
}
```

```dart
// mobile/lib/data/fake_auth_repository.dart
import 'auth_repository.dart';

/// In-memory AuthRepository for tests and for running the app before a
/// real Firebase project exists. Not wired into main.dart in production.
class FakeAuthRepository implements AuthRepository {
  final Map<String, String> _users = {};
  String? _currentUserId;

  @override
  Future<String> registerWithEmailPassword({required String email, required String password}) async {
    if (_users.containsKey(email)) {
      throw AuthException('An account with this email already exists.');
    }
    _users[email] = password;
    _currentUserId = email;
    return email;
  }

  @override
  Future<String> loginWithEmailPassword({required String email, required String password}) async {
    if (_users[email] != password) {
      throw AuthException('Invalid email or password.');
    }
    _currentUserId = email;
    return email;
  }

  @override
  Future<void> logout() async {
    _currentUserId = null;
  }

  @override
  String? get currentUserId => _currentUserId;
}
```

- [x] **Step 2: Write `user_repository.dart` and `fake_user_repository.dart`**

```dart
// mobile/lib/data/user_repository.dart
import '../models/nicotine_user.dart';

abstract class UserRepository {
  Future<void> saveUser(NicotineUser user);
  Future<NicotineUser?> getUser(String userId);
}
```

```dart
// mobile/lib/data/fake_user_repository.dart
import '../models/nicotine_user.dart';
import 'user_repository.dart';

class FakeUserRepository implements UserRepository {
  final Map<String, NicotineUser> _store = {};

  @override
  Future<void> saveUser(NicotineUser user) async {
    _store[user.userId] = user;
  }

  @override
  Future<NicotineUser?> getUser(String userId) async {
    return _store[userId];
  }
}
```

- [x] **Step 3: Run analyzer to confirm no errors**

Run: `cd mobile && flutter analyze lib/data`
Expected: no errors.

---

### Task 5: `AuthController` (FR1)

**Files:**
- Create: `mobile/lib/controllers/auth_controller.dart`
- Test: `mobile/test/controllers/auth_controller_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthException`, `FakeAuthRepository` (Task 4).
- Produces: `enum AuthStatus { idle, loading, success, error }`; `class AuthController extends ChangeNotifier` with constructor `AuthController(AuthRepository)`, fields `status`, `errorMessage`, `userId`, methods `String? validateEmail(String)`, `String? validatePassword(String)`, `Future<bool> register({required String email, required String password})`, `Future<bool> login({required String email, required String password})`.

- [x] **Step 1: Write the failing test**

```dart
// mobile/test/controllers/auth_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/auth_controller.dart';
import 'package:quit_companion/data/fake_auth_repository.dart';

void main() {
  test('register fails validation for a malformed email', () async {
    final controller = AuthController(FakeAuthRepository());

    final success = await controller.register(email: 'not-an-email', password: 'password123');

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  test('register fails validation for a short password', () async {
    final controller = AuthController(FakeAuthRepository());

    final success = await controller.register(email: 'a@b.com', password: 'short');

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
  });

  test('register succeeds with valid credentials', () async {
    final controller = AuthController(FakeAuthRepository());

    final success = await controller.register(email: 'a@b.com', password: 'password123');

    expect(success, isTrue);
    expect(controller.status, AuthStatus.success);
    expect(controller.userId, 'a@b.com');
  });

  test('register surfaces a duplicate-account error from the repository', () async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmailPassword(email: 'a@b.com', password: 'password123');
    final controller = AuthController(repo);

    final success = await controller.register(email: 'a@b.com', password: 'password123');

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
    expect(controller.errorMessage, contains('already exists'));
  });

  test('login succeeds with matching credentials', () async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmailPassword(email: 'a@b.com', password: 'password123');
    final controller = AuthController(repo);

    final success = await controller.login(email: 'a@b.com', password: 'password123');

    expect(success, isTrue);
    expect(controller.userId, 'a@b.com');
  });

  test('login fails with wrong password', () async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmailPassword(email: 'a@b.com', password: 'password123');
    final controller = AuthController(repo);

    final success = await controller.login(email: 'a@b.com', password: 'wrong-password');

    expect(success, isFalse);
    expect(controller.status, AuthStatus.error);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/controllers/auth_controller_test.dart`
Expected: FAIL — file not found.

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/controllers/auth_controller.dart
import 'package:flutter/foundation.dart';
import '../data/auth_repository.dart';

enum AuthStatus { idle, loading, success, error }

/// FR1: registration/login validation and state, backed by an AuthRepository.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthController(this._authRepository);

  AuthStatus status = AuthStatus.idle;
  String? errorMessage;
  String? userId;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? validateEmail(String email) {
    if (email.trim().isEmpty) return 'Email is required.';
    if (!_emailPattern.hasMatch(email.trim())) return 'Enter a valid email address.';
    return null;
  }

  String? validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  Future<bool> register({required String email, required String password}) async {
    final validationError = validateEmail(email) ?? validatePassword(password);
    if (validationError != null) {
      errorMessage = validationError;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      userId = await _authRepository.registerWithEmailPassword(email: email.trim(), password: password);
      status = AuthStatus.success;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final validationError = validateEmail(email);
    if (validationError != null) {
      errorMessage = validationError;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      userId = await _authRepository.loginWithEmailPassword(email: email.trim(), password: password);
      status = AuthStatus.success;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/controllers/auth_controller_test.dart`
Expected: PASS (6 tests)

---

### Task 6: `OnboardingController` (FR2, FR3, FR15)

**Files:**
- Create: `mobile/lib/controllers/onboarding_controller.dart`
- Test: `mobile/test/controllers/onboarding_controller_test.dart`

**Interfaces:**
- Consumes: `UserRepository`, `FakeUserRepository` (Task 4); `QuitDateCalculator` (Task 3); `NicotineUser`, `ProductType`, `QuitStrategy` (Task 2).
- Produces: `enum OnboardingStatus { idle, loading, success, error }`; `class OnboardingController extends ChangeNotifier` with constructor `OnboardingController(UserRepository, QuitDateCalculator)`, methods `void startOnboarding({required String userId, required String email})`, `void recordConsent(bool)`, `void recordProfile({required ProductType productType, required double baselineDailyUsage, required double costPerUnit, String? primaryMotivation, String? personalChallenges, String? pastQuitAttempts})`, `Future<bool> submitQuitStrategy({required QuitStrategy quitStrategy, DateTime? selectedTargetDate})`, getter `NicotineUser? get workingUser`.

- [x] **Step 1: Write the failing test**

```dart
// mobile/test/controllers/onboarding_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/controllers/onboarding_controller.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/domain/quit_date_calculator.dart';
import 'package:quit_companion/models/product_type.dart';
import 'package:quit_companion/models/quit_strategy.dart';

void main() {
  final fixedToday = DateTime(2026, 8, 11);

  OnboardingController buildController() {
    return OnboardingController(
      FakeUserRepository(),
      QuitDateCalculator(now: () => fixedToday),
    );
  }

  test('submitQuitStrategy fails without consent', () async {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com')
      ..recordProfile(productType: ProductType.cigarettes, baselineDailyUsage: 10, costPerUnit: 25);

    final success = await controller.submitQuitStrategy(quitStrategy: QuitStrategy.coldTurkey);

    expect(success, isFalse);
    expect(controller.status, OnboardingStatus.error);
    expect(controller.errorMessage, contains('Consent'));
  });

  test('full flow: consent -> profile -> COLD_TURKEY strategy persists a NicotineUser', () async {
    final repo = FakeUserRepository();
    final controller = OnboardingController(repo, QuitDateCalculator(now: () => fixedToday))
      ..startOnboarding(userId: 'u1', email: 'a@b.com')
      ..recordConsent(true)
      ..recordProfile(
        productType: ProductType.vape,
        baselineDailyUsage: 15,
        costPerUnit: 2.5,
        primaryMotivation: 'health',
      );

    final success = await controller.submitQuitStrategy(quitStrategy: QuitStrategy.coldTurkey);

    expect(success, isTrue);
    expect(controller.status, OnboardingStatus.success);
    expect(controller.workingUser!.quitDate, fixedToday);
    expect(controller.workingUser!.quitStrategy, QuitStrategy.coldTurkey);

    final saved = await repo.getUser('u1');
    expect(saved, isNotNull);
    expect(saved!.productType, ProductType.vape);
    expect(saved.hasConsented, isTrue);
  });

  test('GRADUAL strategy without a target date surfaces the calculator error', () async {
    final controller = buildController()
      ..startOnboarding(userId: 'u1', email: 'a@b.com')
      ..recordConsent(true)
      ..recordProfile(productType: ProductType.pouches, baselineDailyUsage: 8, costPerUnit: 1.2);

    final success = await controller.submitQuitStrategy(quitStrategy: QuitStrategy.gradual);

    expect(success, isFalse);
    expect(controller.status, OnboardingStatus.error);
  });

  test('submitQuitStrategy throws if called before startOnboarding', () {
    final controller = buildController();

    expect(
      () => controller.submitQuitStrategy(quitStrategy: QuitStrategy.coldTurkey),
      throwsStateError,
    );
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/controllers/onboarding_controller_test.dart`
Expected: FAIL — file not found.

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/controllers/onboarding_controller.dart
import 'package:flutter/foundation.dart';
import '../data/user_repository.dart';
import '../domain/quit_date_calculator.dart';
import '../models/nicotine_user.dart';
import '../models/product_type.dart';
import '../models/quit_strategy.dart';

enum OnboardingStatus { idle, loading, success, error }

/// FR2 (profile), FR3 (quit strategy / Quit Day, via QuitDateCalculator),
/// FR15 (consent gate) for Module 1.
class OnboardingController extends ChangeNotifier {
  final UserRepository _userRepository;
  final QuitDateCalculator _quitDateCalculator;

  OnboardingController(this._userRepository, this._quitDateCalculator);

  NicotineUser? _workingUser;
  NicotineUser? get workingUser => _workingUser;

  OnboardingStatus status = OnboardingStatus.idle;
  String? errorMessage;

  void startOnboarding({required String userId, required String email}) {
    _workingUser = NicotineUser(userId: userId, email: email);
  }

  void recordConsent(bool consented) {
    _workingUser = _requireWorkingUser().copyWith(hasConsented: consented);
  }

  void recordProfile({
    required ProductType productType,
    required double baselineDailyUsage,
    required double costPerUnit,
    String? primaryMotivation,
    String? personalChallenges,
    String? pastQuitAttempts,
  }) {
    _workingUser = _requireWorkingUser().copyWith(
      productType: productType,
      baselineDailyUsage: baselineDailyUsage,
      costPerUnit: costPerUnit,
      primaryMotivation: primaryMotivation,
      personalChallenges: personalChallenges,
      pastQuitAttempts: pastQuitAttempts,
    );
  }

  Future<bool> submitQuitStrategy({
    required QuitStrategy quitStrategy,
    DateTime? selectedTargetDate,
  }) async {
    final user = _requireWorkingUser();
    if (!user.hasConsented) {
      errorMessage = 'Consent is required before onboarding can be completed.';
      status = OnboardingStatus.error;
      notifyListeners();
      return false;
    }
    status = OnboardingStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final result = _quitDateCalculator.determineQuitDate(
        quitStrategy: quitStrategy,
        baselineDailyUsage: user.baselineDailyUsage ?? 0,
        selectedTargetDate: selectedTargetDate,
      );
      _workingUser = user.copyWith(
        quitStrategy: quitStrategy,
        quitDate: result.quitDate,
        reductionSchedule: result.reductionSchedule,
      );
      await _userRepository.saveUser(_workingUser!);
      status = OnboardingStatus.success;
      notifyListeners();
      return true;
    } on ArgumentError catch (e) {
      errorMessage = e.message.toString();
      status = OnboardingStatus.error;
      notifyListeners();
      return false;
    }
  }

  NicotineUser _requireWorkingUser() {
    final user = _workingUser;
    if (user == null) {
      throw StateError('startOnboarding must be called before using OnboardingController.');
    }
    return user;
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/controllers/onboarding_controller_test.dart`
Expected: PASS (4 tests)

---

### Task 7: `ConsentScreen` (FR15)

**Files:**
- Create: `mobile/lib/screens/consent/consent_screen.dart`
- Test: `mobile/test/screens/consent_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingController` (Task 6), via `provider`.
- Produces: `class ConsentScreen extends StatefulWidget` with constructor `ConsentScreen({required VoidCallback onContinue})`. Keys: `consent_checkbox`, `consent_continue_button`.

- [x] **Step 1: Write the failing test**

```dart
// mobile/test/screens/consent_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/controllers/onboarding_controller.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/domain/quit_date_calculator.dart';
import 'package:quit_companion/screens/consent/consent_screen.dart';

void main() {
  testWidgets('continue button is disabled until the checkbox is checked, then calls onContinue', (tester) async {
    final controller = OnboardingController(FakeUserRepository(), QuitDateCalculator())
      ..startOnboarding(userId: 'u1', email: 'a@b.com');
    var continued = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingController>.value(
        value: controller,
        child: MaterialApp(
          home: ConsentScreen(onContinue: () => continued = true),
        ),
      ),
    );

    final continueButtonFinder = find.byKey(const Key('consent_continue_button'));
    expect(tester.widget<ElevatedButton>(continueButtonFinder).onPressed, isNull);

    await tester.tap(find.byKey(const Key('consent_checkbox')));
    await tester.pump();

    expect(tester.widget<ElevatedButton>(continueButtonFinder).onPressed, isNotNull);

    await tester.tap(continueButtonFinder);
    await tester.pump();

    expect(continued, isTrue);
    expect(controller.workingUser!.hasConsented, isTrue);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/screens/consent_screen_test.dart`
Expected: FAIL — file not found (also add `provider` import works since Task 1 added the dependency).

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/screens/consent/consent_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';

/// FR15: explicit consent before any FR2 profile data is collected.
class ConsentScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const ConsentScreen({super.key, required this.onContinue});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consent & Privacy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before we collect any information about your nicotine use, we need '
              'your explicit consent. Your data will be anonymized and handled in '
              'line with our privacy policy.',
              key: Key('consent_text'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('consent_checkbox'),
              value: _agreed,
              title: const Text('I have read and agree to the data collection terms.'),
              onChanged: (value) => setState(() => _agreed = value ?? false),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('consent_continue_button'),
                onPressed: _agreed
                    ? () {
                        context.read<OnboardingController>().recordConsent(true);
                        widget.onContinue();
                      }
                    : null,
                child: const Text('Agree & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/screens/consent_screen_test.dart`
Expected: PASS (1 test)

---

### Task 8: Auth screens (`RegisterScreen`, `LoginScreen`) (FR1)

**Files:**
- Create: `mobile/lib/screens/auth/register_screen.dart`
- Create: `mobile/lib/screens/auth/login_screen.dart`
- Test: `mobile/test/screens/register_screen_test.dart`

**Interfaces:**
- Consumes: `AuthController` (Task 5), via `provider`.
- Produces: `class RegisterScreen extends StatefulWidget` with constructor `RegisterScreen({required void Function(String userId, String email) onRegistered})`. Keys: `register_email_field`, `register_password_field`, `register_submit_button`, `register_error_text`. `class LoginScreen` mirrors this with an `onLoggedIn` callback and `login_*` keys — same structure, no separate test file (covered by the same AuthController contract Task 5 already tests; only the wiring differs).

- [x] **Step 1: Write the failing test**

```dart
// mobile/test/screens/register_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/controllers/auth_controller.dart';
import 'package:quit_companion/data/fake_auth_repository.dart';
import 'package:quit_companion/screens/auth/register_screen.dart';

void main() {
  testWidgets('submitting valid credentials calls onRegistered with the new userId', (tester) async {
    final controller = AuthController(FakeAuthRepository());
    String? registeredUserId;
    String? registeredEmail;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: RegisterScreen(
            onRegistered: (userId, email) {
              registeredUserId = userId;
              registeredEmail = email;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('register_email_field')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('register_password_field')), 'password123');
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(registeredUserId, 'a@b.com');
    expect(registeredEmail, 'a@b.com');
  });

  testWidgets('shows an error message when registration fails', (tester) async {
    final controller = AuthController(FakeAuthRepository());

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: MaterialApp(
          home: RegisterScreen(onRegistered: (_, __) {}),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('register_email_field')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('register_password_field')), 'password123');
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register_error_text')), findsOneWidget);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/screens/register_screen_test.dart`
Expected: FAIL — file not found.

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  final void Function(String userId, String email) onRegistered;
  const RegisterScreen({super.key, required this.onRegistered});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('register_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              key: const Key('register_password_field'),
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (auth.status == AuthStatus.error && auth.errorMessage != null)
              Text(
                auth.errorMessage!,
                key: const Key('register_error_text'),
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('register_submit_button'),
                onPressed: auth.status == AuthStatus.loading
                    ? null
                    : () async {
                        final authController = context.read<AuthController>();
                        final email = _emailController.text.trim();
                        final success = await authController.register(
                          email: email,
                          password: _passwordController.text,
                        );
                        if (success && context.mounted) {
                          widget.onRegistered(authController.userId!, email);
                        }
                      },
                child: const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// mobile/lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String userId, String email) onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('login_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              key: const Key('login_password_field'),
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (auth.status == AuthStatus.error && auth.errorMessage != null)
              Text(
                auth.errorMessage!,
                key: const Key('login_error_text'),
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('login_submit_button'),
                onPressed: auth.status == AuthStatus.loading
                    ? null
                    : () async {
                        final authController = context.read<AuthController>();
                        final email = _emailController.text.trim();
                        final success = await authController.login(
                          email: email,
                          password: _passwordController.text,
                        );
                        if (success && context.mounted) {
                          widget.onLoggedIn(authController.userId!, email);
                        }
                      },
                child: const Text('Log In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/screens/register_screen_test.dart`
Expected: PASS (2 tests)

---

### Task 9: Onboarding screens (`OnboardingDataScreen` FR2, `QuitStrategyScreen` FR3, `OnboardingCompleteScreen`)

**Files:**
- Create: `mobile/lib/screens/onboarding/onboarding_data_screen.dart`
- Create: `mobile/lib/screens/onboarding/quit_strategy_screen.dart`
- Create: `mobile/lib/screens/onboarding/onboarding_complete_screen.dart`
- Test: `mobile/test/screens/quit_strategy_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingController` (Task 6), `ProductType`, `QuitStrategy` (Task 2).
- Produces: `class OnboardingDataScreen extends StatefulWidget({required VoidCallback onContinue})`, `class QuitStrategyScreen extends StatefulWidget({required VoidCallback onComplete})`, `class OnboardingCompleteScreen extends StatelessWidget()`. Keys on `QuitStrategyScreen`: `strategy_cold_turkey`, `strategy_gradual`, `strategy_date_based`, `strategy_target_date_field`, `strategy_submit_button`, `strategy_error_text`.

- [x] **Step 1: Write the failing test**

```dart
// mobile/test/screens/quit_strategy_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quit_companion/controllers/onboarding_controller.dart';
import 'package:quit_companion/data/fake_user_repository.dart';
import 'package:quit_companion/domain/quit_date_calculator.dart';
import 'package:quit_companion/models/product_type.dart';
import 'package:quit_companion/screens/onboarding/quit_strategy_screen.dart';

void main() {
  testWidgets('selecting COLD_TURKEY and submitting calls onComplete', (tester) async {
    final controller = OnboardingController(FakeUserRepository(), QuitDateCalculator())
      ..startOnboarding(userId: 'u1', email: 'a@b.com')
      ..recordConsent(true)
      ..recordProfile(productType: ProductType.cigarettes, baselineDailyUsage: 10, costPerUnit: 25);
    var completed = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingController>.value(
        value: controller,
        child: MaterialApp(
          home: QuitStrategyScreen(onComplete: () => completed = true),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('strategy_cold_turkey')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('strategy_submit_button')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(controller.workingUser!.quitDate, isNotNull);
  });

  testWidgets('GRADUAL without picking a target date shows an error, not a crash', (tester) async {
    final controller = OnboardingController(FakeUserRepository(), QuitDateCalculator())
      ..startOnboarding(userId: 'u1', email: 'a@b.com')
      ..recordConsent(true)
      ..recordProfile(productType: ProductType.vape, baselineDailyUsage: 10, costPerUnit: 25);

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingController>.value(
        value: controller,
        child: MaterialApp(
          home: QuitStrategyScreen(onComplete: () {}),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('strategy_gradual')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('strategy_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('strategy_error_text')), findsOneWidget);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/screens/quit_strategy_screen_test.dart`
Expected: FAIL — file not found.

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/screens/onboarding/onboarding_data_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';
import '../../models/product_type.dart';

/// FR2: onboarding profile data. Product type restricted to Vape,
/// Cigarettes, or Pouches only — no Hookah.
class OnboardingDataScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const OnboardingDataScreen({super.key, required this.onContinue});

  @override
  State<OnboardingDataScreen> createState() => _OnboardingDataScreenState();
}

class _OnboardingDataScreenState extends State<OnboardingDataScreen> {
  ProductType _productType = ProductType.cigarettes;
  final _baselineController = TextEditingController();
  final _costController = TextEditingController();
  final _motivationController = TextEditingController();
  final _challengesController = TextEditingController();
  final _pastAttemptsController = TextEditingController();

  @override
  void dispose() {
    _baselineController.dispose();
    _costController.dispose();
    _motivationController.dispose();
    _challengesController.dispose();
    _pastAttemptsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tell Us About Your Habit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ProductType>(
            key: const Key('onboarding_product_type_field'),
            initialValue: _productType,
            decoration: const InputDecoration(labelText: 'Product Type'),
            items: const [
              DropdownMenuItem(value: ProductType.vape, child: Text('Vape')),
              DropdownMenuItem(value: ProductType.cigarettes, child: Text('Cigarettes')),
              DropdownMenuItem(value: ProductType.pouches, child: Text('Pouches')),
            ],
            onChanged: (value) => setState(() => _productType = value ?? _productType),
          ),
          TextField(
            key: const Key('onboarding_baseline_field'),
            controller: _baselineController,
            decoration: const InputDecoration(labelText: 'Daily consumption (units/day)'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            key: const Key('onboarding_cost_field'),
            controller: _costController,
            decoration: const InputDecoration(labelText: 'Cost per unit'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            key: const Key('onboarding_motivation_field'),
            controller: _motivationController,
            decoration: const InputDecoration(labelText: 'Primary motivation'),
          ),
          TextField(
            key: const Key('onboarding_challenges_field'),
            controller: _challengesController,
            decoration: const InputDecoration(labelText: 'Personal challenges'),
          ),
          TextField(
            key: const Key('onboarding_past_attempts_field'),
            controller: _pastAttemptsController,
            decoration: const InputDecoration(labelText: 'Past quit attempts'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('onboarding_continue_button'),
            onPressed: () {
              context.read<OnboardingController>().recordProfile(
                    productType: _productType,
                    baselineDailyUsage: double.tryParse(_baselineController.text) ?? 0,
                    costPerUnit: double.tryParse(_costController.text) ?? 0,
                    primaryMotivation: _motivationController.text,
                    personalChallenges: _challengesController.text,
                    pastQuitAttempts: _pastAttemptsController.text,
                  );
              widget.onContinue();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// mobile/lib/screens/onboarding/quit_strategy_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';
import '../../models/quit_strategy.dart';

/// FR3: Quit Strategy selection, driving SDD §7.1's Determine_Quit_Date.
class QuitStrategyScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const QuitStrategyScreen({super.key, required this.onComplete});

  @override
  State<QuitStrategyScreen> createState() => _QuitStrategyScreenState();
}

class _QuitStrategyScreenState extends State<QuitStrategyScreen> {
  QuitStrategy _strategy = QuitStrategy.coldTurkey;
  DateTime? _targetDate;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OnboardingController>();
    final needsTargetDate = _strategy != QuitStrategy.coldTurkey;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Quit Strategy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<QuitStrategy>(
              key: const Key('strategy_cold_turkey'),
              title: const Text('Cold Turkey — quit today'),
              value: QuitStrategy.coldTurkey,
              groupValue: _strategy,
              onChanged: (value) => setState(() => _strategy = value ?? _strategy),
            ),
            RadioListTile<QuitStrategy>(
              key: const Key('strategy_gradual'),
              title: const Text('Gradual — taper down to a target date'),
              value: QuitStrategy.gradual,
              groupValue: _strategy,
              onChanged: (value) => setState(() => _strategy = value ?? _strategy),
            ),
            RadioListTile<QuitStrategy>(
              key: const Key('strategy_date_based'),
              title: const Text('Date-Based — pick a future quit day'),
              value: QuitStrategy.dateBased,
              groupValue: _strategy,
              onChanged: (value) => setState(() => _strategy = value ?? _strategy),
            ),
            if (needsTargetDate)
              TextButton(
                key: const Key('strategy_target_date_field'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _targetDate = picked);
                },
                child: Text(_targetDate == null ? 'Pick a target date' : _targetDate.toString()),
              ),
            const SizedBox(height: 16),
            if (controller.status == OnboardingStatus.error && controller.errorMessage != null)
              Text(
                controller.errorMessage!,
                key: const Key('strategy_error_text'),
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('strategy_submit_button'),
              onPressed: () async {
                final success = await context.read<OnboardingController>().submitQuitStrategy(
                      quitStrategy: _strategy,
                      selectedTargetDate: _targetDate,
                    );
                if (success) widget.onComplete();
              },
              child: const Text('Confirm Quit Strategy'),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// mobile/lib/screens/onboarding/onboarding_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/onboarding_controller.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<OnboardingController>().workingUser;
    return Scaffold(
      appBar: AppBar(title: const Text("You're All Set")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          key: const Key('onboarding_complete_summary'),
          'Your Quit Day is ${user?.quitDate}.'
          '${user?.reductionSchedule != null ? ' Reduction plan: ${user!.reductionSchedule!.length} days.' : ''}',
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/screens/quit_strategy_screen_test.dart`
Expected: PASS (2 tests)

---

### Task 10: `main.dart` — wire the flow end-to-end with fakes

**Files:**
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/app_flow_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 2–9.
- Produces: `void main()` running `QuitCompanionApp`, `class QuitCompanionApp extends StatelessWidget`.

- [x] **Step 1: Write the failing end-to-end test**

```dart
// mobile/test/app_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/main.dart';

void main() {
  testWidgets('register -> consent -> profile -> quit strategy -> complete', (tester) async {
    await tester.pumpWidget(const QuitCompanionApp());

    await tester.enterText(find.byKey(const Key('register_email_field')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('register_password_field')), 'password123');
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent_checkbox')), findsOneWidget);
    await tester.tap(find.byKey(const Key('consent_checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('consent_continue_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding_baseline_field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('onboarding_baseline_field')), '10');
    await tester.enterText(find.byKey(const Key('onboarding_cost_field')), '25');
    await tester.tap(find.byKey(const Key('onboarding_continue_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('strategy_cold_turkey')), findsOneWidget);
    await tester.tap(find.byKey(const Key('strategy_cold_turkey')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('strategy_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding_complete_summary')), findsOneWidget);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/app_flow_test.dart`
Expected: FAIL — `main.dart` has no `QuitCompanionApp`.

- [x] **Step 3: Write the implementation**

```dart
// mobile/lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/onboarding_controller.dart';
import 'data/fake_auth_repository.dart';
import 'data/fake_user_repository.dart';
import 'domain/quit_date_calculator.dart';
import 'screens/auth/register_screen.dart';
import 'screens/consent/consent_screen.dart';
import 'screens/onboarding/onboarding_complete_screen.dart';
import 'screens/onboarding/onboarding_data_screen.dart';
import 'screens/onboarding/quit_strategy_screen.dart';

// NOTE: wires the in-memory Fake* repositories. Swap for FirebaseAuthRepository /
// FirestoreUserRepository (lib/data/firebase_auth_repository.dart,
// firestore_user_repository.dart) once a real Firebase project exists and
// `flutterfire configure` has been run — see docs/Quit_Companion_SDD.md
// Document Control and this plan's Global Constraints.
void main() {
  runApp(const QuitCompanionApp());
}

class QuitCompanionApp extends StatelessWidget {
  const QuitCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(FakeAuthRepository())),
        ChangeNotifierProvider(
          create: (_) => OnboardingController(FakeUserRepository(), QuitDateCalculator()),
        ),
      ],
      child: MaterialApp(
        title: 'Quit Companion',
        home: const _OnboardingFlow(),
      ),
    );
  }
}

enum _Step { register, consent, profile, strategy, complete }

class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow();

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  _Step _step = _Step.register;

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.register:
        return RegisterScreen(
          onRegistered: (userId, email) {
            context.read<OnboardingController>().startOnboarding(userId: userId, email: email);
            setState(() => _step = _Step.consent);
          },
        );
      case _Step.consent:
        return ConsentScreen(onContinue: () => setState(() => _step = _Step.profile));
      case _Step.profile:
        return OnboardingDataScreen(onContinue: () => setState(() => _step = _Step.strategy));
      case _Step.strategy:
        return QuitStrategyScreen(onComplete: () => setState(() => _step = _Step.complete));
      case _Step.complete:
        return const OnboardingCompleteScreen();
    }
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/app_flow_test.dart`
Expected: PASS (1 test)

- [x] **Step 5: Run the full test suite**

Run: `cd mobile && flutter test`
Expected: PASS — all tests from Tasks 2–10 (~22 tests total).

---

### Task 11: Firebase-backed repositories (interface-compatible, not wired in)

**Files:**
- Create: `mobile/lib/data/firebase_auth_repository.dart`
- Create: `mobile/lib/data/firestore_user_repository.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthException` (Task 4), `UserRepository`, `NicotineUser`, `ProductType`, `QuitStrategy` (Tasks 2, 4).
- Produces: `class FirebaseAuthRepository implements AuthRepository`, `class FirestoreUserRepository implements UserRepository`. Not referenced from `main.dart` — swapping them in is a follow-up task once Firebase project credentials exist.

No test file: these classes call `firebase_auth`/`cloud_firestore` APIs directly and cannot be exercised without a real or emulated Firebase project, which is the documented blocker. Their correctness is structural (implementing the same interface the controllers already depend on and are tested against).

- [x] **Step 1: Write `firebase_auth_repository.dart`**

```dart
// mobile/lib/data/firebase_auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'auth_repository.dart';

/// Real Firebase Auth implementation of AuthRepository (FR1). Requires a
/// configured Firebase project (flutterfire configure) before use — not
/// wired into main.dart until that exists.
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository({fb.FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  @override
  Future<String> registerWithEmailPassword({required String email, required String password}) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      return credential.user!.uid;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Registration failed.');
    }
  }

  @override
  Future<String> loginWithEmailPassword({required String email, required String password}) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user!.uid;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Login failed.');
    }
  }

  @override
  Future<void> logout() => _firebaseAuth.signOut();

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;
}
```

- [x] **Step 2: Write `firestore_user_repository.dart`**

```dart
// mobile/lib/data/firestore_user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/nicotine_user.dart';
import '../models/product_type.dart';
import '../models/quit_strategy.dart';
import 'user_repository.dart';

/// Real Firestore implementation of UserRepository, persisting the
/// NicotineUser entity (SDD §6). Requires a configured Firebase project
/// before use — not wired into main.dart until that exists.
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('nicotineUsers');

  @override
  Future<void> saveUser(NicotineUser user) async {
    await _users.doc(user.userId).set({
      'email': user.email,
      'productType': user.productType?.name,
      'baselineDailyUsage': user.baselineDailyUsage,
      'costPerUnit': user.costPerUnit,
      'primaryMotivation': user.primaryMotivation,
      'personalChallenges': user.personalChallenges,
      'pastQuitAttempts': user.pastQuitAttempts,
      'hasConsented': user.hasConsented,
      'quitStrategy': user.quitStrategy?.name,
      'quitDate': user.quitDate?.toIso8601String(),
      'reductionSchedule': user.reductionSchedule?.map(
        (date, target) => MapEntry(date.toIso8601String(), target),
      ),
      'lastRelapseDate': user.lastRelapseDate?.toIso8601String(),
    });
  }

  @override
  Future<NicotineUser?> getUser(String userId) async {
    final doc = await _users.doc(userId).get();
    final data = doc.data();
    if (data == null) return null;

    return NicotineUser(
      userId: userId,
      email: data['email'] as String,
      productType: _parseProductType(data['productType'] as String?),
      baselineDailyUsage: (data['baselineDailyUsage'] as num?)?.toDouble(),
      costPerUnit: (data['costPerUnit'] as num?)?.toDouble(),
      primaryMotivation: data['primaryMotivation'] as String?,
      personalChallenges: data['personalChallenges'] as String?,
      pastQuitAttempts: data['pastQuitAttempts'] as String?,
      hasConsented: data['hasConsented'] as bool? ?? false,
      quitStrategy: _parseQuitStrategy(data['quitStrategy'] as String?),
      quitDate: (data['quitDate'] as String?) != null ? DateTime.parse(data['quitDate'] as String) : null,
      reductionSchedule: (data['reductionSchedule'] as Map<String, dynamic>?)?.map(
        (dateStr, target) => MapEntry(DateTime.parse(dateStr), (target as num).toDouble()),
      ),
      lastRelapseDate:
          (data['lastRelapseDate'] as String?) != null ? DateTime.parse(data['lastRelapseDate'] as String) : null,
    );
  }

  ProductType? _parseProductType(String? name) =>
      name == null ? null : ProductType.values.firstWhere((v) => v.name == name);

  QuitStrategy? _parseQuitStrategy(String? name) =>
      name == null ? null : QuitStrategy.values.firstWhere((v) => v.name == name);
}
```

- [x] **Step 3: Run analyzer to confirm no errors**

Run: `cd mobile && flutter analyze`
Expected: no errors (this task's two files aren't covered by tests, but must compile cleanly against the packages added in Task 1).

- [x] **Step 4: Run the full test suite one more time to confirm nothing broke**

Run: `cd mobile && flutter test`
Expected: PASS — same ~22 tests as Task 10, unaffected by this task.

---

## Self-Review

**Spec coverage:** FR1 → Tasks 5, 8, 11. FR2 → Tasks 2, 6, 9. FR3/§7.1 → Tasks 2, 3, 6, 9. FR15 → Tasks 2, 6, 7. Canonical `NicotineUser` naming (SDD §6) → Task 2. Google/biometric login correctly *not* built (deferred per SDD Document Control) → out of scope, not attempted anywhere in this plan.

**Placeholder scan:** no TBD/TODO-as-a-step; every step has real, complete code. The one inline `// NOTE:` comment in Task 10 documents a genuine follow-up (Firebase credentials), not a deferred implementation detail within this plan's own scope.

**Type consistency:** `NicotineUser`, `ProductType`, `QuitStrategy` (Task 2) are used identically in Tasks 3, 4, 6, 9, 11. `AuthRepository`/`AuthException` (Task 4) match `AuthController`'s usage (Task 5) and `FirebaseAuthRepository` (Task 11). `UserRepository` (Task 4) matches `OnboardingController` (Task 6) and `FirestoreUserRepository` (Task 11). `QuitDateCalculator.determineQuitDate`'s record return type `({DateTime quitDate, Map<DateTime, double>? reductionSchedule})` is used the same way in Task 3's tests and Task 6's `OnboardingController`.

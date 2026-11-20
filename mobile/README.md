# Quit Companion Mobile

This is the Flutter project directory. Open this folder (the one containing `pubspec.yaml`) in Android Studio; do not open only its `android` subfolder. Install the Flutter and Dart plugins if Android Studio prompts you.

## Run from Android Studio

1. Make sure Flutter and the Android SDK are installed. In Android Studio, install an Android SDK platform and create/start an emulator in **Device Manager**, or connect a device with USB debugging.
2. Open this `mobile` folder in Android Studio and wait for dependency sync.
3. Select an emulator/device, open `lib/main.dart`, then click **Run**.

Android Studio's bundled Java runtime is suitable for the Android build. If the IDE reports a missing SDK or license, run `flutter doctor` and follow its Android toolchain instructions.

## Run from PowerShell

From this directory, run:

```powershell
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter emulators
flutter emulators --launch <emulator-id>
flutter run
```

Create an emulator in Android Studio's **Device Manager** if `flutter emulators` does not list one. Firebase is configured for Android. The Android emulator reaches services running on the host machine through `10.0.2.2`, not `localhost`; change the backend URL for a physical device with `--dart-define=OTP_BACKEND_BASE_URL=http://<host-lan-ip>:8000`.

## Check the app

```powershell
flutter analyze
flutter test
flutter build apk
```

## Reminders and FCM

The reminder feature still schedules its daily reminders locally and now also
supports receiving Firebase Cloud Messaging (FCM) notifications. When the user
enables reminders, the notification-permission flow requests OS and FCM
permission, then saves or refreshes that signed-in user's token and selected
notification categories at
`nicotineUsers/{uid}/fcmTokens/{tokenId}`. The user can remove the registered
token by turning reminders off. Token documents are private: Firestore rules
deny client reads and allow only an authenticated user to write under their
own UID. The reminder settings also support local habit and recovery-motivation
prompts. Deploy `mobile/firestore.rules` before expecting token writes to work.

External Firebase/platform setup is still required:

- In Firebase Console, enable Cloud Messaging for the existing Firebase
  project/app and confirm the registered Android application ID matches this
  project. Keep the matching `google-services.json` in `android/app`; Android
  13+ also requires the notification permission prompt (already declared by
  this app). Use a real device or a configured emulator with Google Play
  services for end-to-end delivery.
- For iOS, register the iOS app/bundle ID in Firebase and provide the matching
  `GoogleService-Info.plist`. In Apple Developer, enable Push Notifications for
  the app ID, then upload an APNs authentication key (or valid APNs
  certificate) in Firebase Console → Project settings → Cloud Messaging.
  This checkout currently has no `ios/` target, so first generate/configure the
  Flutter iOS platform target, enable its Push Notifications capability, and
  test on an APNs-configured device.
- The FastAPI backend's trusted scheduler endpoint,
  `POST /notifications/send/{notification_type}`, accepts only
  `daily_checkin`, `habit_reminder`, and `recovery_motivation`. The daily,
  habit, and recovery reminders already run locally at the user's device-local
  times and selected frequency; keep them local to avoid duplicate delivery
  and preserve offline scheduling.
- Badge and restart-plan events use
  `POST /notifications/events/{notification_type}` with the signed-in user's
  Firebase ID token. The backend verifies the token and sends fixed, reviewed
  copy only to that user's opted-in devices. The app triggers these after a
  newly earned badge is saved (milestones are checked on dashboard/rewards
  loads) and after a relapse is logged and a restart plan is created. These
  event sends do not require Cloud Scheduler.
- **Cloud provisioning is still required for real delivery.** Configure
  `FIREBASE_SERVICE_ACCOUNT_JSON` in the backend deployment and deploy the
  backend. `FCM_SCHEDULER_TOKEN` and a Cloud Scheduler job are needed only if
  you intentionally use the scheduler endpoint; do not schedule the same
  categories already delivered locally. Never send secrets to the Flutter app.
  Background notification payloads are displayed by the OS; the app ignores
  data-only background payloads. Foreground notification payloads are shown
  through the existing local-notification plugin.

## Account deletion and biometric unlock

The Privacy & Security screen provides account deletion after the user types
`DELETE`. The mobile app calls the authenticated backend `DELETE /account`
endpoint, then signs out and clears this device's biometric preference and
local reminder settings/schedules. The backend must have
`FIREBASE_SERVICE_ACCOUNT_JSON` configured as a deployment secret; the endpoint
removes the user's private Firestore data and authored community content before
deleting the Firebase Auth account.

Fingerprint sign-in is optional and available for email/password accounts.
Enabling it requires re-entering the current password and confirming with a
fingerprint; the password is then saved in Android encrypted secure storage and
used only after biometric verification. Phone- and Google-provider accounts
cannot use this sign-in path. The biometric preference can also lock an
existing Firebase session after app restart or return from the background.
Android backup is disabled so encrypted local credentials are not copied to
another device. The device prompt and account deletion still require manual
real-device verification.

To enable it, sign in with email/password, open **Profile → Privacy & Security**,
turn on **Fingerprint sign-in**, enter the current password, and approve the
fingerprint prompt. After signing out, choose **Sign in with fingerprint** on
the login screen. The login screen also offers a way to remove saved
credentials from this device. Existing installations must enable the feature
again to explicitly opt in to secure password storage.

## Source layout

- `lib/main.dart` initializes Firebase and starts the app.
- `lib/app/` contains the app composition root and provider setup.
- `lib/core/` contains app-wide configuration and theming.
- `lib/features/<feature>/` keeps each feature's controllers, data access, domain logic, models, and presentation together.
- `lib/shared/` contains utilities and widgets used across features.
- `test/features/<feature>/` mirrors the feature organization for focused tests.

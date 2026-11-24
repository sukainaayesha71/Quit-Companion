# Step 11 — HTTPS release build: implementation record (2026-11-23)

## Requirement and prior state

The SRDS security requirement is transport security (production API traffic over HTTPS). `ANDROID_COMPLETION.md` already recorded "Release Android builds disallow cleartext HTTP; debug USB builds retain localhost HTTP."

Inspected:

| Item | Finding |
| --- | --- |
| `android/app/src/main/AndroidManifest.xml` | `usesCleartextTraffic="false"`. The merged release manifest was verified to keep `false`. |
| debug / profile manifests | `usesCleartextTraffic="true"`, for USB/LAN development only. The merged debug manifest is `true`. |
| `lib/core/config/otp_backend_config.dart` | Backend URL from `--dart-define=OTP_BACKEND_BASE_URL`; default `http://10.0.2.2:8000` (emulator). **A release build without the define would point at HTTP, which the release manifest blocks, so OTP, Health-Bot, risk scoring, plans, notification events and deletion would all fail silently.** |
| Other URLs in `lib/` and Android sources | No other `http://` usage. Firebase SDKs, source links and video links are https. |
| Release signing | Signed with the **debug key** (Flutter template TODO). No keystore and no `key.properties`; they are already git-ignored in `mobile/android/.gitignore`. |
| Production domain | **None configured.** `deploy/.env.example` has only the placeholder `SITE_DOMAIN=your-api-domain.example`, and `deploy/.env` does not exist. The backend's TLS is provided by Caddy (`deploy/Caddyfile`) once a real domain is set. |

## Decisions (project owner, 2026-11-23)

- **Backend URL:** don't invent one. Add a build guard instead; no release APK until the real HTTPS backend URL exists.
- **Signing:** support `android/key.properties`, falling back to the debug key with a warning. The owner creates the keystore; no credentials are invented.

## Changes

`mobile/android/app/build.gradle.kts`:
- **HTTPS release guard.** Any `assembleRelease` / `bundleRelease` / `packageRelease` fails unless `OTP_BACKEND_BASE_URL` (decoded from Flutter's `dart-defines` Gradle property) is a well-formed `https://` URL with a host. Debug and profile builds are unaffected.
- **Standalone check:** `./gradlew :app:verifyReleaseBackendUrl -Pdart-defines=<base64>` runs the same validation without building.
- **Signing:** loads `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) when present. Otherwise release builds use the debug key and print a quiet-level warning (visible under the Flutter tool's `-q` Gradle mode).

`mobile/lib/core/config/otp_backend_config.dart`: doc comment only, stating the HTTPS release rule and the build command. No behaviour change, and the default stays the emulator URL for debugging.

Not changed: Firebase config, architecture, UI, backend code, the deploy files and the manifests (already correct).

## Verification actually performed

| Check | Command | Result |
| --- | --- | --- |
| Release build, no URL | `flutter build apk --release` | **Failed as intended**: "HTTPS release check failed: OTP_BACKEND_BASE_URL is not set…" |
| Release build, HTTP URL | `flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=http://10.0.2.2:8000` | **Failed as intended**: "…must use https:// for release builds…" |
| Guard logic | `gradlew :app:verifyReleaseBackendUrl` with `https://api.example.com` / `https://` / `ftp://x.y` | Pass / fail ("has no host") / fail ("must use https"). No APK is produced by this task. |
| Debug build unaffected | `flutter build apk --debug` | Built `build/app/outputs/flutter-apk/app-debug.apk` |
| Cleartext policy | `gradlew :app:processReleaseMainManifest`, then inspect the merged manifests | release `usesCleartextTraffic="false"`, debug `"true"` |
| Static analysis | `flutter analyze` | No issues |
| Tests | config, auth/health-bot/relapse HTTP-client tests | 45 passed |

**Not performed:**
- **No release APK or AAB was built.** There is no production HTTPS URL, by decision. The full release pipeline (AOT, R8/shrinking, signing) has therefore not been exercised in this session.
- No HTTPS request to a deployed backend; none exists.
- Release signing with a real keystore (none exists).

## Remaining manual actions

1. **Deploy the backend with TLS.** Copy `deploy/.env.example` to `deploy/.env`, set `SITE_DOMAIN` to the real domain (DNS A record pointing to the server) and the secret-file paths, then run `docker compose --env-file deploy/.env -f deploy/compose.yaml up -d --build`. Caddy obtains the certificate. Check: `curl https://<domain>/health` returns `{"status":"ok"}`.
2. **Create the upload keystore** (keep it and the passwords private; never commit them):
   ```
   keytool -genkey -v -keystore %USERPROFILE%\quit-companion-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Then create `mobile/android/key.properties`:
   ```
   storeFile=C:\\Users\\<you>\\quit-companion-upload.jks
   storePassword=<your password>
   keyAlias=upload
   keyPassword=<your password>
   ```
3. **Build the release:**
   ```
   cd mobile
   flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=https://<domain>
   # or for Play upload:
   flutter build appbundle --release --dart-define=OTP_BACKEND_BASE_URL=https://<domain>
   ```
   Output: `mobile/build/app/outputs/flutter-apk/app-release.apk` (or `mobile/build/app/outputs/bundle/release/app-release.aab`). If the "signed with the DEBUG key" warning appears, `key.properties` wasn't found.
4. **Install on a device** and check: phone OTP, Health-Bot, craving risk scoring and plan generation work, with no "could not reach" errors. Optionally verify there's no plain-HTTP traffic with a proxy or `adb logcat`.
5. Google Sign-In for the release key needs that key's SHA-1/SHA-256 added in the Firebase console (`keytool -list -v -keystore <jks> -alias upload`). This is a console change, not done here.

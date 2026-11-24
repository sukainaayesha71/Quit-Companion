/// Base URL of the FastAPI backend for services such as phone OTP and
/// Health-Bot. Firebase sign-in itself talks directly to Firebase.
///
/// Override at build/run time, e.g.:
///   flutter run --dart-define=OTP_BACKEND_BASE_URL=http://192.168.1.20:8000
///
/// The default supports an Android emulator talking to a backend running on
/// the host machine. A physical device needs the host's real LAN IP instead.
///
/// Release builds (Step 11): must be built with an https:// URL, e.g.
///   flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=https://api.your-domain
/// android/app/build.gradle.kts fails release assemble/bundle tasks otherwise,
/// and the release manifest blocks cleartext HTTP. Plain http:// only works
/// in debug/profile builds (their manifests allow cleartext for USB/LAN dev).
class OtpBackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'OTP_BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}

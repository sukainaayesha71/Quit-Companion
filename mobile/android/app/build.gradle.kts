import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.quitcompanion.quit_companion"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (Module 11 — FR14's
        // local reminders): the plugin's Android implementation uses
        // java.time APIs that need core library desugaring on minSdk < 26
        // consumers of this AAR, even though this app's own minSdk is 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.quitcompanion.quit_companion"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // SDD §2: Android 8.0+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Step 11 release signing: android/key.properties (git-ignored, never
    // committed) points at the upload keystore. Without it, release builds
    // fall back to the debug key so local/demo release builds still work —
    // such an APK can be sideloaded but must NOT be published.
    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKeystore) "release" else "debug")
        }
    }
}

// ---------------------------------------------------------------------------
// Step 11 — HTTPS-only release builds.
//
// The app's backend URL comes from --dart-define=OTP_BACKEND_BASE_URL
// (lib/core/config/otp_backend_config.dart). Its default is the emulator's
// http://10.0.2.2:8000 for local debugging, and the release manifest blocks
// cleartext HTTP (usesCleartextTraffic="false"), so a release build without
// an https:// URL would silently break every backend feature. Release
// assemble/bundle tasks therefore fail unless an https:// URL is supplied.
// Debug and profile builds are unaffected.
// ---------------------------------------------------------------------------
fun dartDefines(): Map<String, String> {
    val encoded = project.findProperty("dart-defines") as String? ?: return emptyMap()
    return encoded.split(",").filter { it.isNotBlank() }.mapNotNull { entry ->
        val decoded = try {
            String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
        } catch (e: IllegalArgumentException) {
            return@mapNotNull null
        }
        val separator = decoded.indexOf('=')
        if (separator <= 0) null else decoded.substring(0, separator) to decoded.substring(separator + 1)
    }.toMap()
}

fun releaseBackendUrlError(): String? {
    val url = dartDefines()["OTP_BACKEND_BASE_URL"]?.trim()
    return when {
        url.isNullOrEmpty() ->
            "OTP_BACKEND_BASE_URL is not set. Release builds need the production HTTPS backend, e.g.\n" +
                "  flutter build apk --release --dart-define=OTP_BACKEND_BASE_URL=https://api.your-domain"
        !url.startsWith("https://") ->
            "OTP_BACKEND_BASE_URL must use https:// for release builds (got \"$url\"). " +
                "Android blocks cleartext HTTP in release builds."
        url.removePrefix("https://").substringBefore('/').isBlank() ->
            "OTP_BACKEND_BASE_URL has no host: \"$url\"."
        else -> null
    }
}

tasks.register("verifyReleaseBackendUrl") {
    group = "verification"
    description = "Fails unless OTP_BACKEND_BASE_URL is an https:// URL (Step 11)."
    doLast {
        releaseBackendUrlError()?.let { throw GradleException(it) }
        logger.lifecycle("Release backend URL OK: ${dartDefines()["OTP_BACKEND_BASE_URL"]}")
    }
}

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { task ->
        task.project == project &&
            Regex("^(assemble|bundle|package)Release$").matches(task.name)
    }
    if (buildsRelease) {
        releaseBackendUrlError()?.let { throw GradleException("HTTPS release check failed: $it") }
        if (!hasReleaseKeystore) {
            // quiet level: the Flutter tool runs Gradle with -q, which hides warn.
            logger.quiet(
                "WARNING: android/key.properties not found - this release build is signed " +
                    "with the DEBUG key. Fine for testing/sideloading, not for publishing.",
            )
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // Pairs with isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.1")
}

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Sprint 63 (docs/15-github-project/cd-workflows.md §2, docs/12-security/owasp-checklist.md M8) —
// standard Flutter release-signing pattern: reads real signing credentials from a gitignored
// key.properties file (see android/.gitignore) if one exists, so this file itself never carries a
// real secret. Deliberately falls back to the debug keystore, unchanged, when key.properties is
// absent — nothing about today's `flutter build apk --debug`/`flutter run --release` behaviour
// changes until a real key.properties is actually created; creating one is the one remaining step,
// not a code change.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasRealKeystore = keystorePropertiesFile.exists()
if (hasRealKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.smartposx.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.smartposx.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasRealKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // rootProject.file, not file() — storeFile in key.properties is a path relative to
                // this android/ directory (where key.properties itself lives, and where the
                // key.properties.example instructions run `keytool` from), not the app/ module
                // directory a bare file() call would resolve against.
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real signing once key.properties exists (see the import block above and
            // key.properties.example in this same directory for the exact steps) — until then,
            // still the debug keystore, exactly as before this sprint, so nothing breaks for
            // local `flutter run --release` testing in the meantime.
            signingConfig = if (hasRealKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

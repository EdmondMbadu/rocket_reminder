import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use(::load)
    }
}

fun encodeDartDefine(value: String): String =
    Base64.getEncoder().encodeToString(value.toByteArray(Charsets.UTF_8))

fun decodeDartDefines(value: String): List<String> =
    value.split(",")
        .filter { it.isNotBlank() }
        .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }

val rocketGoalsApiKey =
    localProperties.getProperty("rocket.goals.firebaseApiKey")
        ?.trim()
        .orEmpty()

if (rocketGoalsApiKey.isNotEmpty()) {
    val existingEncodedDartDefines =
        project.findProperty("dart-defines")
            ?.toString()
            .orEmpty()
    val existingDecodedDartDefines =
        if (existingEncodedDartDefines.isBlank()) {
            emptyList()
        } else {
            decodeDartDefines(existingEncodedDartDefines)
        }
    val hasRocketGoalsApiKey =
        existingDecodedDartDefines.any {
            it.startsWith("ROCKET_GOALS_FIREBASE_API_KEY=") ||
                it.startsWith("ROCKET_GOALS_API_KEY=")
        }

    if (!hasRocketGoalsApiKey) {
        val mergedEncodedDartDefines =
            buildList {
                if (existingEncodedDartDefines.isNotBlank()) {
                    addAll(existingEncodedDartDefines.split(",").filter { it.isNotBlank() })
                }
                add(encodeDartDefine("ROCKET_GOALS_FIREBASE_API_KEY=$rocketGoalsApiKey"))
            }.joinToString(",")

        project.extensions.extraProperties["dart-defines"] = mergedEncodedDartDefines
    }
}

android {
    namespace = "com.example.rocket_reminder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.rocket_reminder"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

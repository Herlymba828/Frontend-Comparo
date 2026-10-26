import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature de publication : android/key.properties en local (jamais versionné)
// ou variables d'environnement ANDROID_KEYSTORE_* injectées par GitHub Secrets.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun signingValue(property: String, environment: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(environment)

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")

android {
    namespace = "com.nexorion_security.comparateurprix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nexorion_security.comparateurprix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Une release n'est jamais signée en silence avec la clé debug
            // (publique) : sans keystore, la build échoue, sauf demande explicite
            // `-PallowDebugSigning` (ex. `flutter run --release` en local ;
            // ces artefacts ne sont pas publiables).
            signingConfig = when {
                releaseStoreFile != null -> signingConfigs.getByName("release")
                project.hasProperty("allowDebugSigning") ->
                    signingConfigs.getByName("debug")
                else -> null
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

// Échec explicite plutôt qu'un artefact non signé ou signé en debug.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project &&
            (it.name == "assembleRelease" || it.name == "bundleRelease")
    }
    if (buildsRelease && releaseStoreFile == null &&
        !project.hasProperty("allowDebugSigning")
    ) {
        throw GradleException(
            "Release sans keystore : définissez android/key.properties ou " +
                "ANDROID_KEYSTORE_PATH (ou -PallowDebugSigning pour un test local).",
        )
    }
}

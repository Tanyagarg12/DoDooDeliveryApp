import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.dodoo.delivery.rider"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dodoo.delivery.rider"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth requires minSdk 23.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Allow per-flavor resValue() (the app_name string below).
    buildFeatures {
        resValues = true
    }

    // Three separate apps from one codebase: rider, admin, and store.
    // Build with:  flutter run/build apk --flavor rider -t lib/main.dart
    //              flutter build apk --flavor admin -t lib/main_admin.dart
    //              flutter build apk --flavor store -t lib/main_store.dart
    // NOTE: each flavor's applicationId must be registered in Firebase
    // (google-services.json). rider + admin are registered; the store package
    // "com.dodoo.delivery.store" must be added in the Firebase console before
    // an Android build of the store flavor will succeed.
    flavorDimensions += "app"
    productFlavors {
        create("rider") {
            dimension = "app"
            applicationId = "com.dodoo.delivery.rider"
            resValue("string", "app_name", "DoDoo Rider")
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.dodoo.delivery.admin"
            resValue("string", "app_name", "DoDoo Admin")
        }
        create("store") {
            dimension = "app"
            applicationId = "com.dodoo.delivery.store"
            resValue("string", "app_name", "DoDoo Store")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

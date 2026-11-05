plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cvc953.lyrio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
      isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hackkboi.timelyr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        //minSdk = flutter.minSdkVersion
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Persistent release signing. When CI provides the keystore (see
    // .github/workflows/flutter-android.yml) every build is signed with the same
    // key, so a new APK installs over the old one as a normal update.
    // Without it, the build falls back to the debug key (not update-safe).
    val releaseKeystore = file("release.keystore")
    val ksStorePassword: String? = System.getenv("ANDROID_SIGNING_STORE_PASSWORD")
    val ksKeyAlias: String? = System.getenv("ANDROID_SIGNING_KEY_ALIAS")
    val ksKeyPassword: String? = System.getenv("ANDROID_SIGNING_KEY_PASSWORD")
    val hasReleaseSigning =
        releaseKeystore.exists() &&
            !ksStorePassword.isNullOrBlank() &&
            !ksKeyAlias.isNullOrBlank() &&
            !ksKeyPassword.isNullOrBlank()

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = ksStorePassword
                keyAlias = ksKeyAlias
                keyPassword = ksKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

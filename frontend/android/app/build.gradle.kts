import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.arka_payroll"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.arka_payroll"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath =
                System.getenv("ANDROID_KEYSTORE_PATH")
                    ?: keystoreProperties["storeFile"]?.toString()
            val storePasswordValue =
                System.getenv("ANDROID_STORE_PASSWORD")
                    ?: keystoreProperties["storePassword"]?.toString()
            val keyAliasValue =
                System.getenv("ANDROID_KEY_ALIAS")
                    ?: keystoreProperties["keyAlias"]?.toString()
            val keyPasswordValue =
                System.getenv("ANDROID_KEY_PASSWORD")
                    ?: keystoreProperties["keyPassword"]?.toString()

            if (storeFilePath != null &&
                storePasswordValue != null &&
                keyAliasValue != null &&
                keyPasswordValue != null
            ) {
                val resolved =
                    if (file(storeFilePath).isAbsolute) {
                        file(storeFilePath)
                    } else {
                        rootProject.file(storeFilePath)
                    }
                storeFile = resolved
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig =
                if (releaseSigning.storeFile != null) {
                    releaseSigning
                } else {
                    // Local fallback so `flutter run --release` still works without key.properties
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

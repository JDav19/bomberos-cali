import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Claves locales que NO van a git. Ver android/*.example y docs/SETUP.md.
fun loadProps(name: String): Properties = Properties().apply {
    val f = rootProject.file(name)
    if (f.exists()) f.inputStream().use { load(it) }
}

val keyProps = loadProps("key.properties")
val secrets = loadProps("secrets.properties")

android {
    namespace = "co.edu.usbcali.bomberos119"
    // flutter_local_notifications exige compileSdk 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "co.edu.usbcali.bomberos119"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = secrets.getProperty("MAPS_API_KEY", "")
    }

    signingConfigs {
        if (keyProps.containsKey("storeFile")) {
            create("release") {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProps.containsKey("storeFile")) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("key.properties no existe: el release se firma con la llave debug.")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// androidx.core 1.19 exige AGP 9.1; este proyecto usa 9.0.1.
configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.16.0", "androidx.core:core-ktx:1.16.0")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

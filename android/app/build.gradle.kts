import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vegece.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }

    defaultConfig {
        applicationId = "com.vegece.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 5
        versionName = "1.0.5"
    }

    signingConfigs {
        create("release") {
            storeFile = file("D:\\VetHome\\vethome\\Claude\\android\\app\\upload-keystore.jks")
            storePassword = "O0775326005o"
            keyAlias = "upload"
            keyPassword = "O0775326005o"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

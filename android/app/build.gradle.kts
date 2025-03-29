plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")  // Updated plugin ID
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Added for Firebase
}

android {
    namespace = "com.example.temp_flash_ai"
    compileSdk = 35  // Explicitly set (recommended over flutter.compileSdkVersion)
    ndkVersion = "27.0.12077973"  // Explicitly set to resolve plugin conflicts

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17  // Updated to Java 17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()  // Updated to match Java 17
    }

    defaultConfig {
        applicationId = "com.example.temp_flash_ai"
        minSdk = 23  // Explicitly set (required by Firebase Auth)
        targetSdk = 34  // Explicitly set
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true  // Enable code shrinking
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        buildConfig = true  // Enable build config generation
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))  // Firebase BoM
    implementation("com.google.firebase:firebase-analytics-ktx")  // Firebase Analytics
    implementation("com.google.firebase:firebase-auth-ktx")  // Firebase Auth
    implementation("androidx.core:core-ktx:1.12.0")  // AndroidX Core
}
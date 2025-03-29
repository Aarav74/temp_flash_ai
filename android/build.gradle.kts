// Top-level build file
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.4")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")  // Updated to latest stable
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Configure build directory at the project level
    layout.buildDirectory.set(File(rootDir, "../build/${project.name}"))
    
    // Apply common configuration for Android projects safely
    pluginManager.withPlugin("com.android.application") {
        configure<com.android.build.gradle.BaseExtension> {
            compileSdkVersion(34)
            ndkVersion = "27.0.12077973"
            
            defaultConfig {
                minSdk = 23
                targetSdk = 34
            }

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(File(rootDir, "../build"))
    delete("${rootDir}/build")
}

extra.apply {
    set("compileSdkVersion", 34)
    set("minSdkVersion", 23)
    set("targetSdkVersion", 34)
    set("ndkVersion", "27.0.12077973")
    set("kotlinVersion", "2.1.20")  // Added Kotlin version as extra property
}
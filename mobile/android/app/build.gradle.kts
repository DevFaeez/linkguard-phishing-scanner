plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "my.linkguard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "my.linkguard"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Mirror resource inputs without macOS AppleDouble files. Do not modify source files.
val cleanResourceRoot = rootProject.layout.buildDirectory.dir("resource-inputs")
val prepareCleanResourceInputs = tasks.register<Sync>("prepareCleanResourceInputs") {
    into(cleanResourceRoot)
    exclude("**/._*", "._*")
}
android.sourceSets.configureEach {
    val sourceSetName = name
    val originalDirectories = res.srcDirs.toList()
    val cleanDirectories = originalDirectories.mapIndexed { index, original ->
        val relativePath = "$sourceSetName/$index"
        prepareCleanResourceInputs.configure {
            from(original) { into(relativePath) }
        }
        cleanResourceRoot.get().dir(relativePath).asFile
    }
    res.setSrcDirs(cleanDirectories)
}
tasks.named("preBuild").configure { dependsOn(prepareCleanResourceInputs) }

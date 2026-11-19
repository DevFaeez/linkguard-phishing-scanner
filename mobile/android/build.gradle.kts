import java.security.MessageDigest

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep source on ESSD, but place Gradle intermediates on the native host filesystem.
// exFAT's AppleDouble files (._drawable etc.) are not Android resource directories.
val checkoutId = MessageDigest.getInstance("SHA-256")
    .digest(rootDir.canonicalPath.toByteArray())
    .take(6).joinToString("") { "%02x".format(it) }
val internalBuildDir = providers.gradleProperty("linkguard.buildRoot").orNull
    ?.let { file(it) }
    ?: file("${System.getProperty("java.io.tmpdir")}/linkguard-android-$checkoutId")
val flutterOutputsDir = rootDir.resolve("../build/app/outputs")

rootProject.layout.buildDirectory.set(internalBuildDir)
subprojects {
    layout.buildDirectory.set(internalBuildDir.resolve(name))
}
subprojects {
    evaluationDependsOn(":app")
}

// Flutter discovers artifacts in mobile/build even though compilation happens internally.
// Register after :app evaluation so this follows Flutter's own APK-copy action.
project(":app") {
    tasks.matching { it.name.startsWith("assemble") || it.name.startsWith("bundle") }
        .configureEach {
            doLast {
                copy {
                    from(layout.buildDirectory.dir("outputs/flutter-apk"))
                    into(flutterOutputsDir.resolve("flutter-apk"))
                    exclude("**/._*")
                }
                copy {
                    from(layout.buildDirectory.dir("outputs/bundle"))
                    into(flutterOutputsDir.resolve("bundle"))
                    exclude("**/._*")
                }
            }
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(flutterOutputsDir)
}

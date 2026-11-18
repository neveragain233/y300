plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials are kept out of version control in
// `android/key.properties` (git-ignored). When the file is absent — a fresh
// clone, or a machine without the keystore — we fall back to debug signing so
// `flutter run` still works. Only real release builds require the file.
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}


// Y300 publishes one arm64 APK. Keep the canonical Gradle artifact
// self-describing without `--split-per-abi`, which would rewrite the
// package versionCode with Flutter's ABI discriminator.
base {
    archivesName.set("y300-v${flutter.versionName}-android-arm64-v8a")
}

android {
    namespace = "com.example.y300"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (v21+) requires Java 8+ API desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 本 fork 的独立应用标识：与上游 com.adws.y300 区分，官方安装包与本项目
        // 安装包不会因为签名不同而互相顶掉。发布后不要修改，否则无法覆盖升级。
        // （上面的 Kotlin `namespace` 是内部命名，与本标识无关。）
        applicationId = "com.adws.y300.fork"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Populated only when android/key.properties exists (real release builds).
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real release keystore when configured; otherwise fall back to
            // debug signing so `flutter run --release` still works without a keystore.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// 插件可能携带全部架构；调试包按 Flutter 请求的平台过滤，模拟器目标继续可用。
val flutterTargetAbis = providers.gradleProperty("target-platform").orNull
    ?.split(",")?.mapNotNull {
        when (it.trim()) {
            "android-arm" -> "armeabi-v7a"
            "android-arm64" -> "arm64-v8a"
            "android-x86" -> "x86"
            "android-x64" -> "x86_64"
            else -> null
        }
    }?.toSet().orEmpty()
androidComponents {
    onVariants { variant ->
        val allowed = if (variant.buildType == "release") setOf("arm64-v8a") else flutterTargetAbis
        if (allowed.isNotEmpty()) {
            variant.packaging.jniLibs.excludes.addAll(
                listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
                    .filterNot { it in allowed }.map { "lib/$it/**" }
            )
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
    // Required by flutter_local_notifications when core library desugaring is on.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

plugins {
    kotlin("multiplatform") version "2.2.21"
    id("com.android.library") version "8.10.1"
}
val componentVersion = providers.gradleProperty("customerServiceVersion").orElse("0.1.5").get()
kotlin {
    androidTarget {
        compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) }
    }
    iosArm64()
    iosX64()
    iosSimulatorArm64 { binaries.framework { baseName = "CustomerServiceConsumer" } }
    sourceSets.commonMain.dependencies {
        implementation("com.github.gycrosskit.customer-service:customer-service:$componentVersion")
    }
}
android {
    namespace = "io.github.gycrosskit.customerservice.consumer"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

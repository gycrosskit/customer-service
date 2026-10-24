plugins {
    kotlin("multiplatform") version "2.2.21-1.0.0"
    id("com.android.library") version "8.10.1"
}
val componentVersion = providers.gradleProperty("customerServiceVersion").orElse("1.0.0").get()
kotlin {
    androidTarget {
        compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) }
    }
    iosArm64 { binaries.framework { baseName = "CustomerServiceConsumer" } }
    iosX64 { binaries.framework { baseName = "CustomerServiceConsumer" } }
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

// 本轮候选与公开旧版本分别解析；Gradle 冲突解析不能悄悄消费另一个组件版本。
tasks.register("verifyExactComponentVersion") {
    doLast {
        val platform = providers.gradleProperty("customerServicePlatform")
            .orElse(if (System.getProperty("os.name").startsWith("Mac")) "ios" else "android").get()
        require(platform in setOf("android", "ios")) { "Unknown customer service consumer platform" }
        val resolutions = configurations.filter { it.isCanBeResolved &&
            (it.name.endsWith("CompileClasspath", true) || it.name.endsWith("CompileKlibraries", true)) &&
            (it.name.startsWith("ios", true) == (platform == "ios")) }
            .map { it.incoming.resolutionResult }
        val unresolved = resolutions.flatMap { it.allDependencies }
            .filterIsInstance<org.gradle.api.artifacts.result.UnresolvedDependencyResult>()
        check(unresolved.isEmpty()) { "Unresolved customer service consumer dependencies: $unresolved" }
        val selected = resolutions.flatMap { it.allComponents }.mapNotNull { it.moduleVersion }
            .filter { it.group == "com.github.gycrosskit.customer-service" }
        check(selected.isNotEmpty() && selected.all { it.version == componentVersion }) {
            "Customer service dependency version mismatch"
        }
    }
}

tasks.matching { it.name.startsWith("compile") || it.name.startsWith("link") }.configureEach {
    dependsOn("verifyExactComponentVersion")
}

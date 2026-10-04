plugins {
    kotlin("multiplatform") version "2.2.21"
    id("com.android.library") version "8.10.1"
    `maven-publish`
}
group = providers.environmentVariable("GROUP").orElse("com.github.gycrosskit").get()
version = providers.environmentVariable("VERSION").orElse("0.1.2").get()
kotlin {
    androidTarget {
        publishLibraryVariants("release")
        compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) }
    }
    iosX64()
    iosArm64()
    iosSimulatorArm64()
    sourceSets {
        androidMain.dependencies {
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
            implementation("com.tencentcloud.desk:aideskcustomer:2.6.0")
            // 与当前宿主 AtomicX 共用同一 IM 版本，不让客服传递依赖升级单例。
            implementation("com.tencent.imsdk:imsdk-plus:9.1.7818")
        }
        commonTest.dependencies { implementation(kotlin("test")) }
    }
}
android {
    namespace = "io.github.gycrosskit.customerservice"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}
publishing {
    repositories.maven {
        name = "staging"
        url = uri(layout.buildDirectory.dir("maven"))
    }
    publications.withType<MavenPublication>().configureEach {
        pom {
            name.set("GY CrossKit Customer Service")
            url.set("https://github.com/gycrosskit/customer-service")
            licenses {
                license {
                    name.set("Apache License, Version 2.0")
                    url.set("https://www.apache.org/licenses/LICENSE-2.0.txt")
                    distribution.set("repo")
                }
            }
            description.set("腾讯客服原生 SDK 适配；业务准入、凭据、会话串行化与页面关闭等待由宿主提供。")
        }
    }
}

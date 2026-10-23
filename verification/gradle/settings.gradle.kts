import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    repositories {
        maven("https://maven.eazytec-cloud.com/nexus/repository/maven-public/")
        maven("https://mirrors.tencent.com/nexus/repository/maven-public/")
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
val candidateMaven = providers.gradleProperty("customerServiceMavenRepo").orNull?.let {
    file(it).also { directory ->
        require(java.io.File(it).isAbsolute && directory.isDirectory) { "Candidate Maven repository must be an existing absolute directory" }
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven("https://maven.eazytec-cloud.com/nexus/repository/maven-public/")
        maven("https://mirrors.tencent.com/nexus/repository/maven-public/")
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        exclusiveContent {
            forRepository {
                maven { url = candidateMaven?.toURI() ?: uri("https://jitpack.io") }
            }
            filter { includeGroup("com.github.gycrosskit.customer-service") }
        }
        google()
        mavenCentral()
        maven("https://mirrors.tencent.com/nexus/repository/maven-tencent/")
    }
}
rootProject.name = "customer-service-consumer"

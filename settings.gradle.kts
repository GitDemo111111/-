pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        // 阿里云 Google 镜像（替代 google()）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        // 阿里云 Central 镜像（替代 mavenCentral()）
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // 阿里云 Gradle Plugin 镜像（替代 gradlePluginPortal()）
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // 阿里云 Public 镜像（合并了多个常用仓库，作为兜底）
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        // 保留 JitPack 原地址（如果项目里有 JitPack 的依赖的话）
        maven { url = uri("https://jitpack.io") }
    }
}

rootProject.name = "MyCalendarMemo"
include(":app")
 
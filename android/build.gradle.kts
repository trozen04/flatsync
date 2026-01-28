allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    afterEvaluate {
        // Apply only to projects that have the Android plugin
        plugins.withType<com.android.build.gradle.LibraryPlugin> {
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                compileSdk = 36
                buildToolsVersion = "36.0.0"  // change to "35.0.0" if you only have 35 installed
            }
        }

        plugins.withType<com.android.build.gradle.AppPlugin> {
            extensions.configure<com.android.build.api.dsl.ApplicationExtension>("android") {
                compileSdk = 36
                buildToolsVersion = "36.0.0"
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

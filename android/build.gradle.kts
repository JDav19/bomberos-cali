allprojects {
    repositories {
        google()
        mavenCentral()
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
// Algunos plugins (Agora) vienen compilados contra un SDK viejo y sus dependencias
// AndroidX exigen uno nuevo. Se sube el compileSdk de todas las librerias.
subprojects {
    configurations.all {
        resolutionStrategy.force("androidx.core:core:1.16.0", "androidx.core:core-ktx:1.16.0")
    }
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            (extensions.getByName("android") as com.android.build.gradle.BaseExtension).compileSdkVersion(37)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

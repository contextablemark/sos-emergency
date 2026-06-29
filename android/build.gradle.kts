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
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. flutter_pcm_sound) pin an older compileSdk than their
// transitive AndroidX dependencies now require (API 34+), which fails the AAR
// metadata check. Force every plugin module up to the app's compileSdk (36)
// after it configures. `withGroovyBuilder` invokes compileSdkVersion(int)
// dynamically, so the root build needs no Android Gradle Plugin imports.
//
// :app is force-evaluated by the evaluationDependsOn(":app") above and already
// targets 36; registering afterEvaluate on an already-evaluated project throws,
// so skip projects that have finished evaluating.
subprojects {
    if (!project.state.executed) {
        afterEvaluate {
            extensions.findByName("android")?.withGroovyBuilder {
                "compileSdkVersion"(36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

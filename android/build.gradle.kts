allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Add test dependencies for Android projects
    plugins.withId("com.android.library") {
        dependencies {
            "testImplementation"("org.robolectric:robolectric:4.10.3")
            "testImplementation"("androidx.test:core:1.5.0")
            "testImplementation"("androidx.test.ext:junit:1.2.1")
            "testImplementation"("org.mockito:mockito-core:5.4.0")
            "testImplementation"("org.mockito:mockito-android:5.4.0")
            "testImplementation"("net.bytebuddy:byte-buddy:1.17.5")
            "testImplementation"("net.bytebuddy:byte-buddy-agent:1.14.5")
        }
        
        tasks.withType<Test> {
            systemProperty("robolectric.dependency.repo.id", "central")
            systemProperty("mockito.mock-maker-class", "mock-maker-inline")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

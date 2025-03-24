/*
 * This file was generated by the Gradle 'init' task.
 *
 * This generated file contains a sample Java application project to get you started.
 * For more details on building Java & JVM projects, please refer to https://docs.gradle.org/8.13/userguide/building_java_projects.html in the Gradle documentation.
 */

plugins {
    // Apply the application plugin to add support for building a CLI application in Java.
    application
    id("io.freefair.lombok") version "8.12.2"
}

var logbackVersion = "1.5.6"
var slf4jVersion = "2.0.13"
var junitVersion = "5.10.1"

var version = "0.0.3"

dependencies {
    // Use JUnit Jupiter for testing.
    testImplementation(libs.junit.jupiter)

    testRuntimeOnly("org.junit.platform:junit-platform-launcher")

    // This dependency is used by the application.
    implementation("io.github.andreyzebin:java-bash:2.1.0")


    implementation("ch.qos.logback:logback-core:$logbackVersion")
    implementation("ch.qos.logback:logback-classic:$logbackVersion")
    implementation("org.slf4j:slf4j-api:$slf4jVersion")
    implementation("org.codehaus.janino:janino:3.1.12")

}

application {
    // Define the main class for the application.
    mainClass.set( "org.example.App")
    applicationDefaultJvmArgs = listOf(
        "-Dlogger.root.level=DEBUG",
        "-Dversion=${version}"
    )
}

tasks.named<Test>("test") {
    // Use JUnit Platform for unit tests.
    useJUnitPlatform()
}

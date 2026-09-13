import java.util.Properties

plugins {
    id("com.android.application")
}

// Signature de publication. Le fichier `keystore.properties` n'est pas
// versionné (voir `.gitignore`) : sans lui, `assembleRelease` et `bundleRelease`
// produisent un artefact non signé, ce qui reste utile pour vérifier que le
// projet compile. Modèle : `keystore.properties.exemple`.
val fichierSignature = rootProject.file("keystore.properties")
val signature = Properties().apply {
    if (fichierSignature.exists()) fichierSignature.inputStream().use { load(it) }
}

android {
    namespace = "com.jmprojectlab.scornade"
    compileSdk = 36

    defaultConfig {
        // Identique au bundle id iOS, et définitif une fois la fiche créée sur
        // Google Play : un nom de paquet publié ne se change ni ne se réutilise.
        applicationId = "com.jmprojectlab.scornade"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    if (signature.containsKey("storeFile")) {
        signingConfigs {
            create("release") {
                storeFile = rootProject.file(signature.getProperty("storeFile"))
                storePassword = signature.getProperty("storePassword")
                keyAlias = signature.getProperty("keyAlias")
                keyPassword = signature.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Rien à minifier : l'application n'a pas de code applicatif, elle
            // n'assemble que la bibliothèque qui lance Chrome en plein écran.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release")
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    // Trusted Web Activity : ouvre le site dans Chrome, sans barre d'adresse,
    // à condition que la vérification Digital Asset Links passe. Voir README.
    implementation("com.google.androidbrowserhelper:androidbrowserhelper:2.6.2")
}

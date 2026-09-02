# android_apps

Small Android apps, one directory each. They are personal tools rather than anything aimed at
the Play Store, so each is built and installed by hand from a signed APK.

| Directory | What it is |
| --- | --- |
| `webapp_generator` | Builds a new WebView container app from nothing but a URL, a name and an icon. One shared template, one script. |
| `webapp_google_tasks` | A generated instance of that template, wrapping `tasks.google.com`. |

## Building

The toolchain is not in this repository and is not installed system-wide. It lives under
`~/Android`: Temurin JDK 17, the Android SDK command-line tools, platform 34, build-tools
34.0.0 and Gradle 8.7. Each project's `build.sh` sets `JAVA_HOME`, `ANDROID_HOME` and
`GRADLE_USER_HOME` to point at it, so building is just:

    cd webapp_google_tasks
    ./build.sh

`local.properties` holds the SDK path and is regenerated per machine, which is why it is not
committed.

## Signing, and what a fresh clone cannot do

`*.keystore` and `signing.properties` are excluded, because this repository is public and
`signing.properties` holds the keystore password in plain text.

A clone without them still compiles. Gradle simply skips signing and writes
`app/build/outputs/apk/release/app-release-unsigned.apk` instead of `app-release.apk`. An
unsigned APK will not install on a phone.

Restore both files from your key backup to get an installable build. This matters more than
it looks: Android identifies an app by its signing certificate, so an APK signed with a
newly generated keystore installs as a **separate app** next to the existing one rather than
updating it, and the old one has to be uninstalled first, losing its data.

## Note on the directory name

This tree is `/mnt/Dev/active_android_projects` locally, matching the `active_*` convention
for work in progress, while the repository is called `android_apps`. Git does not care that
the two differ.

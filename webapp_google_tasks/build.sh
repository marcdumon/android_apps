#!/usr/bin/env bash
# Rebuilds this app. The toolchain lives under ~/Android and is not on PATH, so these
# three variables are what make the build work from a plain shell.
set -euo pipefail
export JAVA_HOME="$HOME/Android/jdk"
export ANDROID_HOME="$HOME/Android/sdk"
export GRADLE_USER_HOME="$HOME/Android/gradle_home"
cd "$(dirname "$0")"
"$HOME/Android/gradle-8.7/bin/gradle" --no-daemon assembleRelease
cp -f app/build/outputs/apk/release/app-release.apk ./tasks.apk
ls -1 ./tasks.apk

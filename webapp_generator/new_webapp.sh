#!/usr/bin/env bash
# Generates a standalone Android app that is a full-screen WebView on one website.
# Every generated app is a copy of webapp_template with a different gradle.properties, so the
# Java source exists exactly once and fixes apply to all apps on their next rebuild.
set -euo pipefail

# This script and its template live in webapp_generator/; the apps it builds are
# siblings of that directory, so the projects dir holds projects and nothing else.
HERE="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$HERE/webapp_template"
ROOT="$(dirname "$HERE")"

usage() {
    cat <<'USAGE'
new_webapp.sh --name NAME --url URL [options]

  --name NAME        App name shown under the launcher icon.
  --url URL          Page the app opens.
  --id APPID         Android package id. Default: com.md.<slug>
  --dir DIR          Project directory name. Default: webapp_<slug>
  --icon FILE.png    Launcher icon. Default: the app's first letter on a coloured tile.
  --bg '#RRGGBB'     Icon background colour. Default: #1A73E8
  --ua desktop|mobile
                     Which layout the site should serve. Default: mobile.
  --extra-hosts H,H  Extra hosts kept inside the app. The site's own domain is always kept.
                     Default: the Google sign-in domains.
  --key-alias A / --store-password P / --key-password P
                     Only needed when reusing a keystore made with other credentials.
  --version-code N   Force a version code. Default: 1, or the existing project's + 1.
  --force            Rebuild over an existing project, keeping its keystore and bumping
                     the version code.

Example:
  webapp_generator/new_webapp.sh --name Tasks --url https://tasks.google.com/ --ua desktop
USAGE
}

NAME=""; URL=""; APPID=""; DIR=""; ICON=""; BG="#1A73E8"; UA="mobile"
EXTRA_HOSTS="google.com,gstatic.com,googleusercontent.com,googleapis.com"
LOGIN_HOSTS="accounts.google.com"
SESSION_COOKIE=""
FORCE=""; FORCED_VC=""
STORE_PASSWORD=webapp123; KEY_ALIAS=webapp; KEY_PASSWORD=webapp123

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --id) APPID="$2"; shift 2 ;;
        --dir) DIR="$2"; shift 2 ;;
        --icon) ICON="$2"; shift 2 ;;
        --bg) BG="$2"; shift 2 ;;
        --ua) UA="$2"; shift 2 ;;
        --extra-hosts) EXTRA_HOSTS="$2"; shift 2 ;;
        --login-hosts) LOGIN_HOSTS="$2"; shift 2 ;;
        --session-cookie) SESSION_COOKIE="$2"; shift 2 ;;
        --store-password) STORE_PASSWORD="$2"; shift 2 ;;
        --key-alias) KEY_ALIAS="$2"; shift 2 ;;
        --key-password) KEY_PASSWORD="$2"; shift 2 ;;
        --version-code) FORCED_VC="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

[[ -n $NAME && -n $URL ]] || { usage; exit 1; }
[[ $UA == desktop || $UA == mobile ]] || { echo "--ua must be desktop or mobile" >&2; exit 1; }

SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/_/g; s/^_//; s/_$//')
APPID=${APPID:-com.md.$(echo "$SLUG" | tr -d '_')}
DIR=${DIR:-webapp_$SLUG}
PROJ="$ROOT/$DIR"

VERSION_CODE=1
KEEP_KEYSTORE=""
if [[ -d $PROJ ]]; then
    [[ -n $FORCE ]] || { echo "$PROJ already exists. Use --force to rebuild it." >&2; exit 1; }
    VERSION_CODE=$(( $(grep -oP '^VERSION_CODE=\K[0-9]+' "$PROJ/gradle.properties" 2>/dev/null || echo 0) + 1 ))
    KEEP_KEYSTORE=$(ls "$PROJ"/*.keystore 2>/dev/null | head -1 || true)
    if [[ -n $KEEP_KEYSTORE ]]; then
        cp "$KEEP_KEYSTORE" "/tmp/keep_$(basename "$KEEP_KEYSTORE")"
        KEEP_KEYSTORE="/tmp/keep_$(basename "$KEEP_KEYSTORE")"
    fi
    rm -rf "$PROJ"
fi
[[ -n $FORCED_VC ]] && VERSION_CODE=$FORCED_VC

cp -r "$TEMPLATE" "$PROJ"
rm -rf "$PROJ/app/build" "$PROJ/.gradle"

STORE_FILE=app.keystore
if [[ -n $KEEP_KEYSTORE ]]; then
    STORE_FILE=$(basename "$KEEP_KEYSTORE" | sed 's/^keep_//')
    mv "$KEEP_KEYSTORE" "$PROJ/$STORE_FILE"
fi

cat > "$PROJ/gradle.properties" <<EOF
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=false

# Written by new_webapp.sh. Everything that makes this app different from the other
# generated web apps is on these lines; the source is a verbatim copy of webapp_template.
APP_NAME=$NAME
APP_ID=$APPID
START_URL=$URL
UA_MODE=$UA
EXTRA_HOSTS=$EXTRA_HOSTS
LOGIN_HOSTS=$LOGIN_HOSTS
SESSION_COOKIE=$SESSION_COOKIE
ICON_BACKGROUND=$BG
VERSION_CODE=$VERSION_CODE
VERSION_NAME=1.$VERSION_CODE
EOF

# Signing credentials go in their own file, kept out of git, so a project can live in
# a public repository without publishing the keystore password. Do not lose the keystore
# itself: without it a rebuilt APK can no longer install over the copy already on the phone.
cat > "$PROJ/signing.properties" <<EOF
STORE_FILE=$STORE_FILE
STORE_PASSWORD=$STORE_PASSWORD
KEY_ALIAS=$KEY_ALIAS
KEY_PASSWORD=$KEY_PASSWORD
EOF

echo "sdk.dir=$HOME/Android/sdk" > "$PROJ/local.properties"

# Icon: a supplied PNG, or the app's first letter rendered onto a transparent tile.
# Either way it is inset to 25% so the launcher's adaptive-icon mask cannot crop it.
mkdir -p "$PROJ/app/src/main/res/drawable-nodpi"
if [[ -n $ICON ]]; then
    cp "$ICON" "$PROJ/app/src/main/res/drawable-nodpi/app_icon.png"
else
    python3 - "$PROJ/app/src/main/res/drawable-nodpi/app_icon.png" "$NAME" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont

out, name = sys.argv[1], sys.argv[2]
img = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
letter = name.strip()[:1].upper() or '?'
for path in ('/usr/share/fonts/noto/NotoSans-Bold.ttf',
             '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
             '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf'):
    try:
        font = ImageFont.truetype(path, 300)
        break
    except OSError:
        continue
else:
    font = ImageFont.load_default()
box = draw.textbbox((0, 0), letter, font=font)
draw.text(((432 - box[2] - box[0]) / 2, (432 - box[3] - box[1]) / 2), letter,
          font=font, fill=(255, 255, 255, 255))
img.save(out)
PY
fi

cat > "$PROJ/app/src/main/res/drawable/ic_launcher_foreground.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<inset xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@drawable/app_icon"
    android:inset="25%" />
EOF

export JAVA_HOME="$HOME/Android/jdk"
export ANDROID_HOME="$HOME/Android/sdk"
export GRADLE_USER_HOME="$HOME/Android/gradle_home"

if [[ ! -f $PROJ/$STORE_FILE ]]; then
    "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$PROJ/$STORE_FILE" -alias "$KEY_ALIAS" \
        -storepass "$STORE_PASSWORD" -keypass "$KEY_PASSWORD" -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=$NAME, OU=Personal, O=Personal, L=X, S=X, C=BE" >/dev/null 2>&1
fi

cat > "$PROJ/build.sh" <<'EOF'
#!/usr/bin/env bash
# Rebuilds this app. The toolchain lives under ~/Android and is not on PATH, so these
# three variables are what make the build work from a plain shell.
set -euo pipefail
export JAVA_HOME="$HOME/Android/jdk"
export ANDROID_HOME="$HOME/Android/sdk"
export GRADLE_USER_HOME="$HOME/Android/gradle_home"
cd "$(dirname "$0")"
"$HOME/Android/gradle-8.7/bin/gradle" --no-daemon assembleRelease
cp -f app/build/outputs/apk/release/app-release.apk ./__SLUG__.apk
ls -1 ./__SLUG__.apk
EOF
sed -i "s/__SLUG__/$SLUG/g" "$PROJ/build.sh"
chmod +x "$PROJ/build.sh"

cat > "$PROJ/README.md" <<EOF
# $NAME (Android web app)

A full-screen WebView on <$URL>. Nothing else: no offline, no notifications.

Generated by ../webapp_generator/new_webapp.sh. Do not edit the Java here - edit
webapp_generator/webapp_template and regenerate, or the next regeneration overwrites it:

    ../webapp_generator/new_webapp.sh --name '$NAME' --url '$URL' --dir $DIR --id $APPID --ua $UA --force

Build:   ./build.sh   ->  ./$SLUG.apk
Install: copy the APK to the phone and tap it, or
         ~/Android/sdk/platform-tools/adb install ./$SLUG.apk

The user agent claims to be $UA Chrome. That is deliberate: the "wv" token in a stock WebView
user agent makes Google refuse to sign you in, and a mobile token makes sites serve their phone
layout. See buildUserAgent() in the template.

KEEP $STORE_FILE. Without it a rebuilt APK can no longer install over the copy on the phone.
EOF

"$PROJ/build.sh"
echo
echo "Project: $PROJ"
echo "Name:    $NAME    id: $APPID    version code: $VERSION_CODE    ua: $UA"

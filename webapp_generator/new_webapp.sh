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
new_webapp.sh --dir DIR --force            regenerate an existing app

  --name NAME        App name shown under the launcher icon.
  --url URL          Page the app opens.
  --id APPID         Android package id. Default: com.md.<slug>
  --dir DIR          Project directory name. Default: webapp_<slug>
  --icon FILE.png    Launcher icon. Kept if the project already has one, otherwise drawn.
  --glyph letter|tick
                     Shape to draw when no icon file is given. Default: letter, the app's
                     first letter. tick suits a task list.
  --bg '#RRGGBB'     Icon background colour. Default: #1A73E8
  --ua desktop|mobile
                     Which layout the site should serve. Default: mobile.
  --extra-hosts H,H  Extra hosts kept inside the app. The site's own domain is always kept.
                     Default: the Google sign-in domains.
  --login-hosts H,H  Sign-in domains that always get the phone user agent, even in desktop
                     mode, because sign-in pages refuse a desktop agent from a phone.
                     Default: accounts.google.com
  --session-cookie C Cookie name proving a signed-in session, so the app knows when it may
                     switch to the configured user agent. Default: none, meaning any cookie.
  --key-alias A / --store-password P / --key-password P
                     Only needed when creating a keystore with particular credentials.
  --version-code N   Version code to write. Default: 1, or the existing project's, unchanged.
  --force            Update an existing project.

Regenerating an existing app keeps everything it does not own: the settings you gave last
time, the keystore, the icon, and any file that did not come from the template, such as a
changelog or an icon script. Only template files are refreshed, and the version code is left
alone unless you pass --version-code.

Example:
  webapp_generator/new_webapp.sh --name Tasks --url https://tasks.google.com/ --ua desktop
USAGE
}

# One KEY=VALUE out of a properties file. Empty when the file or the key is absent. Values
# may themselves contain "=", which is why everything after the first one is kept.
prop() {
    [[ -f $1 ]] || return 0
    sed -n "s/^$2=//p" "$1" | head -1
}

slug_of() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/_/g; s/^_//; s/_$//'
}

# Nothing is given a default yet. A setting comes from the command line if you passed it,
# otherwise from the existing project, otherwise from the defaults at the bottom of this
# block. That order is what makes regenerating with no options reproduce the same app.
FORCE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --id) APPID="$2"; shift 2 ;;
        --dir) DIR="$2"; shift 2 ;;
        --icon) ICON="$2"; shift 2 ;;
        --glyph) GLYPH="$2"; shift 2 ;;
        --bg) BG="$2"; shift 2 ;;
        --ua) UA="$2"; shift 2 ;;
        --extra-hosts) EXTRA_HOSTS="$2"; shift 2 ;;
        --login-hosts) LOGIN_HOSTS="$2"; shift 2 ;;
        --session-cookie) SESSION_COOKIE="$2"; shift 2 ;;
        --store-password) STORE_PASSWORD="$2"; shift 2 ;;
        --key-alias) KEY_ALIAS="$2"; shift 2 ;;
        --key-password) KEY_PASSWORD="$2"; shift 2 ;;
        --version-code) VERSION_CODE="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -n ${DIR-} ]]; then
    PROJ="$ROOT/$DIR"
elif [[ -n ${NAME-} ]]; then
    DIR="webapp_$(slug_of "${NAME}")"
    PROJ="$ROOT/$DIR"
else
    echo "need --name for a new app, or --dir for an existing one" >&2
    usage; exit 1
fi

if [[ -d $PROJ ]]; then
    [[ -n $FORCE ]] || { echo "$PROJ already exists. Use --force to update it." >&2; exit 1; }
    OLD_GRADLE="$PROJ/gradle.properties"
    OLD_SIGNING="$PROJ/signing.properties"
    : "${NAME=$(prop "$OLD_GRADLE" APP_NAME)}"
    : "${URL=$(prop "$OLD_GRADLE" START_URL)}"
    : "${APPID=$(prop "$OLD_GRADLE" APP_ID)}"
    : "${UA=$(prop "$OLD_GRADLE" UA_MODE)}"
    : "${EXTRA_HOSTS=$(prop "$OLD_GRADLE" EXTRA_HOSTS)}"
    : "${LOGIN_HOSTS=$(prop "$OLD_GRADLE" LOGIN_HOSTS)}"
    : "${SESSION_COOKIE=$(prop "$OLD_GRADLE" SESSION_COOKIE)}"
    : "${BG=$(prop "$OLD_GRADLE" ICON_BACKGROUND)}"
    : "${VERSION_CODE=$(prop "$OLD_GRADLE" VERSION_CODE)}"
    : "${STORE_FILE=$(prop "$OLD_SIGNING" STORE_FILE)}"
    : "${STORE_PASSWORD=$(prop "$OLD_SIGNING" STORE_PASSWORD)}"
    : "${KEY_ALIAS=$(prop "$OLD_SIGNING" KEY_ALIAS)}"
    : "${KEY_PASSWORD=$(prop "$OLD_SIGNING" KEY_PASSWORD)}"
fi

: "${NAME:=}"
: "${URL:=}"
[[ -n $NAME && -n $URL ]] || {
    echo "a name and a url are required, and could not be read from the project" >&2
    usage; exit 1
}

SLUG=$(slug_of "$NAME")
: "${APPID:=com.md.$(echo "$SLUG" | tr -d '_')}"
: "${BG:=#1A73E8}"
: "${UA:=mobile}"
: "${EXTRA_HOSTS:=google.com,gstatic.com,googleusercontent.com,googleapis.com}"
: "${LOGIN_HOSTS:=accounts.google.com}"
: "${SESSION_COOKIE=}"
: "${STORE_FILE:=app.keystore}"
: "${STORE_PASSWORD:=webapp123}"
: "${KEY_ALIAS:=webapp}"
: "${KEY_PASSWORD:=webapp123}"
: "${VERSION_CODE:=1}"
: "${ICON=}"
: "${GLYPH:=letter}"

[[ $UA == desktop || $UA == mobile ]] || { echo "--ua must be desktop or mobile" >&2; exit 1; }
[[ $GLYPH == letter || $GLYPH == tick ]] || { echo "--glyph must be letter or tick" >&2; exit 1; }

# The template is laid over the project rather than replacing it, so files the generator
# never created, a changelog or an icon script for instance, survive a regeneration.
mkdir -p "$PROJ"
cp -r "$TEMPLATE/." "$PROJ/"
rm -rf "$PROJ/app/build" "$PROJ/.gradle"

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

# Icon: a supplied PNG, whatever the project already has, or the app's first letter on a
# transparent tile. Either way it is inset to 25% so the launcher's mask cannot crop it.
# An existing icon is never overwritten, so a hand drawn one survives regeneration.
ICON_PATH="$PROJ/app/src/main/res/drawable-nodpi/app_icon.png"
mkdir -p "$(dirname "$ICON_PATH")"
if [[ -n $ICON ]]; then
    cp "$ICON" "$ICON_PATH"
elif [[ ! -f $ICON_PATH ]]; then
    python3 - "$ICON_PATH" "$NAME" "$GLYPH" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont

out, name, glyph = sys.argv[1], sys.argv[2], sys.argv[3]
SIZE = 432
img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

if glyph == 'tick':
    # Drawn at 4x and downsampled, because PIL does not antialias lines.
    scale = 4
    px = SIZE * scale
    big = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    pen = ImageDraw.Draw(big)
    width = int(px * 0.11)
    points = [(px * 0.26, px * 0.52), (px * 0.44, px * 0.70), (px * 0.76, px * 0.31)]
    pen.line(points, fill='#ffffff', width=width, joint='curve')
    for x, y in (points[0], points[-1]):
        r = width / 2
        pen.ellipse([x - r, y - r, x + r, y + r], fill='#ffffff')
    big.resize((SIZE, SIZE), Image.LANCZOS).save(out)
    sys.exit(0)

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
draw.text(((SIZE - box[2] - box[0]) / 2, (SIZE - box[3] - box[1]) / 2), letter,
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

# The README is written once and then left alone, because it is the natural place to add
# notes about the app that the generator knows nothing about. Delete it and regenerate to
# get a fresh one.
if [[ ! -f $PROJ/README.md ]]; then
cat > "$PROJ/README.md" <<EOF
# $NAME (Android web app)

A full-screen WebView on <$URL>. Nothing else: no offline, no notifications.

Generated by ../webapp_generator/new_webapp.sh. Do not edit the Java, the manifest or
build.gradle here: edit webapp_generator/webapp_template and regenerate, or the next
regeneration overwrites your change.

    ../webapp_generator/new_webapp.sh --dir $DIR --force

That command needs no other options. The generator reads this app's settings back out of
gradle.properties and signing.properties, keeps the keystore, the icon and the version code,
and leaves alone any file it did not create, such as a changelog or an icon script. Pass an
option only when you want to change that one setting.

Build:   ./build.sh   ->  ./$SLUG.apk
Install: copy the APK to the phone and tap it, or
         ~/Android/sdk/platform-tools/adb install ./$SLUG.apk

The user agent claims to be $UA Chrome. That is deliberate: the "wv" token in a stock WebView
user agent makes Google refuse to sign you in, and a mobile token makes sites serve their phone
layout. See buildUserAgent() in the template.

KEEP $STORE_FILE. Without it a rebuilt APK can no longer install over the copy on the phone.
EOF
fi

"$PROJ/build.sh"
echo
echo "Project: $PROJ"
echo "Name:    $NAME    id: $APPID    version code: $VERSION_CODE    ua: $UA"

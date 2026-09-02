# webapp_generator

Turns a URL into an installable Android app: a full-screen WebView on that one site, with its
own launcher icon, its own entry in recents, no address bar and its own cookie jar. Android's
"add to home screen" only makes a browser shortcut for sites that ship no PWA manifest, which
is what this exists to replace.

It does **not** give you offline access, notifications or widgets. Those need a real native
client against the site's API.

## Usage

    ./new_webapp.sh --name NAME --url URL [options]

Apps are built into the parent directory as `webapp_<slug>/`, so this generator sits beside
the projects it makes.

## Examples

    # Simplest case: name and URL, nothing else.
    ./new_webapp.sh --name Wikipedia --url https://en.wikipedia.org/
    
    # Force the site's wide layout. Google Tasks on a phone user agent shows one list at a
    # time behind a dropdown; on a desktop one it shows every list side by side.
    ./new_webapp.sh --name Tasks --url https://tasks.google.com/ --ua desktop
    
    # Your own icon and tile colour instead of the generated letter.
    ./new_webapp.sh --name Home --url https://192.168.129.100:8123/ --icon ~/ha.png --bg '#41BDF5'
    
    # A site whose login lives on another domain: keep that domain inside the app, or the
    # sign-in redirect escapes to the browser and the app never gets the session cookie.
    ./new_webapp.sh --name Jira --url https://example.atlassian.net/ --extra-hosts atlassian.com,okta.com
    
    # Update an existing app. No other options are needed: the settings are read back out
    # of the project, so this rebuilds it exactly as it was.
    ./new_webapp.sh --dir webapp_google_tasks --force

    # Change one setting on an existing app. Everything else stays as it was.
    ./new_webapp.sh --dir webapp_google_tasks --ua mobile --force

## Options

| Option | Meaning |
|---|---|
| `--name NAME` | Label under the launcher icon. Required. |
| `--url URL` | Page the app opens. Required. |
| `--id APPID` | Android package id. Default `com.md.<slug>`. Two apps with the same id cannot coexist. |
| `--dir DIR` | Project directory. Default `webapp_<slug>`. |
| `--icon FILE.png` | Launcher icon. Default: the app's first letter on a coloured tile. |
| `--bg '#RRGGBB'` | Icon background. Default `#1A73E8`. |
| `--ua desktop\|mobile` | Which layout the site serves. Default `mobile`. |
| `--extra-hosts H,H` | Extra hosts kept inside the app. The site's own domain is always kept; everything else opens in the browser. |
| `--login-hosts H` | Sign-in domains that always get the phone user agent, even in desktop mode. Default `accounts.google.com`. A desktop user agent from a phone is refused by sign-in pages. |
| `--version-code N` | Force a version code. |
| `--force` | Update an existing project. Required before it will touch one. |
| `--session-cookie C` | Cookie name that proves a signed-in session, so the app knows when it may switch from the sign-in user agent to the configured one. Default none, meaning any cookie counts. |

## Why the user agent is faked

A stock Android WebView announces itself with a `wv` token. Google refuses to run sign-in when
it sees that token - you get "this browser or app may not be secure" and can never log in. The
template rewrites the user agent into the plain Chrome form, reusing the real Chrome version
already in the string. `--ua desktop` additionally drops the `Mobile` and `Android` tokens,
which is what makes a site serve its wide layout.

## Keys

Each app gets its own keystore in its project directory. **Do not lose it.** Android will not
install an APK over an app signed with a different key, so a lost keystore means uninstalling
the app from the phone before you can update it. `--force` preserves it.

## Layout

    webapp_generator/
      new_webapp.sh        this script
      webapp_template/     the actual app source, one copy for all apps
    webapp_<slug>/         each generated app: gradle.properties, keystore, build.sh, APK

Only `gradle.properties` differs between generated apps. Edit the template, not a generated
app - regenerating overwrites it.

## Toolchain

JDK 17, Android SDK and Gradle 8.7 live in `~/Android` (~1.8 GB), nothing installed
system-wide. `rm -rf ~/Android` removes it; nothing else on the machine depends on it.

## Regenerating an existing app

Regeneration is not destructive. The generator lays the template over the project rather than
replacing it, so it only touches files it owns:

| Kept | Refreshed |
| --- | --- |
| The settings, read back from `gradle.properties` and `signing.properties`, so options you gave last time do not have to be repeated | The Java source, the manifest, `build.gradle`, the theme resources, everything that comes from the template |
| The keystore, the version code, and the launcher icon | `gradle.properties`, `signing.properties`, `build.sh`, `local.properties` |
| `README.md`, written once and never overwritten, so notes you add survive | |
| Any file the generator never created, a changelog or an icon script for instance | |

An option on the command line always wins over the stored value, so changing one thing is a
single flag and everything else stays as it was. The version code is never changed on its
own; pass `--version-code` when you want a new one.

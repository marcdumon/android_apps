# Changelog

`versionName` always mirrors `versionCode`: version 1.N is versionCode N. Every version that
was released and confirmed working on a device carries a git tag
`webapp_google_tasks-vX.Y`. Versions listed here without a tag say why.

## 1.6, versionCode 6

Launcher icon is a tick instead of the app's first letter, drawn by `make_icon.py`. The
letter was the generator's fallback for apps built without an icon file.

Follows the system light and dark setting. The app was pinned to a light theme, and a WebView
reports the app's theme to the page, so the page was always told light. There is now an
`AppTheme` with a `values-night` variant, the WebView is allowed to darken pages that do not
handle dark themselves, and its background is painted dark so there is no white flash before
the page draws. `uiMode` was removed from `configChanges` so the activity is recreated when
the setting changes; without that nothing re-themes until the app is killed.

Confirmed working on a device. Not tagged: version numbering and tagging are decided
separately.

## 1.5, versionCode 5 (tagged)

Google sign-in works. The user agent is chosen once at startup and never changed while a page
is loading. Until a session cookie is present the app runs on the phone user agent, which
sign-in accepts; afterwards it uses the desktop one, so restart the app once after signing in
to get the side-by-side lists.

## 1.4, versionCode 4 (withdrawn, never worked)

Attempted to switch the user agent per host, changing it when a redirect reached
`accounts.google.com`. Android restarts the current page load whenever the user agent
changes, so the restart went back to the start URL, which selected the other user agent,
which restarted the load again. The app showed a white screen and never settled.

No tag: it was never a working release. Superseded by 1.5.

## 1.3, versionCode 3 (tagged)

First version under version control, so this is where the repository history begins. Desktop
user agent throughout, which gives the side-by-side task lists but means Google refuses to
run sign-in.

## 1.0 to 1.2, versionCode 1 to 2

Built before the project was in git, while the app was still being worked out: first working
container, then the icon and signing setup, then the switch to a desktop user agent to get
all task lists shown at once instead of one at a time behind a dropdown.

No tags: no commits exist for them.

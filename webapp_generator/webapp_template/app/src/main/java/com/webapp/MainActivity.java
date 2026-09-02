package com.webapp;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.CookieManager;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Full-screen container around one website.
 *
 * The site, the user agent mode and the list of extra hosts that stay inside the app all come
 * from BuildConfig, so this file is identical in every app generated from this template.
 */
public class MainActivity extends Activity {

    private WebView web;
    private String homeDomain;
    private String siteUserAgent;
    private String loginUserAgent;
    private boolean signedIn;

    private static final String PREFS = "webapp";
    private static final String KEY_SIGNED_IN = "signed_in";

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedState) {
        super.onCreate(savedState);

        homeDomain = registrableDomain(Uri.parse(BuildConfig.START_URL).getHost());

        web = new WebView(this);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(true);
        s.setBuiltInZoomControls(true);
        s.setDisplayZoomControls(false);
        // Dropping the "wv" token is what lets Google and other providers run sign-in at
        // all; they refuse a WebView and detect it from that token. "desktop" additionally drops
        // the Mobile/Android tokens, which is how you get a site's wide layout on a phone.
        //
        // A desktop user agent coming from a phone is contradicted by everything else the
        // WebView reveals, and sign-in pages reject that outright. So the hosts listed in
        // LOGIN_HOSTS get the plain phone user agent instead, and the site itself keeps the
        // configured one. Sign in once, and the cookie keeps you in from then on.
        //
        // The user agent is chosen once here and never touched again: Android restarts the
        // current load whenever it changes, so changing it on a redirect sends the sign-in
        // flow into an endless reload. Until the account is signed in, the whole app uses the
        // phone user agent so the sign-in page accepts it. Afterwards it uses the configured
        // one, which for a desktop mode app is what shows the full-width layout.
        String stock = s.getUserAgentString();
        siteUserAgent = buildUserAgent(stock, BuildConfig.UA_MODE);
        loginUserAgent = buildUserAgent(stock, "mobile");
        signedIn = getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_SIGNED_IN, false);
        boolean needsSignIn = !signedIn && !BuildConfig.LOGIN_HOSTS.isEmpty();
        s.setUserAgentString(needsSignIn ? loginUserAgent : siteUserAgent);
        // Popups would open a second, invisible WebView; force everything into this one.
        s.setSupportMultipleWindows(false);
        s.setJavaScriptCanOpenWindowsAutomatically(true);

        // Third-party cookies are needed by most external sign-in handoffs, and are what
        // keeps you logged in between launches.
        CookieManager cookies = CookieManager.getInstance();
        cookies.setAcceptCookie(true);
        cookies.setAcceptThirdPartyCookies(web, true);

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri url = request.getUrl();
                if (staysInApp(url)) {
                    return false;
                }
                openExternally(url);
                return true;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                rememberSignedIn(url);
            }
        });

        if (savedState != null) {
            web.restoreState(savedState);
        } else {
            web.loadUrl(BuildConfig.START_URL);
        }
    }

    /**
     * Rewrites the stock WebView user agent.
     *
     * Reuses the Chrome version already in the string so it stays honest. "desktop" claims to be
     * Chrome on Linux; anything else keeps the phone identity but without the WebView marker.
     */
    /**
     * Once the site itself loads with cookies set, the account is signed in, so later launches
     * can use the configured user agent. Changing it now would restart the load, so the flag is
     * only read at startup.
     */
    private void rememberSignedIn(String url) {
        if (signedIn || url == null) {
            return;
        }
        String host = Uri.parse(url).getHost();
        if (host == null || !homeDomain.equals(registrableDomain(host))) {
            return;
        }
        String cookie = CookieManager.getInstance().getCookie(url);
        if (cookie != null && !cookie.isEmpty()) {
            signedIn = true;
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_SIGNED_IN, true).apply();
        }
    }

    private static boolean isLoginHost(String host) {
        if (host == null || BuildConfig.LOGIN_HOSTS.isEmpty()) {
            return false;
        }
        for (String entry : BuildConfig.LOGIN_HOSTS.split(",")) {
            String candidate = entry.trim();
            if (!candidate.isEmpty() && (host.equals(candidate) || host.endsWith("." + candidate))) {
                return true;
            }
        }
        return false;
    }

    private static String buildUserAgent(String webViewUserAgent, String mode) {
        Matcher m = Pattern.compile("Chrome/([0-9.]+)").matcher(webViewUserAgent);
        String version = m.find() ? m.group(1) : "131.0.0.0";
        if ("desktop".equals(mode)) {
            return "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/"
                    + version + " Safari/537.36";
        }
        return webViewUserAgent
                .replace("; wv)", ")")
                .replaceAll(" Build/[^);]*", "")
                .replaceAll("Version/[0-9.]+ ", "");
    }

    /** True when a URL should load inside the app rather than being handed to the browser. */
    private boolean staysInApp(Uri url) {
        String scheme = url.getScheme();
        if (scheme == null || !(scheme.equals("http") || scheme.equals("https"))) {
            return false;
        }
        String host = url.getHost();
        if (host == null) {
            return false;
        }
        if (registrableDomain(host).equals(homeDomain)) {
            return true;
        }
        for (String extra : BuildConfig.EXTRA_HOSTS.split(",")) {
            extra = extra.trim();
            if (!extra.isEmpty() && (host.equals(extra) || host.endsWith("." + extra))) {
                return true;
            }
        }
        return false;
    }

    /**
     * Last two labels of a host, so app.example.com and example.com count as the same site.
     *
     * Deliberately naive: it treats co.uk as the registrable domain. Fine for a personal
     * container, since the only effect of getting it wrong is a link opening in the browser.
     */
    private static String registrableDomain(String host) {
        if (host == null) {
            return "";
        }
        String[] labels = host.split("\\.");
        if (labels.length < 2) {
            return host;
        }
        return labels[labels.length - 2] + "." + labels[labels.length - 1];
    }

    /** Hands a link the app does not own to the system. */
    private void openExternally(Uri url) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, url));
        } catch (ActivityNotFoundException e) {
            Toast.makeText(this, "No app can open " + url, Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) {
            web.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        // Without this flush the session cookie can be lost when Android kills the app.
        CookieManager.getInstance().flush();
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }
}

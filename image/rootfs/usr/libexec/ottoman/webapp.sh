#!/bin/bash
# ottoman-webapp <site-id> <url>: run a streaming site as a TV app in Firefox (Flathub org.mozilla.firefox) kiosk
# mode with its own profile. Widevine is Firefox's own CDM (software, L3: ~720p-1080p on these services,
# never 4K; measured 2026-11-03 in the VM). The profile's user.js enables DRM and suppresses first-run UI.
set -euo pipefail
SITE=${1:?site id}; URL=${2:?url}
APPDIR="$HOME/.var/app/org.mozilla.firefox"
PROFILE="$APPDIR/ottoman/$SITE"
mkdir -p "$PROFILE"
cat > "$PROFILE/user.js" <<'PREFS'
user_pref("media.eme.enabled", true);
user_pref("media.gmp-widevinecdm.enabled", true);
user_pref("media.gmp-widevinecdm.visible", true);
user_pref("media.gmp-widevinecdm.autoupdate", true);
user_pref("media.gmp-manager.updateEnabled", true);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyAcceptedVersion", 2);
user_pref("datareporting.policy.dataSubmissionPolicyNotifiedTime", "1");
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("termsofuse.acceptedVersion", 5);
user_pref("termsofuse.acceptedDate", "1");
user_pref("termsofuse.bypassNotification", true);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("full-screen-api.warning.timeout", 0);
PREFS
exec flatpak --user run org.mozilla.firefox --no-remote --profile "$PROFILE" --kiosk "$URL"

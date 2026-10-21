#!/bin/bash
# Install the TvHome launcher on the TV and test it (opens it directly; does NOT make it the default yet).
# Usage: ./scripts/04-install-launcher.sh            use dist/TvHome.apk (or download it from GitHub)
#        ./scripts/04-install-launcher.sh --build    build from launcher/ (Android SDK + JDK 17 needed)
#        ./scripts/04-install-launcher.sh <file.apk> install a specific APK
source "$(dirname "$0")/lib.sh"
LOG="$ROOT/state/install-launcher.log"; exec > >(tee "$LOG") 2>&1
PKG=net.amirul.tvhome; ACT=$PKG/.HomeActivity
APK="$ROOT/state/TvHome.apk"
case "${1:-}" in
  --build)
    export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    [ -d "$ANDROID_HOME" ] || export ANDROID_HOME="$HOME/Android/Sdk"
    [ -d "$ANDROID_HOME" ] || export ANDROID_HOME="/usr/lib/android-sdk"
    command -v /usr/libexec/java_home >/dev/null && export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || echo "${JAVA_HOME:-}")"
    case "${JAVA_HOME:-}" in *jdk-1[789]*|*java-1[789]*) : ;; *)
      command -v javac >/dev/null && echo "   NOTE: Gradle 8.5.2 wants JDK 17; \`javac -version\` says $(javac -version 2>&1)";; esac
    cd "$ROOT/launcher"; echo "sdk.dir=$ANDROID_HOME" > local.properties
    # Release, not debug: a debug build is android:debuggable="true", which lets any ADB shell read/write
    # the launcher's private prefs via run-as. See docs/SECURITY.md.
    if [ ! -f "$ROOT/state/keystore.properties" ]; then
      echo "!! No state/keystore.properties - a release build needs a signing keystore."
      echo "   Create one (once, keep it out of git):"
      echo "     mkdir -p $ROOT/state"
      echo "     keytool -genkeypair -keystore $ROOT/state/tvhome.keystore -alias tvhome \\"
      echo "       -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=TvHome, O=Local, C=MY'"
      echo "     printf 'storeFile=../state/tvhome.keystore\\nstorePassword=CHANGE_ME\\nkeyAlias=tvhome\\nkeyPassword=CHANGE_ME\\n' \\"
      echo "       > $ROOT/state/keystore.properties && chmod 600 $ROOT/state/keystore.properties"
      echo "   Or install a pre-built APK: ./scripts/04-install-launcher.sh <file.apk>"
      exit 1
    fi
    if [ ! -f gradle/wrapper/gradle-wrapper.jar ]; then
      T=$(mktemp -d); ( cd "$T" && touch settings.gradle && gradle -q wrapper --gradle-version 8.7 --distribution-type all ) || { echo "!! needs 'gradle' once to create the wrapper"; exit 1; }
      cp -R "$T/gradlew" "$T/gradlew.bat" "$T/gradle" . ; rm -rf "$T"
    fi
    chmod +x gradlew; ./gradlew --no-daemon -q assembleRelease || { echo "!! BUILD FAILED"; exit 1; }
    cp app/build/outputs/apk/release/app-release.apk "$APK"; cd "$ROOT";;
  "")
    REPO="${REPO:-$(git -C "$ROOT" remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]##; s#\.git$##')}"
    REPO="${REPO:-amirulmzlan/android-tv-debloat}"
    if [ -f "$ROOT/dist/TvHome.apk" ]; then
      echo "== Using dist/TvHome.apk from this repository"; cp "$ROOT/dist/TvHome.apk" "$APK"
    else
      echo "== Downloading TvHome.apk from github.com/$REPO"
      curl -fL -o "$APK" "https://github.com/$REPO/releases/latest/download/TvHome.apk" 2>/dev/null || \
      curl -fL -o "$APK" "https://github.com/$REPO/raw/main/dist/TvHome.apk" || { echo "!! download failed - try --build"; exit 1; }
    fi;;
  *) cp "$1" "$APK";;
esac
echo "== APK: $(wc -c < "$APK" | tr -d ' ') bytes"

# Refuse a debuggable APK. A debug TvHome lets any ADB shell read/write its private prefs via run-as on
# Android TV (docs/SECURITY.md). Check the manifest before it ever reaches the TV.
# NOTE: aapt shows aapt's binary encoding: android:debuggable=(type 0x12)0xffffffff is TRUE, 0x0 is false.
# Many release manifests still carry android:debuggable="false" explicitly, which is harmless - only reject true.
manifest_debuggable() {
  if command -v aapt >/dev/null 2>&1; then
    aapt dump xmltree "$1" AndroidManifest.xml 2>/dev/null | grep -i 'debuggable' | grep -qiE '0xffffffff|="true"'
  elif command -v apkanalyzer >/dev/null 2>&1; then
    apkanalyzer manifest print "$1" 2>/dev/null | grep -i 'debuggable' | grep -qi 'true'
  else
    return 2   # cannot tell
  fi
}
manifest_debuggable "$APK"; MD=$?
case "$MD" in
  0) echo "!! REFUSING: $APK declares android:debuggable=\"true\"."
     echo "   A debuggable HOME app can be taken over from any ADB shell (run-as). Build with --build (release)"
     echo "   or strip it first. See docs/SECURITY.md."
     exit 1 ;;
  2) echo "   NOTE: aapt/apkanalyzer not found - cannot pre-check the manifest for android:debuggable."
     echo "         scripts/07-verify-hardening.sh will check the installed package." ;;
  *) echo "   manifest: not debuggable OK" ;;
esac

[ -f "$ROOT/state/stock-home.txt" ] || S cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1 > "$ROOT/state/stock-home.txt"
echo "== Installing (if this hangs on Android 14, look at the TV for a confirmation)"
if ! A install -r "$APK"; then
  echo "   adb install failed; trying push + pm install"
  A push "$APK" /data/local/tmp/tvhome.apk >/dev/null && S pm install -r /data/local/tmp/tvhome.apk
fi
if ! S pm path $PKG | grep -q package:; then
  echo "!! The TV refused the launcher. If the error was INSTALL_FAILED_VERIFICATION_FAILURE or about HOME/signatures,"
  echo "   this TV can't use a custom launcher (examples/README.md, cases B/C). The debloat still stands."; exit 1
fi
S pm grant $PKG android.permission.ACCESS_COARSE_LOCATION 2>/dev/null   # lets the Wi-Fi pill show the network name
S logcat -c -b crash
echo "== Opening TvHome directly"
S am start -W -n $ACT | grep -E 'Status'; sleep 4
echo "   top: $(top)"; shot launcher-01-open
k KEYCODE_DPAD_RIGHT;            shot launcher-02-dock-right
k KEYCODE_DPAD_UP;               shot launcher-03-topbar
k KEYCODE_DPAD_LEFT; k KEYCODE_DPAD_LEFT; k KEYCODE_DPAD_LEFT
k KEYCODE_DPAD_CENTER 2;         shot launcher-04-inputs
k KEYCODE_BACK
k KEYCODE_DPAD_DOWN; k KEYCODE_DPAD_DOWN 1.6; shot launcher-05-grid
k KEYCODE_DPAD_UP 1.6;           shot launcher-06-back-to-dock
echo "   memory: $(S dumpsys meminfo $PKG | grep -m1 TOTAL)"
CR=$(S logcat -d -b crash | grep -c "$PKG"); echo "   crashes: $CR"
[ "$CR" != 0 ] && S logcat -d -b crash | grep -A20 "Process: $PKG" | head -30
echo "== Done. Tell your AI agent 'done'."

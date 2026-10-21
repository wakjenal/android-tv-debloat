#!/bin/bash
# Regression test for the debuggable-APK guard used by 04-install-launcher.sh and docs/SECURITY.md.
# No TV needed. Pass any number of APKs (or none - it makes its own tiny fixture with aapt if available).
#
# Usage: ./scripts/test-debuggable-guard.sh [apk ...]
#
# Why this exists: the first version of the guard grepped for the word "debuggable" and rejected *every* APK,
# including a good release build whose manifest merely says android:debuggable="false" (aapt encodes that as
# (type 0x12)0x0). Rejecting a safe APK is as bad as accepting an unsafe one - both break the install step.
set -u
exec 2>&1

# --- the function under test (kept byte-identical to 04-install-launcher.sh) ---
manifest_debuggable() {
  if command -v aapt >/dev/null 2>&1; then
    aapt dump xmltree "$1" AndroidManifest.xml 2>/dev/null | grep -i 'debuggable' | grep -qiE '0xffffffff|="true"'
  elif command -v apkanalyzer >/dev/null 2>&1; then
    apkanalyzer manifest print "$1" 2>/dev/null | grep -i 'debuggable' | grep -qi 'true'
  else
    return 2   # cannot tell
  fi
}

PASS=0; FAIL=0
expect() { # expect <true|false> <apk> <label>
  manifest_debuggable "$2"; local rc=$?
  local want="$1" got
  case "$rc" in 0) got=true ;; 1) got=false ;; *) got=unknown ;; esac
  if [ "$got" = "$want" ]; then echo "   PASS  $3 -> debuggable=$got"; PASS=$((PASS+1));
  else echo "   FAIL  $3 -> expected debuggable=$want, got $got (rc=$rc)"; FAIL=$((FAIL+1)); fi
}

if [ $# -gt 0 ]; then
  for apk in "$@"; do
    # default expectation: a shipped APK must not be debuggable
    expect false "$apk" "$(basename "$apk")"
  done
else
  command -v aapt >/dev/null 2>&1 || { echo "SKIP: aapt not found and no APKs given"; exit 0; }
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  mkdir -p "$T/dbg" "$T/rel"
  # A minimal APK-shaped zip is not enough for aapt; build a manifest-only fixture with aapt/zip instead.
  # aapt2 compile+link is the portable way to get a real binary manifest.
  if command -v aapt2 >/dev/null 2>&1 && command -v zip >/dev/null 2>&1; then
    for v in true false; do
      d="$T/${v}"; mkdir -p "$d"
      cat > "$d/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="net.amirul.test.${v}">
    <application android:debuggable="${v}" android:label="t"/>
</manifest>
EOF
      aapt2 link -o "$T/${v}.apk" --manifest "$d/AndroidManifest.xml" -I "$(aapt2 dump packagename /dev/null 2>/dev/null; echo)" 2>/dev/null \
        || aapt2 link -o "$T/${v}.apk" --manifest "$d/AndroidManifest.xml" 2>/dev/null \
        || { echo "SKIP: aapt2 link could not build a fixture (needs android.jar)"; exit 0; }
    done
    expect true  "$T/true.apk"  "fixture debuggable=true"
    expect false "$T/false.apk" "fixture debuggable=false"
  else
    echo "SKIP: need aapt2 + zip to build fixtures, or pass APKs as arguments"
    exit 0
  fi
fi

echo "== Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

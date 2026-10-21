#!/bin/bash
# Verify the things that actually matter for safety on this TV: the launcher is not debuggable, HOME is the
# launcher actually running, Private DNS is still AdGuard, and ADB is still authenticated.
# Read-only - changes nothing on the TV.
# Usage: ./scripts/07-verify-hardening.sh
source "$(dirname "$0")/lib.sh"
PKG=net.amirul.tvhome
PASS=0; FAIL=0
ok()   { echo "   PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "   FAIL  $1"; FAIL=$((FAIL+1)); }
info() { echo "   ....  $1"; }

echo "== Device"
info "$(S getprop ro.product.model) / $(S getprop ro.product.device) / Android $(S getprop ro.build.version.release) API $(S getprop ro.build.version.sdk)"
info "abi=$(S getprop ro.product.cpu.abi) abilist64=$(S getprop ro.product.cpu.abilist64)"

echo ""
echo "== 1. Launcher is installed and not debuggable"
if S pm path $PKG | grep -q '^package:'; then ok "installed: $(S pm path $PKG | head -1 | sed 's/^package://')"
else bad "not installed"; fi
FLAGS=$(S dumpsys package $PKG 2>/dev/null | grep -m1 'flags=' | tr -d ' ')
if echo "$FLAGS" | grep -q 'DEBUGGABLE'; then
  bad "debuggable flag present -> any ADB shell can run-as into the launcher"
elif [ -n "$FLAGS" ]; then
  ok "not debuggable ($FLAGS)"
else
  bad "could not read package flags"
fi
RA=$(S run-as $PKG id 2>&1)
case "$RA" in
  *'not debuggable'*) ok "run-as refused: $RA" ;;
  uid=*)              bad "run-as SUCCEEDED: $RA" ;;
  *)                  info "run-as: $RA" ;;
esac

echo ""
echo "== 2. HOME is the launcher"
HOMER=$(S cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)
case "$HOMER" in
  *$PKG*|*HomeActivity*) ok "resolve-activity -> $HOMER" ;;
  *)                     bad "resolve-activity -> $HOMER" ;;
esac
RES=$(top)
case "$RES" in
  *$PKG*) ok "on screen: $RES" ;;
  *)      info "current top: $RES (may be another app; press Home and re-run)" ;;
esac

echo ""
echo "== 3. Private DNS"
MODE=$(S settings get global private_dns_mode)
SPEC=$(S settings get global private_dns_specifier)
if [ "$MODE" = "hostname" ] && [ -n "$SPEC" ] && [ "$SPEC" != "null" ]; then
  ok "private_dns_mode=$MODE specifier=$SPEC"
else
  bad "private_dns_mode=$MODE specifier=$SPEC (AdGuard not active)"
fi
case "$SPEC" in *adguard*) ok "AdGuard specifier set" ;; *) bad "not an AdGuard hostname" ;; esac

echo ""
echo "== 4. ADB authorisation"
info "ro.adb.secure=$(S getprop ro.adb.secure)  ro.debuggable=$(S getprop ro.debuggable)"
[ "$(S getprop ro.adb.secure)" = "1" ] && ok "ADB requires authorisation" || bad "ro.adb.secure != 1"
[ "$(S getprop ro.debuggable)" = "0" ] && ok "ro.debuggable=0" || bad "ro.debuggable=$(S getprop ro.debuggable)"

echo ""
echo "== 5. Boot integrity"
info "verified boot: $(S getprop ro.boot.verifiedbootstate)  bootloader: $(S getprop ro.boot.flash.locked)  verity: $(S getprop ro.boot.veritymode)"
info "selinux: $(S getenforce)  build: $(S getprop ro.build.type)/$(S getprop ro.build.tags)"
[ "$(S getenforce)" = "Enforcing" ] && ok "SELinux Enforcing" || bad "SELinux $(S getenforce)"

echo ""
echo "== 6. Package state"
info "enabled: $(S pm list packages -e | wc -l | tr -d ' ')  disabled: $(S pm list packages -d | wc -l | tr -d ' ')"
for p in com.android.vending com.google.android.gms com.android.tv.settings com.android.systemui; do
  if S pm list packages -e | grep -qx "package:$p"; then ok "core kept: $p"; else bad "core missing/disabled: $p"; fi
done

echo ""
echo "== 7. Memory"
S dumpsys meminfo | grep -E 'MemTotal|MemFree|MemAvailable' | sed 's/^ */   ....  /'
SW=$(S cat /proc/meminfo | grep -iE '^SwapTotal|^SwapFree' | tr -s ' ' | tr '\n' ' ')
[ -n "$SW" ] && info "swap meminfo: $SW" || info "swap: not reported on this kernel"

echo ""
echo "== Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1

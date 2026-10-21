#!/bin/bash
# Re-enable everything the scripts disabled (or one package) and optionally put DNS/stock home back.
# Usage: ./scripts/restore.sh                       re-enable every recorded package, keep Private DNS as-is
#        ./scripts/restore.sh --keep-dns            same, explicit: do not touch Private DNS
#        ./scripts/restore.sh --reset-dns           re-enable everything AND put Private DNS back to automatic
#        ./scripts/restore.sh <package>             just one package
#
# By default Private DNS is left alone: this kit sets AdGuard DNS in phase 4 and silently undoing that
# is a surprise (and loses ad/tracker blocking). Pass --reset-dns if you really want the stock setting.
source "$(dirname "$0")/lib.sh"

KEEP_DNS=1
RESET_DNS=0
ARG=""
for a in "$@"; do
  case "$a" in
    --keep-dns)  KEEP_DNS=1 ;;
    --reset-dns) RESET_DNS=1; KEEP_DNS=0 ;;
    -h|--help)   sed -n '2,9p' "$0"; exit 0 ;;
    *)           ARG="$a" ;;
  esac
done

if [ -n "$ARG" ]; then LIST="$ARG"; else LIST=$(sort -u "$ROOT/state/disabled.txt" 2>/dev/null); fi
[ -z "$LIST" ] && echo "Nothing recorded as disabled."

for p in $LIST; do
  echo "   enable $p: $(S pm enable --user 0 "$p")"
  [ -n "$ARG" ] && { grep -vx "$p" "$ROOT/state/disabled.txt" > "$ROOT/state/.d" 2>/dev/null; mv "$ROOT/state/.d" "$ROOT/state/disabled.txt"; }
done

if [ -z "$ARG" ]; then
  if [ "$RESET_DNS" = 1 ]; then
    S settings put global private_dns_mode opportunistic; echo "   Private DNS back to automatic (--reset-dns)."
  elif [ "$KEEP_DNS" = 1 ]; then
    echo "   Private DNS left as-is: $(S settings get global private_dns_mode) $(S settings get global private_dns_specifier)"
  fi
  [ -f "$ROOT/state/stock-home.txt" ] && { H=$(cat "$ROOT/state/stock-home.txt"); S cmd package set-home-activity "$H" >/dev/null; echo "   Home set back to $H"; }
  : > "$ROOT/state/disabled.txt"
fi

echo "Still disabled on the TV:"; S pm list packages -d

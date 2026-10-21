# Xiaomi Mi Box S 2nd gen (MiTV-AFKR0 / "jaws") — Android 14

A complete, tested debloat profile for the **global** Mi Box S 2nd gen. Verified on firmware
`V816.0.26.4.17.UZFAABX` (Android 14 / API 34) with a **32-bit only** `armeabi-v7a` userspace.

- Device notes, full package table and gotchas: [`examples/xiaomi-mitv-afkr0-jaws.md`](../examples/xiaomi-mitv-afkr0-jaws.md)
- Security notes (debuggable launcher, ADB, DNS): [`docs/SECURITY.md`](../docs/SECURITY.md)
- Open the batch lists in [`lists/jaws/`](../lists/jaws/) — apply them in order.

## Quick start

```bash
./scripts/01-connect-and-backup.sh 192.168.0.25        # read-only backup, approve the TV dialog
./scripts/02-debloat.sh lists/jaws/01-telemetry.txt    # then 02, 03 ... one batch at a time
./scripts/03-adblock-dns.sh                            # AdGuard Private DNS (optional)
./scripts/04-install-launcher.sh --build               # release build (needs JDK 17 + Android SDK)
./scripts/05-activate-launcher.sh                      # disables launcherx, sets TvHome as HOME
./scripts/07-verify-hardening.sh                       # proves it all stuck
./scripts/close-adb.sh                                 # when you're done
```

## Do not run `restore.sh` blindly

`restore.sh` with no arguments re-enables everything it recorded — that part is fine. In **this branch** it also leaves
Private DNS alone by default, so your AdGuard setting survives a restore. Pass `--reset-dns` if you actually want the
stock `opportunistic` mode back.

## Order that works

| # | Batch | What it kills |
|---|---|---|
| 1 | `01-telemetry.txt` | Xiaomi/Google analytics, feedback, partnersetup |
| 2 | `02-ads-rows.txt` | PatchWall rows, michannel, mitvplus, oemtab, webcontent |
| 3 | `03-background.txt` | Print spooler, calendar sync, Xiaomi update/smartshare/wfd |
| 4 | `04-preloads.txt` | Gallery, Mi Music, media explorer, Play Games, videos, dreamx, talkback |
| 5 | `05-optional.txt` | Chromecast, Google TV remote, axel, setupwraith, remote pairing — **ask first** |
| 6 | — | PatchWall `com.mitv.tvhome.atv` and Prime Video are `pm uninstall --user 0`; see the device notes |

The launcher step (`05-activate-launcher.sh`) is last because it disables `com.google.android.apps.tv.launcherx`.

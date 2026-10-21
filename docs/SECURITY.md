# Security notes

This kit touches system packages and installs a home-screen replacement over ADB. None of that needs root, but a few
things are worth getting right. Everything below was verified on a real **Xiaomi Mi Box S 2nd gen (MiTV-AFKR0, Android 14)**;
the same reasoning applies to any Android TV / Google TV device.

## The launcher must not be debuggable

**`dist/TvHome.apk` in this repo is still a debug build.** It was produced by `./gradlew assembleDebug`, so an installed
package reports:

```
flags=[ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ]
```

With `DEBUGGABLE` set, **any** ADB shell on the box — no root needed — can take over the launcher's private data:

```bash
adb shell run-as net.amirul.tvhome cat shared_prefs/home.xml
adb shell run-as net.amirul.tvhome sh -c 'echo ... > shared_prefs/home.xml'
```

`home.xml` holds `gridPkg`, `dock`, `top` and `region`. Changing `gridPkg` points the launcher's default focus at a
package of the attacker's choosing; on a launcher that is also a `HOME` handler that is a meaningful hook.

### Check any TvHome build before installing

```bash
# 1. Is the flag true in the APK's manifest?
#    aapt encodes the boolean: 0xffffffff = true, 0x0 = false. A release manifest may still say
#    android:debuggable="false", which is harmless - only 0xffffffff (or ="true") is a problem.
aapt dump xmltree dist/TvHome.apk AndroidManifest.xml | grep -i debuggable
#   bad : android:debuggable(0x0101000f)=(type 0x12)0xffffffff
#   good: android:debuggable(0x0101000f)=(type 0x12)0x0   (or no line at all)

#    scripts/test-debuggable-guard.sh covers this decision in both directions.

# 2. Or ask the TV after installing (definitive):
adb shell dumpsys package net.amirul.tvhome | grep -m1 'flags='
#   good: flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ]
#   bad : flags=[ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ]

# 3. And try it:
adb shell run-as net.amirul.tvhome id
#   good: run-as: package not debuggable: net.amirul.tvhome
```

`scripts/07-verify-hardening.sh` runs all of the above plus the DNS and HOME checks.

### What changed in this branch

- `launcher/app/build.gradle` gained a `release` build type with `minifyEnabled` and a signing config, so
  `./gradlew assembleRelease` produces a non-debuggable APK.
- `scripts/04-install-launcher.sh --build` now runs `assembleRelease`, and **refuses to install** an APK whose manifest
  declares `android:debuggable="true"`.
- `scripts/07-verify-hardening.sh` is new and verifies the installed package.

> If you build your own, keep the keystore. Android refuses to update a package when the signing certificate changes,
> which forces an uninstall/reinstall and loses the launcher's settings. `scripts/04-install-launcher.sh --build`
> stores it under `state/` (git-ignored).

## ADB over Wi-Fi on port 5555

`ro.adb.secure=1`, so a new host must be approved in the on-TV dialog — but **anyone on the same LAN who can get that
dialog approved gets a shell** (uid 2000) and can install, uninstall, screenshot and read logs. Mitigations:

- Turn USB/Network debugging **off** when you're done. `scripts/close-adb.sh` does this.
- Prefer the `adb` pairing/authorisation dialog over leaving port 5555 open permanently.
- On the box itself there is no per-app firewall and no `iptables` binary, so you cannot restrict it locally.

## Private DNS is a security control here

AdGuard Private DNS (`dns.adguard-dns.com`) blocks a useful slice of tracking and some malware C2 domains. Two things
matter:

1. **Don't let a restore script silently undo it.** Upstream `scripts/restore.sh` sets
   `private_dns_mode opportunistic` when run with no arguments. This branch keeps that behaviour only when you ask for
   it (`--reset-dns`); the default is to leave DNS alone. Pass `--keep-dns` for explicit intent.
2. **It is not a content filter.** DNS cannot separate YouTube ads from YouTube video (same `*.googlevideo.com` hosts).
   `scripts/03-adblock-dns.sh` says this too.

## Self-updating sideloaded apps

A sideloaded app that holds `REQUEST_INSTALL_PACKAGES` can prompt the user to install its own update. On Android 14 the
`appops set <pkg> REQUEST_INSTALL_PACKAGES deny` value **does not survive a reboot** — it reverts to `allow`. `pm revoke`
of normal runtime permissions does persist.

If you want the appop to stick, re-apply it after each boot, e.g. from your agent's runbook:

```bash
adb shell appops set <package> REQUEST_INSTALL_PACKAGES deny
```

## What this kit never does

No root, no `su`, no unlocking the bootloader, no flashing, no writing to `/system`, no DM-Verity changes, no
disabling of `com.android.vending` / `com.google.android.gms` / SystemUI / Settings. Every disable is `pm disable-user`
and reversible with `pm enable`, and every change is recorded in `state/disabled.txt`.

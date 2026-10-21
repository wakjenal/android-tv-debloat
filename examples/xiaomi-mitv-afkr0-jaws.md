<!--
DEVICE:     Xiaomi Mi Box S 2nd gen, model MiTV-AFKR0, codename "jaws", global firmware, Amlogic S905X2 (sc2)
ANDROID:    14 (API 34), Google TV, build UKG3.250107.001 / V816.0.26.4.17.UZFAABX
ABI:        armeabi-v7a ONLY (32-bit; abilist64 is empty)
SETUPWRAITH: disabled on this box; it does NOT own the saved Wi-Fi after setup completes
CASE:       A - sideload works, no HOME restriction; launcherx has HOME priority 2 and must be disabled
RAM:        ~1.9 GB (MemTotal 1960728 kB)
RESULT:     29 packages disabled, AdGuard Private DNS, TvHome as default home (survives reboot)
-->

# Xiaomi Mi Box S 2nd gen — MiTV-AFKR0 "jaws" (Android 14, Google TV)

Tested end to end. This is the first **Android 14 / Google TV** device in this repo, and it behaves differently from the
Android 9 Mi TV in [`xiaomi-mitv-mssp2.md`](xiaomi-mitv-mssp2.md) in several ways worth reading before you start.

## Device facts (from `getprop`)

| Property | Value |
|---|---|
| `ro.product.model` | `MiTV-AFKR0` |
| `ro.product.device` | `jaws` |
| `ro.product.brand` / `manufacturer` | `Xiaomi` |
| `ro.build.version.release` / `sdk` | `14` / `34` |
| `ro.build.display.id` | `UKG3.250107.001.V816.0.26.4.17.UZFAABX` |
| `ro.build.fingerprint` | `Xiaomi/jaws/jaws:14/UKG3.250107.001/V816.0.26.4.17.UZFAABX:user/release-keys` |
| `ro.build.version.security_patch` | `2026-03-01` |
| `ro.board.platform` | `sc2` (Amlogic) |
| `ro.product.cpu.abi` | **`armeabi-v7a`** — 32-bit only |
| `ro.product.cpu.abilist64` | *(empty)* |
| `ro.build.type` / `ro.build.tags` | `user` / `release-keys` |

### ⚠️ 32-bit only — install the v7a APK

`abilist64` is empty, so **`arm64-v8a` APKs will fail to install** (`INSTALL_FAILED_NO_MATCHING_ABIS`). Always take the
`armeabi-v7a` build, or a universal APK. Check before installing:

```bash
adb shell getprop ro.product.cpu.abilist      # armeabi-v7a,armeabi
adb shell getprop ro.product.cpu.abilist64    # (empty)
```

## Stock home screen

- Stock launcher: **`com.google.android.apps.tv.launcherx`** (Google TV), `HOME` priority **2**.
- TvHome installs with priority **0**, so `cmd package set-home-activity` alone is **not enough** — the stock launcher
  still wins the Home key. `scripts/05-activate-launcher.sh` handles this by disabling `launcherx`, which is correct here.
- `com.google.android.tungsten.setupwraith` (setup wizard) is **not** a HOME claimant on this box after setup — case D
  does not apply. It was disabled along with the other Xiaomi preloads with no effect on the saved Wi-Fi network.
- `com.android.tv.settings.system.FallbackHome` exists and works as a safety net if the launcher is ever removed.

## Disabled (29 packages, in batch order)

| Batch | Packages |
|---|---|
| Telemetry / feedback | `com.miui.tv.analytics`, `com.xiaomi.statistic`, `com.google.android.feedback`, `com.android.statementservice`, `com.google.android.partnersetup` |
| Ads & rows (PatchWall) | `com.mitv.tvhome.michannel`, `com.mitv.tvhome.mitvplus`, `com.mitv.tvhome.oemtab`, `com.xm.webcontent`, `com.xiaomi.tvqs.overseas` |
| Background / sync | `com.android.printspooler`, `com.google.android.syncadapters.calendar`, `com.xiaomi.mitv.updateservice`, `com.xiaomi.mitv.smartshare`, `com.xiaomi.wfdsinkhelperservice` |
| Preloaded apps | `com.mitv.gallery`, `com.xiaomi.mimusic2`, `com.xiaomi.mitv.mediaexplorer`, `com.google.android.play.games`, `com.google.android.videos`, `com.google.android.youtube.tvmusic`, `com.google.android.apps.tv.dreamx`, `com.google.android.marvin.talkback` |
| Person's choice | `com.google.android.apps.mediashell` (Chromecast — **only if you don't cast**), `com.google.android.tv.remote.service` (Google TV phone remote), `com.google.android.tv.axel` (Google TV "what to watch" rows), `com.google.android.tungsten.setupwraith`, `com.xiaomi.android.tvsetup.partnercustomizer` |
| Launcher step | `com.google.android.apps.tv.launcherx` |

### Removed entirely (not just disabled)

These were `pm uninstall --user 0`'d because they actively revive themselves or force-launch other packages:

| Package | Why |
|---|---|
| `com.mitv.tvhome.atv` (PatchWall) | `LaunchOtherAppsUtils` inside it kept force-starting it; needs `global.patchwall_enable=0` **and** the Play Store update APK removed, then two reboots |
| `com.amazon.amazonvideo.livingroom` (Prime Video) | Preloaded 58 MB system app; restored cleanly with `pm install-existing` during testing |

Both have system APKs on `/product`, so `pm install-existing <pkg>` brings them back. See `scripts/restore.sh`.

## Kept — needed by this box

`mitv.service`, `com.xiaomi.mitv.tvmanager`, `com.xiaomi.mitv.updateservice` (**ask first** — it's the OTA client),
`com.android.providers.tv`, `com.google.android.tv.remote.service` (**ask** — phone remote), `com.google.android.gms`,
`com.google.android.gsf`, `com.android.vending` (Play Store — **never remove**, it's also the package verifier),
`com.google.android.inputmethod.latin`, `com.google.android.apps.mediashell` (**ask** — Chromecast),
`com.mstar.netflixobserver` (Netflix button), `com.xiaomi.android.tvsetup.partnercustomizer` (**ask** — carries the
Bluetooth remote pairing screen and a global key receiver).

## Notes

- **Play Store is load-bearing.** Removing `com.android.vending` looks like a debloat win and is not: it is the package
  verifier and installer on this box. Restore with `pm install-existing com.android.vending`; the system copy lives in
  `/product/priv-app/Tubesky`.
- **`run-as` on the launcher was a real hole.** `dist/TvHome.apk` shipped as an `assembleDebug` build, so the installed
  package had `DEBUGGABLE` in its flags and `run-as net.amirul.tvhome` worked from any ADB shell — read/write access to
  `shared_prefs/home.xml` (including `gridPkg`). Fixed by building a release variant; see [`docs/SECURITY.md`](../docs/SECURITY.md).
- **Do not run `scripts/restore.sh` blindly on this box** if you care about the DNS setting: it resets Private DNS to
  `opportunistic`. Use `scripts/restore.sh <package>` to undo one package at a time, or `--keep-dns` (added in this branch).
- **AdGuard Private DNS works well here.** `dns.adguard-dns.com` resolves `doubleclick.net` and
  `googleadservices.com` to `127.0.0.1`. It does **not** block YouTube ads — ads and video come from the same
  `*.googlevideo.com` hosts.
- **Some appops reset on reboot.** `REQUEST_INSTALL_PACKAGES` set with `appops set <pkg> REQUEST_INSTALL_PACKAGES deny`
  reverts to `allow` after a reboot on Android 14. The `pm revoke` permissions do persist.
- **ADB over Wi-Fi is intermittent.** `adb connect` occasionally returns `No route to host` and recovers on retry;
  `scripts/status.sh` reconnects and reports.
- **Memory:** after a reboot with 121 packages enabled, `MemAvailable` ≈ 970 MB of 1.9 GB. Long sessions push
  `SwapUsed` past 700 MB; a reboot is the fix, not a config change.
- Camera-free box: there are no HDMI inputs or tuner of its own, so TvHome hides the **Inputs** button automatically.

## Restore

```bash
./scripts/restore.sh --keep-dns                          # re-enable every disabled package, keep AdGuard DNS
./scripts/restore.sh com.google.android.apps.tv.launcherx  # just the stock launcher
adb shell pm install-existing com.mitv.tvhome.atv        # bring PatchWall back
adb shell pm install-existing com.amazon.amazonvideo.livingroom
```

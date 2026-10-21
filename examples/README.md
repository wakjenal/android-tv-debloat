# Device notes

Each file starts with a header that tells an agent which case the TV is. Add yours with a pull request.

| Case | What happens | What to do |
|---|---|---|
| **A. Works** | Sideload OK; stock launcher must be disabled to make TvHome the default | Full debloat + launcher |
| **B. All sideloads rejected** | `INSTALL_FAILED_VERIFICATION_FAILURE` for `adb install`, `pm install`, even the maker's own APKs (reported on some China-market sets) | Debloat only. Say the launcher is impossible on this TV; stop retrying |
| **C. HOME needs the maker's signature** | Any APK declaring `CATEGORY_HOME` is refused; other APKs install fine | Debloat only (the launcher can't be the home screen) |
| **D. Google TV setup wizard claims HOME** | `com.google.android.tungsten.setupwraith` takes over Home after the stock launcher is disabled | Check `dumpsys wifi \| grep -o 'cname=[^ ]*'` first: if the wizard owns the saved Wi-Fi, have the person forget + re-join the network, then disable the wizard |

| File | Device | Case |
|---|---|---|
| [xiaomi-mitv-mssp2.md](xiaomi-mitv-mssp2.md) | Xiaomi Mi TV (MiTV-MSSP2, global), Android TV 9 | A |
| [xiaomi-mitv-afkr0-jaws.md](xiaomi-mitv-afkr0-jaws.md) | Xiaomi Mi Box S 2nd gen (MiTV-AFKR0 "jaws", global), **Google TV / Android 14, 32-bit** | A |

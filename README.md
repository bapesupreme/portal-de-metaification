# Portal De-Meta-ification (Android 9, Gen 1)

Notes and scripts from de-Facebooking a Meta Portal Gen 1 (Android 9, API 28,
`arm64-v8a`) and installing [Kiosk Satellite](https://github.com/jxlarrea/kiosk-satellite)
as a replacement kiosk launcher.

Builds on and credits:
- [fcjr/unmetaportal](https://github.com/fcjr/unmetaportal) — launcher takeover,
  account removal via CVE-2024-31317
- [starbrightlab/immortal](https://github.com/starbrightlab/immortal) — OTA/verifier
  disabling pattern
- [Kiosk Satellite](https://github.com/jxlarrea/kiosk-satellite) — the kiosk app itself

This is provided as-is for a discontinued device. No warranty; you can brick your
device if you disable the wrong system package. Read a step before you run it.

## Order matters

Disable the wipe/OTA/verifier packages **before** touching accounts. Doing it in
the wrong order (accounts first) risks the device wiping itself mid-process —
see [`docs/fdr-chain.md`](docs/fdr-chain.md) for why.

## 1. Prerequisites

- Go through stock setup once (Wi-Fi + Facebook/WhatsApp login) — you need a
  logged-in state to enable ADB in Settings in the first place.
- Enable ADB, connect:
  ```
  adb tcpip 5555
  adb connect <portal-ip>:5555
  ```
- Confirm actual CPU architecture (don't assume from other packages' `primaryCpuAbi`
  — that reflects what the *package* ships, not the device):
  ```
  adb shell getprop ro.product.cpu.abi
  ```

## 2. Disable the wipe path, OTA, and the package verifier

```
adb shell pm disable-user --user 0 com.facebook.alohaservices.deviceadmin
adb shell pm disable-user --user 0 com.facebook.aloha.otaui
adb shell pm disable-user --user 0 com.facebook.appverifier
adb shell settings put global package_verifier_enable 0
```

Confirm the wipe receiver is actually gone:
```
adb shell cmd package query-receivers -a com.facebook.aloha.action.PERFORM_FACTORY_USER_DATA_RESET
```
Expect `No receivers found`.

> `com.facebook.aloha.alohaotasetup` does not exist on this firmware build —
> only `otaui` (the prompt) was found. The full download/check-in engine's
> exact package was never identified; `system.services` and `alohaappmanager`
> were checked and ruled out as *not* it, but are load-bearing shared
> infrastructure — don't try to disable them.

## 3. Remove Facebook/Meta accounts

Uses the CVE-2024-31317 Zygote command-injection technique
(see [`scripts/remove-accounts.sh`](scripts/remove-accounts.sh), sourced from
`unmetaportal`'s `tools/portal-remove-facebook-accounts.sh`).

```
adb push scripts/remove-accounts.sh /data/local/tmp/
adb shell chmod 755 /data/local/tmp/remove-accounts.sh
adb shell sh /data/local/tmp/remove-accounts.sh
```

**Important — two of the four accounts regenerate within ~20 seconds.**
See [`docs/account-regeneration.md`](docs/account-regeneration.md). If you need
a zero-account window (e.g. for `dpm set-device-owner`), run the removal script
and the next command back-to-back, with nothing in between.

## 4. Install Kiosk Satellite

```
adb install kiosk-satellite-<version>.<abi>.apk
```

If you ever get `Activity class ... does not exist` after a plain `adb install`
on top of an existing install, do a clean reinstall instead of `-r`:
```
adb uninstall me.jxl.kiosk_satellite
adb install kiosk-satellite-<version>.<abi>.apk
```

## 5. Device ownership

Requires zero accounts at the moment this runs:
```
adb shell sh /data/local/tmp/remove-accounts.sh
adb shell dpm set-device-owner me.jxl.kiosk_satellite/.KioskAdminReceiver
```

Verify:
```
adb shell dumpsys device_policy
```
Look for a populated `Device Owner:` block.

## 6. Grant permissions

See [`scripts/grant-permissions.sh`](scripts/grant-permissions.sh) — Android
9-appropriate subset of Kiosk Satellite's permissions doc.

## 7. Kiosk mode without `set-home-activity`

`cmd package set-home-activity me.jxl.kiosk_satellite/.HomeAlias` was rejected
with `IllegalArgumentException: cannot be home on user 0` on this device —
root cause never identified (ruled out: provisioning flags, competing default
launcher, device-owner status, component enablement — see
[`docs/home-activity-issue.md`](docs/home-activity-issue.md)).

Working alternative, from `unmetaportal`'s own documented fallback for the
same failure:
```
adb shell settings put global policy_control 'immersive.full=*'
adb shell am force-stop me.jxl.kiosk_satellite
adb shell am start -S --activity-clear-task --activity-task-on-home -n me.jxl.kiosk_satellite/.MainActivity
adb shell am stack list   # find the taskId for kiosk_satellite
adb shell am task lock <taskId>
```

Note: `am task lock` fully prevents exiting the app without ADB
(`adb shell am task lock stop` to release). Test whether Kiosk Satellite's own
foreground-service auto-relaunch is sufficient for your use case before
committing to a full task lock.

## 8. Lock screen / screensaver

```
adb shell locksettings set-disabled true
adb shell settings put secure screensaver_enabled 0
```

## 9. Remove the login nag

`com.facebook.alohaapps.personaluser` owns `FacebookUserLoginActivity`
and can pop up asking you to re-log in. Narrowly scoped to login UI (not
shared infrastructure like `system.services`), safe to disable:
```
adb shell pm disable-user --user 0 com.facebook.alohaapps.personaluser
```

## Known limitations

- ADB over Wi-Fi does not survive a reboot on Android 9 (no Test Harness Mode
  — that's Android 10+ only). One USB connection + `adb tcpip 5555` is needed
  after every reboot.
- `BootReceiver` in Kiosk Satellite is registered for `BOOT_COMPLETED` but was
  observed not firing on at least one reboot in testing — cause unconfirmed.
- The real OTA download/apply engine's package was never conclusively
  identified on this firmware build.

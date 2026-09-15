# ADB & Account Removal: Android 9 vs Android 10

## The one step neither version can skip

Portal requires completing stock setup — Wi-Fi + Facebook/WhatsApp login — before
the ADB toggle in Settings is even reachable. This is true on both API 28 (Gen 1,
Android 9) and the Android 10 hardware. There is no way to reach ADB access
without going through this once. Everything below assumes that step is already
done and ADB is enabled.

## Android 9 (Gen 1 Portal, API 28)

Test Harness Mode does not exist prior to Android 10, so there is exactly one
path here:

- **CVE-2024-31317** (`scripts/remove-accounts.sh`) — spawns a shell as the
  `alohausers` UID via Zygote command injection and calls
  `AccountManagerService.removeAccount()` directly for each `com.facebook.aloha.*`
  account. Non-destructive: nothing else on the device is touched.
- ADB over Wi-Fi does not survive a reboot on Android 9 — there's no mechanism to
  persist it. Every reboot means re-tethering USB and re-running
  `adb tcpip 5555`.

There is no alternative to weigh here; this is simply what's available on the
platform.

## Android 10

Both paths are viable, and they solve different problems:

### Path A — CVE-2024-31317 script (same as Android 9)
- Surgical: removes only the target accounts, leaves disabled packages, kiosk
  app installs, and any other configuration already applied untouched.
- Preferred when you've already done setup work (Section 2 onward in the main
  README) and don't want to redo it.

### Path B — Test Harness Mode (`adb shell cmd testharness enable`)
Confirmed working on Portal's shipped `user` build (not just `userdebug`/`eng`).

- Stores the current ADB key in the persistent partition, factory-resets the
  device, restores the key, and skips Setup Wizard entirely on reboot — so you
  land on a shell with ADB already trusted and **zero accounts**, without ever
  seeing the Facebook/WhatsApp login screen again.
- Destructive: it's a full wipe. Anything done in prior steps (disabled
  packages, kiosk installs, device-owner provisioning) is gone and has to be
  reapplied from scratch afterward.
- Doesn't grant anything beyond what plain ADB already had — no `adb root`,
  no additional UID reach. Its value here is specifically "wipe + never see
  the login screen again," not privilege escalation.

### Choosing between them on Android 10
Use the script (Path A) if you want to keep existing device configuration and
just need the accounts gone. Use Test Harness Mode (Path B) if you're starting
over anyway, or specifically want a device state guaranteed to have never had
accounts provisioned on it going forward — at the cost of redoing every
downstream step.

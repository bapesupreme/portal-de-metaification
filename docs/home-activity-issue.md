# `set-home-activity` rejection (unresolved root cause)

```
adb shell cmd package set-home-activity me.jxl.kiosk_satellite/.HomeAlias
java.lang.IllegalArgumentException: Component ComponentInfo{me.jxl.kiosk_satellite/me.jxl.kiosk_satellite.HomeAlias} cannot be home on user 0
```

## What was ruled out, in order tested

1. **Component disabled?** No — `dumpsys package` showed `HomeAlias` correctly
   declared with `MAIN`/`HOME`/`DEFAULT` categories, no
   `disabledComponents`/`enabledComponents` override.
2. **App-level stopped state?** No — `stopped=false` after launching the app
   once via `am start`.
3. **Provisioning flags?** No — `device_provisioned` and `user_setup_complete`
   were both already `1`.
4. **Competing default launcher?** Ruled out — `resolve-activity` initially
   showed stock `com.facebook.alohaapps.launcher`'s `HomeActivity` as
   `isDefault=true`, so it was disabled entirely
   (`pm disable-user com.facebook.alohaapps.launcher`). Retried — same
   rejection.
5. **Device-owner status?** No — set `dpm set-device-owner` successfully
   first, retried — same rejection.

With stock launcher disabled, `resolve-activity` fell through to AOSP's
`com.android.settings.FallbackHome` (`priority=-1001`) — the placeholder shown
when nothing else resolves as HOME — rather than resolving `HomeAlias`. So
Android's resolver isn't finding `HomeAlias` a valid HOME candidate for a
reason not identified by any of the above checks.

**Root cause remains unidentified.** Possibly an Android 9-specific quirk in
how `<activity-alias>` components are validated by this particular internal
check (there are known AOSP inconsistencies in alias handling across API
levels), but this wasn't confirmed.

## Working alternative (no root cause fix needed)

`unmetaportal`'s own kiosk script (`tools/portal-kiosk-enable.sh`) documents
hitting this exact same failure mode and works around it rather than solving
it — treats `set-home-activity` as optional, falls back to:

```sh
adb shell settings put global policy_control 'immersive.full=*'
adb shell am force-stop me.jxl.kiosk_satellite
adb shell am start -S --activity-clear-task --activity-task-on-home -n me.jxl.kiosk_satellite/.MainActivity
adb shell am stack list   # find the taskId
adb shell am task lock <taskId>
```

`--activity-task-on-home` puts the activity on top of the home task stack
without requiring it to win the actual HOME role. `am task lock` (Lock Task
Mode / screen pinning) then prevents navigating away — arguably a stronger
guarantee for kiosk purposes than `set-home-activity` would have given anyway.

**Trade-off:** `am task lock` blocks all exit, including yours — release with
`adb shell am task lock stop`, which requires ADB access. If you don't want
that rigidity, test whether Kiosk Satellite's own foreground-service
auto-relaunch behavior (documented to restart it if closed/crashed) is
sufficient on its own before committing to a full task lock.

Immortal's `provisioning/provision.sh` was checked for a more sophisticated
answer — it does not have one. `set_launcher()` calls the identical
`set-home-activity` command with no fallback beyond printing a warning on
failure.

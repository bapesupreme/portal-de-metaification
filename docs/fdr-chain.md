# The self-wipe chain: why account removal can factory reset the device

Removing all `com.facebook.aloha.*` accounts (e.g. via `unmetaportal`'s
CVE-2024-31317 technique) can trigger a **local, on-device self-wipe** — this
was reproduced on real hardware, not just theorized.

## The chain (confirmed by decompiling the relevant APKs)

```
com.facebook.alohaservices.alohausers
  WhatsAppReloginFDRManager.maybePerformFDR()
    — checks account/owner state; if the server-side owners list
      comes back empty, or relogin attempts exceed a max count,
      considers this an "abnormal case" needing FDR (Factory Data Reset)
  → sends broadcast: com.facebook.aloha.permission.TRIGGER_FDR_CHECK

com.facebook.aloha.system.services
  FdrCheckBroadcastReceiver
    — receives TRIGGER_FDR_CHECK, does the actual evaluation
  → sends broadcast: com.facebook.aloha.action.PERFORM_FACTORY_USER_DATA_RESET

com.facebook.alohaservices.deviceadmin
  FactoryResetReceiver
    — receives PERFORM_FACTORY_USER_DATA_RESET, performs the actual wipe
    — requires android.permission.MASTER_CLEAR / RECOVERY
```

Relevant strings found in `alohausers`' dex:
- `"server returned owners list is empty; checking FDR possibility"`
- `"abnormal case and device shall be FDR-ed"`
- `"Performing FDR because number of relogin attempts reached maximum"`

## The fix

Disable `deviceadmin` — the *last* hop — before removing accounts:
```
adb shell pm disable-user --user 0 com.facebook.alohaservices.deviceadmin
```

Confirm the broadcast has nowhere to land:
```
adb shell cmd package query-receivers -a com.facebook.aloha.action.PERFORM_FACTORY_USER_DATA_RESET
# expect: No receivers found
```

Android drops a broadcast with zero matching receivers silently — the sender
gets no error. This was tested end-to-end: with `deviceadmin` disabled first,
running the account-removal script dropped `dumpsys account` to zero and the
device stayed online and functional, confirmed across a reboot.

## What this does NOT cover

- The real AOSP `MasterClearReceiver` (part of the settings/system framework)
  is unaffected — a physical hardware reset (volume+power) still works. This
  is expected and not something you'd want to lose as a real recovery option.
- `RemoteWipeReceiver` (also in `deviceadmin`, triggered by a server-pushed
  `com.facebook.aloha.CLOUD_NOTIFICATION` via MQTT push) is also disabled as
  a side effect of disabling the whole package, but this is a separate,
  server-initiated path — disabling the receiver stops the device from
  *acting* on such a push, not Meta from *sending* one.
- Only `alohausers` and `deviceadmin` (and the `system.services` receiver
  found while tracing this) were checked for this specific broadcast chain.
  No exhaustive search of every system package for other listeners was done —
  `query-receivers` against the actual device is the authoritative check,
  not this document.

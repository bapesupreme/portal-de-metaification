# Account regeneration after removal

After running the account-removal script, not all four accounts stay removed.

## Observed behavior (reproduced on two separate device/session states)

Immediately after removal: `dumpsys account` shows `Accounts: 0`.

Within **~20-23 seconds**, without any reboot or further action:
```
Account {name=aloha_pl_user, type=com.facebook.aloha.pl}
Account {name=aloha_hw_user, type=com.facebook.aloha.hw}
```
regenerate on their own.

`aloha_device_user` (`com.facebook.aloha.sso`) and the real owner account
(`type=com.facebook.aloha.privowner`) do **not** regenerate — confirmed stable
across multiple checks and a reboot.

## Root cause (from decompiling `alohausers`)

```
HWIdentityTokenManager$retreiveTokenInternal   -> addAccountExplicitly(...) for aloha_hw_user
PortalUniverseTokenManager$createTokenInternal -> addAccountExplicitly(...) for aloha_pl_user
```

These are lazy get-or-create token managers, not login-state accounts. Some
caller — likely a periodic background job in `system.services`, `system.device`,
or `alohaappmanager` (none of the three were conclusively confirmed as the
caller; not identified via static analysis, live logcat trace was proposed but
not completed) — requests a hardware-identity or "portal universe" token
periodically. `alohausers`, acting as the registered `AccountAuthenticator`
for these types, transparently recreates the backing account if it's missing
in order to serve the request.

## Practical implication

`dpm set-device-owner` requires **zero accounts of any kind** present at the
moment it runs — not just the human-tied account. Since `pl`/`hw` come back
within ~20 seconds, this is a race, not a stable state to reach:

```
adb shell sh remove-accounts.sh
adb shell dpm set-device-owner me.jxl.kiosk_satellite/.KioskAdminReceiver
```

Run these two commands back-to-back with nothing in between (no `dumpsys`
check eating into the window). This was confirmed to work when run this way.

## Open question

The actual caller triggering `retreiveTokenInternal`/`createTokenInternal` on
this cadence was never identified. A live `logcat` capture bracketing the
~20-second regeneration window (watching for `ActivityManager: Start proc`
lines for candidate packages right before the `action_account_add` timestamp)
would be the way to confirm it, but this wasn't completed. If you trace it,
please open a PR / issue with the finding.

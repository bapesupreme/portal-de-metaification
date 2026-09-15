# Packages Referenced in This Repo

What each package is, and why it's disabled, has its account removed, or is
deliberately left alone.

## Disabled (Step 2 — wipe path, OTA, verifier)

### `com.facebook.alohaservices.deviceadmin`
Registers the device-admin/policy receiver responsible for triggering a full
factory reset — specifically the `PERFORM_FACTORY_USER_DATA_RESET` broadcast
used as an anti-tamper response (e.g. if the device detects it's been logged
out of its associated account, or certain system packages have been altered).
**Disabled first, before anything else,** because this is the component that
could wipe the device mid-process if account removal or package changes trip
its detection logic. Confirmed gone via `cmd package query-receivers` for that
action returning no receivers.

### `com.facebook.aloha.otaui`
The OTA (over-the-air update) user-facing prompt — the "update available"
dialog. Disabled to stop update prompts/nags from interrupting the kiosk UI
once Kiosk Satellite is installed. Note: this is only the *prompt*; the
underlying download/check-in engine that actually fetches and applies updates
was never conclusively identified on this firmware (see "Known limitations"
in the README) — disabling `otaui` stops the UI, not necessarily background
update activity.

### `com.facebook.appverifier`
Android's package verifier component (Meta's build of it) — checks installed
APKs against a trust/signature policy before allowing installation or certain
operations. Disabled alongside setting `package_verifier_enable 0` because it
can block or flag the sideloaded `.debug`-style APKs and the Kiosk Satellite
install used later in the process.

## Accounts removed (Step 3)

### `com.facebook.aloha.*` accounts (the four Facebook/WhatsApp login accounts)
Not a package — these are `AccountManager` entries created during Facebook/
WhatsApp login in Setup Wizard. Removed (not disabled — accounts don't have a
disable state) because they're the actual "logged in" state the whole project
is trying to get rid of. Two of the four regenerate within ~20 seconds of
removal (see `docs/account-regeneration.md`), which is why Step 5 re-runs the
removal script immediately before `dpm set-device-owner` rather than relying
on the Step 3 run alone.

## Disabled (Step 9 — login nag)

### `com.facebook.alohaapps.personaluser`
Owns `FacebookUserLoginActivity` — the UI that prompts you to log back in.
Narrowly scoped to that login screen specifically, not shared account/system
infrastructure, so it's safe to disable outright once accounts are already
gone and you don't want the prompt resurfacing.

## Explicitly *not* touched

### `com.facebook.alohaservices.alohausers`
This is the package whose UID owns the `com.facebook.aloha.*` account entries
in `AccountManagerService` — the CVE-2024-31317 script spawns a shell running
*as this UID* specifically to gain permission to call `removeAccount()`. It's
a hard dependency, not a caution call like the two below: it's almost
certainly the registered account authenticator for the `com.facebook.aloha.*`
account type, so removing it breaks the account-removal technique itself
(`UID_LINE` lookup fails immediately) and risks orphaning the account-type
registration rather than cleaning it up. Stays installed and running
throughout the whole process. See
[`docs/alohausers-not-removed.md`](docs/alohausers-not-removed.md) for the
full reasoning.

### `com.facebook.alohaservices.system.services`
Checked and ruled out as the OTA engine. Left alone — this is shared system
infrastructure other components depend on; disabling it risks breaking
functionality well beyond OTA (unconfirmed exactly how much, which is itself
the reason to leave it alone rather than test destructively).

### `com.facebook.alohaappmanager`
Also checked and ruled out as the OTA engine, also left alone for the same
"load-bearing, don't experiment on a discontinued device" reason.

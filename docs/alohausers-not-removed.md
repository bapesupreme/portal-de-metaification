# Why `com.facebook.alohaservices.alohausers` Is Never Removed

This package gets referenced constantly throughout the process (it's what the
CVE-2024-31317 script targets), which makes it easy to mentally lump in with
the packages that *are* disabled or removed. It shouldn't be. This is a
dependency the whole flow relies on staying installed and running — not
just another Facebook package that survived out of caution.

## It's the mechanism, not a target

Every other package touched in this repo is something being turned off:
`deviceadmin` (wipe path), `otaui` (update prompt), `appverifier`,
`personaluser` (login nag). `alohaservices.alohausers` is the opposite case —
it's the thing the account-removal step *uses* to do its job.

`scripts/remove-accounts.sh` works by:
1. Looking up this package's UID via `pm list packages -U`
2. Using CVE-2024-31317 (Zygote command injection) to spawn a shell running
   as that UID
3. Calling `AccountManagerService.removeAccount()` from that shell — which
   only succeeds because the calling UID matches the UID that owns the
   `com.facebook.aloha.*` accounts

Remove the package, and step 1 fails immediately — `UID_LINE` comes back
empty and the script exits with `Could not find UID for $PACKAGE` before ever
reaching the account-removal logic. There's no version of the current
technique that still works without this package present.

## It's almost certainly the account authenticator

The `com.facebook.aloha.*` account type has to be registered with Android's
`AccountManager` framework by *something* implementing `AbstractAccountAuthenticator`
for that type — and given the naming and UID relationship, this package is
that authenticator. That's a standing registration in the framework, not a
one-time setup step. Pulling the package while its account type is still
registered doesn't clean up the account type — it orphans it, which is a
worse and less predictable state than four accounts sitting there disabled.

## It's very likely a system package

Following the `alohaservices.*` naming pattern shared with `system.services`,
this is presumably baked into `/system`, same as the two packages in
`docs/packages.md` that are explicitly left alone as unidentified/load-bearing.
`pm uninstall` on a `/system` package either fails outright without a
`-k --user 0`-style workaround, or only hides it for the current user rather
than actually removing it — and "hidden but still registered as the
authenticator" carries the same orphaning risk as above, with none of the
benefit.

## Net effect

This lands in the "don't touch" bucket for a different reason than
`system.services`/`alohaappmanager`. Those two are unknowns being avoided out
of caution. This one is a known, load-bearing dependency: the removal
technique this entire repo is built around requires it to keep existing.

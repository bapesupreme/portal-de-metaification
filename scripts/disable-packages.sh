#!/system/bin/sh
# Run via: adb shell sh disable-packages.sh
# Or paste each block individually via `adb shell <command>` from Windows/CMD.
#
# ORDER MATTERS: disable these before running remove-accounts.sh.
# See docs/fdr-chain.md for why.

echo "Disabling deviceadmin (blocks the self-wipe path)..."
pm disable-user --user 0 com.facebook.alohaservices.deviceadmin

echo "Disabling OTA prompt UI..."
pm disable-user --user 0 com.facebook.aloha.otaui

echo "Disabling package verifier..."
pm disable-user --user 0 com.facebook.appverifier
settings put global package_verifier_enable 0

echo "Confirming wipe receiver is gone (expect 'No receivers found'):"
cmd package query-receivers -a com.facebook.aloha.action.PERFORM_FACTORY_USER_DATA_RESET

# --- Optional, run only after Kiosk Satellite (or your replacement launcher)
#     is confirmed working ---

# echo "Disabling stock launcher..."
# pm disable-user --user 0 com.facebook.alohaapps.launcher

# echo "Disabling login nag..."
# pm disable-user --user 0 com.facebook.alohaapps.personaluser

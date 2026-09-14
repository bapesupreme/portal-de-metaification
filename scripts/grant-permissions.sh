#!/system/bin/sh
# Kiosk Satellite permission grants — Android 9 (API 28) subset.
# Run via: adb shell sh grant-permissions.sh
PKG=me.jxl.kiosk_satellite

pm grant $PKG android.permission.RECORD_AUDIO
pm grant $PKG android.permission.CAMERA
pm grant $PKG android.permission.ACCESS_COARSE_LOCATION
pm grant $PKG android.permission.ACCESS_FINE_LOCATION
pm grant $PKG android.permission.READ_EXTERNAL_STORAGE
pm grant $PKG android.permission.WRITE_EXTERNAL_STORAGE

appops set $PKG SYSTEM_ALERT_WINDOW allow
appops set $PKG WRITE_SETTINGS allow
appops set $PKG GET_USAGE_STATS allow
dumpsys deviceidle whitelist +$PKG

# Person Detection (Portal-specific)
pm grant $PKG android.permission.READ_LOGS

echo "Done. Restart the app for READ_LOGS to take effect:"
echo "  adb shell am force-stop $PKG"
echo "  adb shell am start -S --activity-clear-task --activity-task-on-home -n $PKG/.MainActivity"

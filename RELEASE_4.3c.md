## What's Changed

**v4.3c** is a notification-safety and battery-efficiency release on top of **v4.3b**. No settings are turned on for you - everything remains opt-in. `versionCode` stays at `43` so the real 4.4 release still shows as an update.

### Notification Safety
- **Wakelock killer no longer uses `am force-stop`** - force-stopped apps silently missed FCM pushes and alarms until reopened. It now uses `am kill`, which stops the wakelock holder but keeps apps able to receive push notifications.

### Battery
- **Fixed `netstats_poll_interval` being set to 60 s** (framework default is 30 min) - this fired ~30x more network-stats alarms, causing needless wakeups. Now kept at the framework default.
- **`netstats_global_alert_bytes` restored to the 5 MB framework default** (was 2 MB), reducing extra alert wakeups.
- **Reduced screen-off monitor polling from 3-5 s to 10 s** in both Deep Doze and Screen Off Optimization, cutting `dumpsys` wakeups during idle.

### New: OEM Freezer (opt-in, OnePlus/OPPO)
- **Disables selected OnePlus/OPPO bloat services** (`com.oplus.*`, `com.coloros.*`, `com.oneplus.*`, `com.oppo.*`) via `pm disable`, with full job-cancellation and clean revert.
- **Device-gated**: automatically ignored on any non-OnePlus/OPPO device.
- Editable package list: `module/config/oem_services.txt` (categories `common` / `oneplus` / `oppo`, risky components commented out).
- Enable with `ENABLE_OEM_FREEZER=1` in `config/user_prefs`, or toggle it in the WebUI.

### WebUI
- **New "OEM Freezer" toggle** on the GMS page, integrated into **Freeze All / Stock All / Re-apply** and the home status card.
- **Translations added for all 14 languages** (new strings in `ar/de/en/es/fr/id/it/ja/pl/pt-BR/ru/tr/uk/zh-CN`).

### Other
- **Full uninstall revert** for frozen OEM packages (tracking file + runner).
- **Whitelists stay plain**: `doze_whitelist.txt` and `ram_clean_whitelist.txt` remain empty by default - every package is opted in by the user.
- Module version string updated to `4.3c` (`versionCode` intentionally stays `43`).
- Docs updated: `README.md` + all 13 localized READMEs, `CHANGELOG.md`.

## Testing focus
- Confirm WhatsApp/Telegram/etc. push notifications arrive instantly with Deep Doze enabled (add your messaging apps to the Deep Doze whitelist in the WebUI).
- On OnePlus/OPPO: enable OEM Freezer and verify no relied-on service is missing; everything in the list is safe to disable and easily trimmed in `oem_services.txt`.
- With Kill Logs enabled, check battery stats stay sane (netstats now polls at the 30-min default).

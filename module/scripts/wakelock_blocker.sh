#!/system/bin/sh
# Frosty - Kernel WakeLock Blocker

_d="${0%/*}"
[ -z "$_d" ] && _d="/data/adb/modules/Frosty/scripts"
MODDIR="${_d%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"
unset _d
MODVER=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)

LOGDIR="$MODDIR/logs"
WAKELOCK_LOG="$LOGDIR/wakelock_blocker.log"
USER_PREFS="$MODDIR/config/user_prefs"
WAKELOCK_BLOCKLIST="$MODDIR/config/wakelock_blocklist.txt"

ENABLE_WAKELOCK_BLOCKER=0
[ -f "$USER_PREFS" ] && . "$USER_PREFS"

mkdir -p "$LOGDIR"
log_kwl() { echo "[$(date '+%H:%M:%S')] $1" >> "$WAKELOCK_LOG"; }

block() {
  echo "Frosty v${MODVER:-?} - Kernel WakeLock Blocker (BLOCK) - $(date '+%Y-%m-%d %H:%M:%S')" > "$WAKELOCK_LOG"
  [ "$ENABLE_WAKELOCK_BLOCKER" != "1" ] && { log_kwl "[SKIP] Kernel WakeLock Blocker disabled"; return 0; }
  [ ! -f "$WAKELOCK_BLOCKLIST" ] && { log_kwl "[SKIP] No blocklist found at $WAKELOCK_BLOCKLIST"; return 0; }

  local blocked=0

  # WLAN power saving
  for _wlan in /sys/module/wlan/parameters /sys/module/cfg80211/parameters; do
    [ -f "$_wlan/power_save" ] && echo 1 > "$_wlan/power_save" 2>/dev/null && blocked=$((blocked + 1))
    [ -f "$_wlan/disable_11b" ] && echo 1 > "$_wlan/disable_11b" 2>/dev/null && blocked=$((blocked + 1))
  done

  # Disable bluetooth polling
  [ -f /sys/module/bluetooth/parameters/disable_ertm ] && echo Y > /sys/module/bluetooth/parameters/disable_ertm 2>/dev/null
  [ -f /sys/module/bluetooth/parameters/disable_hci_logging ] && echo 1 > /sys/module/bluetooth/parameters/disable_hci_logging 2>/dev/null

  while IFS= read -r kwl_name; do
    case "$kwl_name" in ''|'#'*) continue ;; esac
    kwl_name=$(echo "$kwl_name" | tr -d ' ')
    [ -z "$kwl_name" ] && continue

    local blocked_this=0

    # Method 1: /sys/power/wake_lock (for known wakelocks)
    if [ -f /sys/power/wake_lock ]; then
      echo "$kwl_name" > /sys/power/wake_unlock 2>/dev/null && blocked_this=1
    fi

    # Method 2: /sys/class/misc/wakeup_source/ (per-wakelock control)
    if [ -d "/sys/class/misc/wakeup_source/$kwl_name" ]; then
      echo 0 > "/sys/class/misc/wakeup_source/$kwl_name/enable" 2>/dev/null && blocked_this=1
    fi

    # Method 3: Disable via parent device power/wakeup
    local _devpath
    _devpath=$(find /sys/devices -name "$kwl_name" -type d 2>/dev/null | head -1)
    if [ -n "$_devpath" ] && [ -f "$_devpath/power/wakeup" ]; then
      echo "disabled" > "$_devpath/power/wakeup" 2>/dev/null && blocked_this=1
    fi

    [ "$blocked_this" = "1" ] && blocked=$((blocked + 1))
  done < "$WAKELOCK_BLOCKLIST"

  log_kwl "[OK] Blocked $blocked Kernel WakeLocks"
  echo "{\"status\":\"ok\",\"blocked\":$blocked}"
}

unblock() {
  echo "Frosty v${MODVER:-?} - Kernel WakeLock Blocker (UNBLOCK) - $(date '+%Y-%m-%d %H:%M:%S')" > "$WAKELOCK_LOG"
  [ ! -f "$WAKELOCK_BLOCKLIST" ] && { log_kwl "[SKIP] No blocklist found"; return 0; }

  local restored=0
  while IFS= read -r kwl_name; do
    case "$kwl_name" in ''|'#'*) continue ;; esac
    kwl_name=$(echo "$kwl_name" | tr -d ' ')
    [ -z "$kwl_name" ] && continue

    # Re-enable via device path
    local _devpath
    _devpath=$(find /sys/devices -name "$kwl_name" -type d 2>/dev/null | head -1)
    if [ -n "$_devpath" ] && [ -f "$_devpath/power/wakeup" ]; then
      echo "enabled" > "$_devpath/power/wakeup" 2>/dev/null && restored=$((restored + 1))
    fi

    # Re-enable via wakeup_source class
    if [ -d "/sys/class/misc/wakeup_source/$kwl_name" ]; then
      echo 1 > "/sys/class/misc/wakeup_source/$kwl_name/enable" 2>/dev/null
    fi
  done < "$WAKELOCK_BLOCKLIST"

  log_kwl "[OK] Restored $restored Kernel WakeLocks"
  echo "{\"status\":\"ok\",\"restored\":$restored}"
}

case "$1" in
  block)   block ;;
  unblock) unblock ;;
  *) echo "Usage: $0 {block|unblock}"; exit 1 ;;
esac
exit 0

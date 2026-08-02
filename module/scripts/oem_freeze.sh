#!/system/bin/sh
# Frosty - OnePlus/Oppo OEM Freezer (opt-in, device-gated)

_d="${0%/*}"
[ -z "$_d" ] && _d="/data/adb/modules/Frosty/scripts"
MODDIR="${_d%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"
unset _d
MODVER=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)

LOGDIR="$MODDIR/logs"
OEM_LOG="$LOGDIR/oem_freeze.log"
OEM_LIST="$MODDIR/config/oem_services.txt"
USER_PREFS="$MODDIR/config/user_prefs"
FROZEN_FILE="$MODDIR/tmp/oem_frozen.txt"

ENABLE_OEM_FREEZER=0
[ -f "$USER_PREFS" ] && . "$USER_PREFS"

mkdir -p "$LOGDIR" "$MODDIR/tmp"
log_oem() { echo "[$(date '+%H:%M:%S')] $1" >> "$OEM_LOG"; }

_get_user_ids() {
  pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | grep -oE '[0-9]+' || ls /data/user 2>/dev/null
}

detect_oem() {
  local _brand
  _brand=$(getprop ro.product.vendor.brand 2>/dev/null)
  [ -z "$_brand" ] && _brand=$(getprop ro.product.brand 2>/dev/null)
  [ -z "$_brand" ] && _brand=$(getprop ro.product.manufacturer 2>/dev/null)
  case "$_brand" in
    *OnePlus*)        echo "oneplus" ;;
    *OPPO*|*Oppo*|*oppo*) echo "oppo" ;;
    *) echo "other" ;;
  esac
}

_cancel_jobs() {
  local _pkg="$1" _uid
  for _uid in $(_get_user_ids); do
    cmd jobscheduler cancel --user "$_uid" "$_pkg" >/dev/null 2>&1
  done
}

freeze_oem() {
  echo "Frosty v${MODVER:-?} - OEM (FREEZE) - $(date '+%Y-%m-%d %H:%M:%S')" > "$OEM_LOG"
  [ "$ENABLE_OEM_FREEZER" != "1" ] && { log_oem "[SKIP] OEM freezer disabled in user_prefs"; return 0; }

  local oem
  oem=$(detect_oem)
  if [ "$oem" = "other" ]; then
    log_oem "[SKIP] Device is not OnePlus/Oppo - ignoring"
    return 0
  fi
  log_oem "Device detected: $oem"

  [ ! -f "$OEM_LIST" ] && { log_oem "[SKIP] oem_services.txt not found"; return 0; }

  local count=0 fail=0 skip=0 _user_ids
  _user_ids=$(_get_user_ids)
  : > "$FROZEN_FILE"

  while IFS='|' read -r svc cat || [ -n "$svc" ]; do
    case "$svc" in ''|'#'*) continue ;; esac
    svc=$(echo "$svc" | tr -d ' ')
    cat=$(echo "$cat" | tr -d ' ')
    [ -z "$cat" ] && continue
    case "$cat" in
      common)  ;;
      oneplus) [ "$oem" = "oneplus" ] || continue ;;
      oppo)    [ "$oem" = "oppo" ] || continue ;;
      *) continue ;;
    esac

    local _svc_pkg
    _svc_pkg=$(printf '%s' "$svc" | cut -d/ -f1)
    pm list packages 2>/dev/null | grep -Fx "package:$_svc_pkg" >/dev/null 2>&1 || {
      log_oem "[SKIP] $_svc_pkg not installed"
      skip=$((skip + 1))
      continue
    }

    local _disabled_any=false _uid
    for _uid in $_user_ids; do
      pm disable --user "$_uid" "$svc" >/dev/null 2>&1 && _disabled_any=true
    done

    if $_disabled_any; then
      printf '%s\n' "$svc" >> "$FROZEN_FILE"
      log_oem "[OK] $svc"
      count=$((count + 1))
      _cancel_jobs "$_svc_pkg"
    else
      log_oem "[FAIL] $svc"
      fail=$((fail + 1))
    fi
  done < "$OEM_LIST"

  log_oem ""
  log_oem "Summary: $count disabled, $fail failed, $skip skipped"
  echo "{\"status\":\"ok\",\"disabled\":$count,\"failed\":$fail,\"skipped\":$skip}"
}

stock_oem() {
  echo "Frosty v${MODVER:-?} - OEM (STOCK) - $(date '+%Y-%m-%d %H:%M:%S')" > "$OEM_LOG"
  local count=0 fail=0 _user_ids
  _user_ids=$(_get_user_ids)

  if [ -f "$FROZEN_FILE" ]; then
    log_oem "Restoring from tracking file..."
    while IFS= read -r svc || [ -n "$svc" ]; do
      case "$svc" in ''|'#'*) continue ;; esac
      local _ok=false _uid
      for _uid in $_user_ids; do
        pm enable --user "$_uid" "$svc" >/dev/null 2>&1 && _ok=true
      done
      if $_ok; then count=$((count + 1)); else fail=$((fail + 1)); fi
    done < "$FROZEN_FILE"
    rm -f "$FROZEN_FILE"
  else
    log_oem "No tracking file - using full service list..."
    while IFS='|' read -r svc cat || [ -n "$svc" ]; do
      case "$svc" in ''|'#'*) continue ;; esac
      svc=$(echo "$svc" | tr -d ' ')
      local _ok=false _uid
      for _uid in $_user_ids; do
        pm enable --user "$_uid" "$svc" >/dev/null 2>&1 && _ok=true
      done
      if $_ok; then count=$((count + 1)); else fail=$((fail + 1)); fi
    done < "$OEM_LIST"
  fi

  log_oem ""
  log_oem "Summary: $count enabled, $fail failed"
  echo "{\"status\":\"ok\",\"enabled\":$count,\"failed\":$fail}"
}

case "$1" in
  freeze) freeze_oem ;;
  stock)  stock_oem ;;
  *) echo "Usage: $0 {freeze|stock}"; exit 1 ;;
esac
exit 0

#!/system/bin/sh
# Frosty - GMS Doze

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"
MODVER=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)

LOGDIR="$MODDIR/logs"
DOZE_LOG="$LOGDIR/gms_doze.log"
USER_PREFS="$MODDIR/config/user_prefs"
OVERLAYS_FILE="$MODDIR/config/gms_overlays.txt"

ENABLE_GMS_DOZE=0
[ -f "$USER_PREFS" ] && . "$USER_PREFS"

GMS_PKG="com.google.android.gms"
GMS_ADMIN1="$GMS_PKG/$GMS_PKG.auth.managed.admin.DeviceAdminReceiver"
GMS_ADMIN2="$GMS_PKG/$GMS_PKG.mdm.receivers.MdmDeviceAdminReceiver"

_GMS_GREP="allow-in-power-save.*com\.google\.android\.gms|allow-in-data-usage-save.*com\.google\.android\.gms|<wl[^>]*>[[:space:]]*com\.google\.android\.gms[[:space:]]*</wl>"
_GMS_SED='/allow-in-power-save.*com\.google\.android\.gms/d;/allow-in-data-usage-save.*com\.google\.android\.gms/d;/<wl[^>]*>com\.google\.android\.gms<\/wl>/d'

mkdir -p "$LOGDIR"
log_doze() { echo "[$(date '+%H:%M:%S')] $1" >> "$DOZE_LOG"; }

get_user_ids() {
  pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | grep -oE '[0-9]+' || ls /data/user 2>/dev/null
}

_log_status() {
  local label="$1"
  log_doze "Status after $label"

  local wl_full=$(dumpsys deviceidle whitelist 2>/dev/null)
  local in_system=$(echo "$wl_full" | grep "system,$GMS_PKG")
  local in_excidle=$(echo "$wl_full" | grep "system-excidle,$GMS_PKG")
  local in_user=$(echo "$wl_full" | grep "user,$GMS_PKG")
  local in_any=$(echo "$wl_full" | grep "$GMS_PKG")

  if [ -z "$in_any" ]; then
    log_doze "[OK] GMS fully optimized - not in any whitelist tier"
  else
    [ -n "$in_system" ]  && log_doze "[INFO] system tier: persists until overlay + reboot"
    [ -n "$in_excidle" ] && log_doze "[INFO] system-excidle tier: deep doze active, light doze exempt"
    [ -n "$in_user" ]    && log_doze "[WARN] user tier: still present"
  fi

  local overlay_count=0
  [ -f "$OVERLAYS_FILE" ] && overlay_count=$(grep -c '.' "$OVERLAYS_FILE" 2>/dev/null)
  log_doze "[INFO] XML overlays: $overlay_count"

  local has_unwl="NO"
  [ -f /data/system/deviceidle.xml ] && \
    grep -q "<un-wl n=\"$GMS_PKG\"" /data/system/deviceidle.xml 2>/dev/null && has_unwl="YES"
  log_doze "[INFO] deviceidle.xml <un-wl>: $has_unwl"

  local has_wl="NO"
  [ -f /data/system/deviceidle.xml ] && \
    grep -q "<wl n=\"$GMS_PKG\"" /data/system/deviceidle.xml 2>/dev/null && has_wl="YES"
  log_doze "[INFO] deviceidle.xml <wl>: $has_wl"

  if [ "$has_unwl" = "YES" ] && [ "$has_wl" = "NO" ]; then
    if [ -z "$in_any" ]; then
      log_doze "[GOOD] GMS fully dozed - removed from all whitelist tiers"
    elif [ -n "$in_excidle" ] && [ -z "$in_system" ] && [ -z "$in_user" ]; then
      log_doze "[GOOD] GMS effectively dozed - deep doze active, system-excidle is cosmetic"
    else
      log_doze "[OK] GMS partially dozed via deviceidle.xml"
    fi
  elif [ "$has_wl" = "YES" ]; then
    log_doze "[URGENT] GMS <wl> conflicts with <un-wl> doze unstable!"
  fi
}

patch_xml() {
  [ -f "$OVERLAYS_FILE" ] && {
    local existing=$(grep -c '.' "$OVERLAYS_FILE" 2>/dev/null)
    log_doze "[OK] $existing overlay(s) already generated"
    return 0
  }

  log_doze "Scanning for GMS whitelist XMLs..."
  local count=0 scanned=0 _seen=""

  for base in /system /product /vendor /system_ext /odm /india \
              /my_product /my_heytap /my_region /my_bigball /my_carrier \
              /my_company /my_engineering /my_manifest /my_preload \
              /my_reserve /my_stock \
              /system/product /system/vendor /system/system_ext /system/odm; do
    [ -d "$base" ] || continue
    for _dir in "$base/etc" "$base/oplus" "$base/oppo"; do
      [ -d "$_dir" ] || continue
      for xml in $(find "$_dir" -maxdepth 2 -type f -name "*.xml" 2>/dev/null); do
        local real=$(readlink -f "$xml" 2>/dev/null)
        [ -z "$real" ] && real="$xml"
        case "$_seen" in *"|$real|"*) continue ;; esac
        _seen="${_seen}|$real|"
        scanned=$((scanned + 1))

        grep -qE "$_GMS_GREP" "$real" 2>/dev/null || continue

        # Remap symlink-resolved /system/xxx/ paths to canonical partition roots.
        local relative="${real#/}"
        case "$relative" in
          system/product/*)    relative="product/${relative#system/product/}" ;;
          system/system_ext/*) relative="system_ext/${relative#system/system_ext/}" ;;
          system/vendor/*)     relative="vendor/${relative#system/vendor/}" ;;
          system/odm/*)        relative="odm/${relative#system/odm/}" ;;
        esac
        case "$relative" in
          system/*) ;;
          product/*|vendor/*|odm/*|system_ext/*) ;;
          *) relative="system/$relative" ;;
        esac
        local dest="$MODDIR/$relative"

        mkdir -p "$(dirname "$dest")"
        if cp -af "$real" "$dest" 2>/dev/null; then
          sed -i "$_GMS_SED" "$dest"
          echo "$dest" >> "$OVERLAYS_FILE"
          log_doze "[OK] Overlaid: $real → $relative"
          count=$((count + 1))
        else
          log_doze "[FAIL] Cannot copy: $real"
        fi
      done
    done
  done

  if [ "$count" -eq 0 ]; then
    log_doze "[INFO] No GMS whitelist XMLs found in $scanned files - device may use runtime whitelist only"
    log_doze "[INFO] GMS Doze relies on deviceidle.xml <un-wl> injection + runtime whitelist removal"
  else
    log_doze "[OK] $count XML(s) overlaid from $scanned scanned - reboot to mount"
  fi
}

remove_xml() {
  if [ -f "$OVERLAYS_FILE" ]; then
    local count=0
    while IFS= read -r file; do
      case "$file" in '#'*|'') continue ;; esac
      [ -f "$file" ] && rm -f "$file" && count=$((count + 1))
    done < "$OVERLAYS_FILE"
    rm -f "$OVERLAYS_FILE"
    log_doze "[OK] Removed $count overlay files"
  fi
  for _root in system product vendor odm system_ext \
               my_product my_heytap my_region my_bigball my_carrier \
               my_company my_engineering my_manifest my_preload \
               my_reserve my_stock india; do
    [ -d "$MODDIR/$_root" ] && find "$MODDIR/$_root" -type d -empty -delete 2>/dev/null
  done
}

apply() {
  echo "Frosty v${MODVER:-?} - GMS Doze (APPLY) - $(date '+%Y-%m-%d %H:%M:%S')" > "$DOZE_LOG"
  [ "$ENABLE_GMS_DOZE" != "1" ] && { log_doze "[SKIP] GMS Doze disabled"; return 0; }
  log_doze "Applying GMS Doze..."

  patch_xml

  local admin_count=0
  for user_id in $(get_user_ids); do
    for admin in "$GMS_ADMIN1" "$GMS_ADMIN2"; do
      if pm disable --user "$user_id" "$admin" >/dev/null 2>&1; then
        log_doze "[OK] Disabled: $admin (user $user_id)"
        admin_count=$((admin_count + 1))
      fi
    done
  done
  log_doze "Disabled $admin_count device admin receiver(s)"

  dumpsys deviceidle whitelist -"$GMS_PKG" >/dev/null 2>&1
  log_doze "[OK] Removed from user whitelist"

  local sys_out=$(cmd deviceidle sys-whitelist -"$GMS_PKG" 2>&1)
  case "$sys_out" in
    *[Uu]nknown*|*[Ee]rror*) log_doze "[INFO] sys-whitelist command not available" ;;
    *) log_doze "[OK] sys-whitelist: ${sys_out:-executed}" ;;
  esac

  cmd deviceidle except-idle-whitelist -"$GMS_PKG" >/dev/null 2>&1

  if [ -f /data/system/deviceidle.xml ] && \
     grep -q "<wl n=\"$GMS_PKG\"" /data/system/deviceidle.xml 2>/dev/null; then
    sed -i "/<wl n=\"$GMS_PKG\"/d" /data/system/deviceidle.xml
    restorecon /data/system/deviceidle.xml 2>/dev/null
    log_doze "[OK] Removed persistent <wl> from deviceidle.xml"
  fi

  # GMS loses allow-in-power-save via sysconfig, so the OS is now allowed to
  # kill its processes during idle. Warm it back up here so Camera, PayPal, and
  # other GMS-dependent apps don't crash on first open after doze is applied.
  am start-service -n "$GMS_PKG/.checkin.CheckinService" >/dev/null 2>&1 || true
  log_doze "[OK] GMS warmed up"

  _log_status "apply"
}

revert() {
  echo "Frosty v${MODVER:-?} - GMS Doze (REVERT) - $(date '+%Y-%m-%d %H:%M:%S')" > "$DOZE_LOG"
  log_doze "Reverting GMS Doze..."

  remove_xml

  dumpsys deviceidle whitelist +"$GMS_PKG" >/dev/null 2>&1
  log_doze "[OK] Restored to user whitelist"

  local sys_out=$(cmd deviceidle sys-whitelist +"$GMS_PKG" 2>&1)
  case "$sys_out" in
    *[Uu]nknown*|*[Ee]rror*) log_doze "[INFO] sys-whitelist not available" ;;
    *) log_doze "[OK] sys-whitelist restore: ${sys_out:-executed}" ;;
  esac

  local admin_count=0
  for user_id in $(get_user_ids); do
    for admin in "$GMS_ADMIN1" "$GMS_ADMIN2"; do
      if pm enable --user "$user_id" "$admin" >/dev/null 2>&1; then
        log_doze "[OK] Enabled: $admin (user $user_id)"
        admin_count=$((admin_count + 1))
      fi
    done
  done
  log_doze "Re-enabled $admin_count device admin receiver(s)"

  _log_status "revert"
}

case "$1" in
  apply|freeze) apply ;;
  revert|stock) revert ;;
esac
exit 0
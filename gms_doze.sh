#!/system/bin/sh
# FROSTY - GMS Doze Handler

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"

LOGDIR="$MODDIR/logs"
DOZE_LOG="$LOGDIR/gms_doze.log"
USER_PREFS="$MODDIR/config/user_prefs"

mkdir -p "$LOGDIR"

MODVER=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)
log_doze() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DOZE_LOG"; }

ENABLE_GMS_DOZE=0
[ -f "$USER_PREFS" ] && . "$USER_PREFS"

GMS_PKG="com.google.android.gms"
GMS_ADMIN1="$GMS_PKG/$GMS_PKG.auth.managed.admin.DeviceAdminReceiver"
GMS_ADMIN2="$GMS_PKG/$GMS_PKG.mdm.receivers.MdmDeviceAdminReceiver"

get_user_ids() {
  pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | grep -oE '[0-9]+' || ls /data/user 2>/dev/null
}

# Partitions that may carry sysconfig XMLs with GMS whitelist entries
_PARTITIONS="india my_bigball my_carrier my_company my_engineering my_heytap \
             my_manifest my_preload my_product my_region my_reserve my_stock \
             odm product system system_ext vendor"

_GMS_PATTERNS=(
  "allow-in-power-save.*com\.google\.android\.gms"
  "allow-in-data-usage-save.*com\.google\.android\.gms"
  "<wl[^>]*>[[:space:]]*com\.google\.android\.gms[[:space:]]*</wl>"
)

# Returns 0 if /$1 is a separate mount point (not under /system)
_is_separate_partition() {
  local p="$1"
  mountpoint -q "/$p" 2>/dev/null && return 0
  [ -L "/system/$p" ] && return 0
  grep -qE "^[^ ]+ /$p " /proc/mounts 2>/dev/null && return 0
  return 1
}

# Log full status to doze log
_log_status() {
  local label="$1"
  log_doze "Status after $label"

  local wl_full
  wl_full=$(dumpsys deviceidle whitelist 2>/dev/null)
  local in_system=$(echo "$wl_full" | grep "system,$GMS_PKG")
  local in_excidle=$(echo "$wl_full" | grep "system-excidle,$GMS_PKG")
  local in_user=$(echo "$wl_full" | grep "user,$GMS_PKG")
  local in_any=$(echo "$wl_full" | grep "$GMS_PKG")

  if [ -z "$in_any" ]; then
    log_doze "[OK] GMS fully optimized — not in any whitelist tier"
  else
    [ -n "$in_system" ]  && log_doze "[INFO] system tier: persists until overlay mounts + reboot"
    [ -n "$in_excidle" ] && log_doze "[INFO] system-excidle tier: residual — deep doze IS active, only light doze exempt"
    [ -n "$in_user" ]    && log_doze "[WARN] user tier: still present"
  fi

  local xml_count
  xml_count=$(find "$MODDIR" -path "*/sysconfig/*.xml" -type f 2>/dev/null | wc -l)
  log_doze "[INFO] XML overlays: $xml_count"

  if [ "$xml_count" -gt 0 ]; then
    local overlay_active="YES"
    for _cp in /product/etc/sysconfig/*.xml /system/product/etc/sysconfig/*.xml \
               /system_ext/etc/sysconfig/*.xml /vendor/etc/sysconfig/*.xml; do
      [ -f "$_cp" ] && grep -q "allow-in-power-save.*com\.google\.android\.gms" "$_cp" 2>/dev/null && {
        overlay_active="NO"
        break
      }
    done
    log_doze "[INFO] Overlay mounted: $overlay_active"
    if [ "$overlay_active" = "NO" ]; then
      log_doze "[INFO] Sysconfig overlay not mounted by root manager (limitation, not a bug)"
      log_doze "[INFO] GMS IS still dozed via deviceidle.xml — system-excidle is cosmetic"
    fi
  fi

  local has_unwl="NO"
  [ -f /data/system/deviceidle.xml ] && \
    grep -q "<un-wl n=\"$GMS_PKG\"" /data/system/deviceidle.xml 2>/dev/null && has_unwl="YES"
  log_doze "[INFO] deviceidle.xml <un-wl>: $has_unwl"

  local has_wl="NO"
  [ -f /data/system/deviceidle.xml ] && \
    grep -q "<wl n=\"$GMS_PKG\"" /data/system/deviceidle.xml 2>/dev/null && has_wl="YES"
  log_doze "[INFO] deviceidle.xml <wl>: $has_wl"

  # Final verdict
  if [ "$has_unwl" = "YES" ] && [ "$has_wl" = "NO" ]; then
    if [ -z "$in_any" ]; then
      log_doze "[GOOD] GMS fully dozed — removed from all whitelist tiers"
    elif [ -n "$in_excidle" ] && [ -z "$in_system" ] && [ -z "$in_user" ]; then
      log_doze "[GOOD] GMS effectively dozed — deep doze active, system-excidle is cosmetic"
    else
      log_doze "[OK] GMS partially dozed via deviceidle.xml"
    fi
  elif [ "$has_wl" = "YES" ]; then
    log_doze "[URGENT] GMS <wl> conflicts with <un-wl> — doze unstable!"
  fi
}

# Create patched XML overlays
patch_xml() {
  local existing
  existing=$(find "$MODDIR" -path "*/sysconfig/*.xml" -type f 2>/dev/null | wc -l)
  if [ "$existing" -gt 0 ]; then
    log_doze "[OK] $existing sysconfig overlay(s) already present"
    return 0
  fi

  _GREP_PATTERN=$(IFS='|'; echo "${_GMS_PATTERNS[*]}")
  _SED_PATTERN=$(printf '/%s/d;' "${_GMS_PATTERNS[@]//\//\\/}")

  local patched=0 _seen=""

  # Search for sysconfig and other whitelist files
  for _base in $_PARTITIONS; do
    _base="/$_base"
    for _dir in "$_base/etc" "$_base/oplus" "$_base/oppo"; do
      [ -d "$_dir" ] || continue
      for xml in $(find "$_dir" -type f -name "*.xml" -depth -maxdepth 2 2>/dev/null); do
        local _real
        _real=$(readlink -f "$xml" 2>/dev/null)
        [ -z "$_real" ] && _real="$xml"
        case "$_seen" in *"|$_real|"*) continue ;; esac
        _seen="${_seen}|${_real}|"

        grep -qE "$_GREP_PATTERN" "$xml" 2>/dev/null || continue

        local dest="$MODDIR${_real}"
        mkdir -p "$(dirname "$dest")"
        if cp -af "$_real" "$dest" 2>/dev/null; then
          sed -i "$_SED_PATTERN" "$dest"
          log_doze "[OK] Patched: $_real"
          patched=$((patched + 1))
        else
          log_doze "[FAIL] Cannot copy: $_real"
        fi
      done
    done
  done

  # Also check /system/$sub for legacy layouts where sub-partition is a real dir under /system
  for _sub in product vendor system_ext odm; do
    [ -d "/system/$_sub/etc/sysconfig" ] || continue
    [ -L "/system/$_sub" ] && continue  # already handled via /$_sub above
    for xml in $(find "/system/$_sub/etc/sysconfig" -type f -name "*.xml" 2>/dev/null); do
      local _real
      _real=$(readlink -f "$xml" 2>/dev/null)
      [ -z "$_real" ] && _real="$xml"
      case "$_seen" in *"|$_real|"*) continue ;; esac
      _seen="${_seen}|${_real}|"

      grep -qE 'allow-in-power-save.*com\.google\.android\.gms|allow-in-data-usage-save.*com\.google\.android\.gms' \
        "$xml" 2>/dev/null || continue

      local dest="$MODDIR${_real}"
      mkdir -p "$(dirname "$dest")"
      if cp -af "$_real" "$dest" 2>/dev/null; then
        sed -i '/allow-in-power-save.*com\.google\.android\.gms/d;/allow-in-data-usage-save.*com\.google\.android\.gms/d' "$dest"
        log_doze "[OK] Patched: $_real"
        patched=$((patched + 1))
      else
        log_doze "[FAIL] Cannot copy: $_real"
      fi
    done
  done

  # Place overlay files at the correct path for the root manager
  _fixup_partition_layout

  if [ "$patched" -eq 0 ]; then
    log_doze "[INFO] No sysconfig XMLs with GMS entries found"
  else
    log_doze "[OK] $patched XML(s) patched — reboot for overlay to take effect"
  fi
}

# Ensure overlay files are at the correct location for the root manager
_fixup_partition_layout() {
  for p in $_PARTITIONS; do
    if _is_separate_partition "$p"; then
      # Separate: move from $MODDIR/system/$p/ → $MODDIR/$p/
      if [ -d "$MODDIR/system/$p" ] && [ ! -L "$MODDIR/system/$p" ]; then
        mkdir -p "$MODDIR/$p"
        if cp -af "$MODDIR/system/$p/." "$MODDIR/$p/" 2>/dev/null; then
          rm -rf "$MODDIR/system/$p"
          log_doze "[OK] /$p is separate — moved overlay to \$MODDIR/$p/"
        else
          log_doze "[WARN] cp failed for /$p — keeping at \$MODDIR/system/$p/"
        fi
      fi
      # Compatibility symlink (KSU convention)
      if [ -d "$MODDIR/$p" ] && [ ! -e "$MODDIR/system/$p" ]; then
        mkdir -p "$MODDIR/system" 2>/dev/null
        ln -sf "../$p" "$MODDIR/system/$p" 2>/dev/null
      fi
    else
      # Integrated: move from $MODDIR/$p/ → $MODDIR/system/$p/
      if [ -d "$MODDIR/$p" ] && [ ! -L "$MODDIR/$p" ]; then
        mkdir -p "$MODDIR/system/$p"
        if cp -af "$MODDIR/$p/." "$MODDIR/system/$p/" 2>/dev/null; then
          rm -rf "$MODDIR/$p"
          log_doze "[OK] /$p under /system — moved overlay to \$MODDIR/system/$p/"
        else
          log_doze "[WARN] cp failed for /$p — keeping at \$MODDIR/$p/"
        fi
      fi
    fi
  done
}

# Remove patched XML overlays
remove_xml() {
  find "$MODDIR" -path "*/sysconfig/*.xml" -type f 2>/dev/null -delete
  for p in $_PARTITIONS; do
    [ -L "$MODDIR/system/$p" ] && rm -f "$MODDIR/system/$p" 2>/dev/null
    [ -d "$MODDIR/$p" ] && find "$MODDIR/$p" -type d -empty -delete 2>/dev/null
    [ -d "$MODDIR/system/$p" ] && [ ! -L "$MODDIR/system/$p" ] && \
      find "$MODDIR/system/$p" -type d -empty -delete 2>/dev/null
  done
  log_doze "[OK] XML overlays removed"
}

apply() {
  echo "Frosty v${MODVER:-?} - GMS Doze - APPLY $(date '+%Y-%m-%d %H:%M:%S')" > "$DOZE_LOG"

  if [ "$ENABLE_GMS_DOZE" != "1" ]; then
    log_doze "[SKIP] GMS Doze disabled by user"
    return 0
  fi

  log_doze "Applying GMS Doze..."

  # 1. Create XML overlays for root manager to mount
  patch_xml

  # 2. Disable device admin receivers
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

  # 3. Runtime whitelist removal
  dumpsys deviceidle whitelist -"$GMS_PKG" >/dev/null 2>&1
  log_doze "[OK] Removed from user whitelist"

  local sys_out
  sys_out=$(cmd deviceidle sys-whitelist -"$GMS_PKG" 2>&1)
  case "$sys_out" in
    *[Uu]nknown*|*[Ee]rror*) log_doze "[INFO] sys-whitelist not available" ;;
    *) log_doze "[OK] sys-whitelist: ${sys_out:-executed}" ;;
  esac

  # Best-effort: try except-idle removal (only affects user tier of except-idle,
  cmd deviceidle except-idle-whitelist -"$GMS_PKG" >/dev/null 2>&1

  # 4. Remove persistent <wl> from deviceidle.xml
  if [ -f /data/system/deviceidle.xml ] && \
     grep -q "<wl n=\"$GMS_PKG\"" /data/system/deviceidle.xml 2>/dev/null; then
    sed -i "/<wl n=\"$GMS_PKG\"/d" /data/system/deviceidle.xml
    restorecon /data/system/deviceidle.xml 2>/dev/null
    log_doze "[OK] Removed persistent <wl> from deviceidle.xml"
  fi

  # 5. Full status
  _log_status "apply"
}

revert() {
  echo "Frosty v${MODVER:-?} - GMS Doze - REVERT $(date '+%Y-%m-%d %H:%M:%S')" > "$DOZE_LOG"

  log_doze "Reverting GMS Doze..."

  # 1. Remove XML overlays
  remove_xml

  # 2. Restore whitelists
  dumpsys deviceidle whitelist +"$GMS_PKG" >/dev/null 2>&1
  log_doze "[OK] Restored to user whitelist"

  local sys_out
  sys_out=$(cmd deviceidle sys-whitelist +"$GMS_PKG" 2>&1)
  case "$sys_out" in
    *[Uu]nknown*|*[Ee]rror*) log_doze "[INFO] sys-whitelist not available" ;;
    *) log_doze "[OK] sys-whitelist restore: ${sys_out:-executed}" ;;
  esac

  # 3. Re-enable device admin receivers
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

  # deviceidle.xml cleanup handled by post-fs-data.sh on next boot
  log_doze "Reboot recommended for full restoration"

  # 4. Full status
  _log_status "revert"
}

case "$1" in
  apply|freeze) apply ;;
  revert|stock) revert ;;
  *) echo "Usage: gms_doze.sh [apply|revert]" ;;
esac

exit 0

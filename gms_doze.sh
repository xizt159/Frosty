#!/system/bin/sh
# Frosty - GMS Doze

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"
MODVER=$(grep "^version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)

LOGDIR="$MODDIR/logs"
DOZE_LOG="$LOGDIR/gms_doze.log"
USER_PREFS="$MODDIR/config/user_prefs"
OVERLAYS_FILE="$MODDIR/config/gms_overlays.txt"
PATCHES_FILE="$MODDIR/config/deviceidle_patches.txt"
PATCHES_BACKUP="$MODDIR/backup/patched_packages.txt"

ENABLE_GMS_DOZE=0
[ -f "$USER_PREFS" ] && . "$USER_PREFS"

GMS_PKG="com.google.android.gms"
GMS_ADMIN1="$GMS_PKG/$GMS_PKG.auth.managed.admin.DeviceAdminReceiver"
GMS_ADMIN2="$GMS_PKG/$GMS_PKG.mdm.receivers.MdmDeviceAdminReceiver"

# Partitions that may carry sysconfig or deviceidle XMLs with GMS whitelist entries
_ALL_PARTITIONS="/india /my_bigball /my_carrier /my_company /my_engineering /my_heytap \
                 /my_manifest /my_preload /my_product /my_region /my_reserve /my_stock \
                 /odm /product /system /system_ext /vendor"

_PARTITIONS=""

_GMS_PATTERNS="allow-in-power-save.*${GMS_PKG//[\.]/\\.} \
               allow-in-data-usage-save.*${GMS_PKG//[\.]/\\.} \
               <wl[^>]*>[[:space:]]*${GMS_PKG//[\.]/\\.}[[:space:]]*</wl>"

_GMS_GREP=""
_GMS_SED=""

_PKGS_TO_PATCH=""


mkdir -p "$LOGDIR"
log_doze() { echo "[$(date '+%H:%M:%S')] $1" >> "$DOZE_LOG"; }

# Initialize variables
_init() {
  # Filter partitions by existence
  for _p in $_ALL_PARTITIONS;do
    [ -d "$_p" ] || continue
    _PARTITIONS="${_PARTITIONS:+$_PARTITIONS }/${_p#/}"
  done

  # Add custom patches to _GMS_PATTERNS
  _load_patches
  for pkg in $_PKGS_TO_PATCH; do
    pkg="${pkg#\*}"
    _GMS_PATTERNS="$_GMS_PATTERNS \
                   <wl[^>]*>[[:space:]]*${pkg//[\.]/\\.}[[:space:]]*</wl>"
  done

  # Convert _GMS_PATTERNS to _GMS_GREP & _GMS_SED
  for _pattern in $_GMS_PATTERNS; do
    _GMS_GREP="${_GMS_GREP:+$_GMS_GREP|}$_pattern"
    _GMS_SED="$_GMS_SED/${_pattern/\//\\/}/d;"
  done
}

# Check if overlays file exists and no new patches are needed
_is_patched() {
  [ ! -f "$OVERLAYS_FILE" ] && return 1
  [ -n "$_PKGS_TO_PATCH" ] && {
    for pkg in $_PKGS_TO_PATCH; do
      case "$pkg" in
        \**) return 1 ;;
      esac
    done
  }
  return 0
}

# Get user IDs of device
_get_user_ids() {
  pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | grep -oE '[0-9]+' || ls /data/user 2>/dev/null
}

# Only apps in /data/app are really safe to be optimized
_is_safe_app() {
  _paths="$(pm path "$1" 2>/dev/null)"
  [ -z "$_paths" ] && return 1 # App is not installed

  while IFS= read -r path; do
    case "$path" in
      package:/data/app/*) ;;
      package:/*) return 1 ;;
      *) continue ;;
    esac
  done <<EOF
$_paths
EOF
  return 0
}

_load_patches() {
  _normalize() {
    sed -E 's/^[[:space:]]*#.*//;s/#.*//;s/^[[:space:]]+//;s/[[:space:]]+$//' "$1" \
    | grep -v '^$' | sort -u
  }

  [ ! -f "$PATCHES_BACKUP" ] && {
    mkdir -p "$(dirname "$PATCHES_BACKUP")"
    printf "# DeviceIdle Patches - $(date '+%Y-%m-%d %H:%M:%S')\n" > "$PATCHES_BACKUP"
  }

  OLD_PKGS="$(_normalize "$PATCHES_BACKUP")"
  NEW_PKGS="$(_normalize "$PATCHES_FILE")"

  if [ "$NEW_PKGS" != "$OLD_PKGS" ]; then
    for pkg in $NEW_PKGS; do
      [ -n "$pkg" ] && _is_safe_app "$pkg" || continue

      case " $OLD_PKGS " in
        *" $pkg "*) continue ;;
      esac
      
      _PKGS_TO_PATCH="${_PKGS_TO_PATCH:+$_PKGS_TO_PATCH }*$pkg"
    done

    {
      printf "# DeviceIdle Patches - %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
      printf "%s\n" $NEW_PKGS 
    } > "$PATCHES_BACKUP"
  else
    for pkg in $OLD_PKGS; do
      [ -n "$pkg" ] && _is_safe_app "$pkg" || continue
      _PKGS_TO_PATCH="${_PKGS_TO_PATCH:+$_PKGS_TO_PATCH }$pkg"
    done
  fi
}


# Initialize variables before running any scripts
_init

# Log full status to doze log
log_status() {
  local label="$1"
  [ -s "$DOZE_LOG" ] || echo "Frosty v${MODVER:-?} - GMS Doze (STATUS) - $(date '+%Y-%m-%d %H:%M:%S')" > "$DOZE_LOG"
  log_doze "Status after $label"

  local wl_full=$(dumpsys deviceidle whitelist 2>/dev/null)
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

  local overlay_count=0
  [ -f "$OVERLAYS_FILE" ] && overlay_count=$(grep -c '.' "$OVERLAYS_FILE" 2>/dev/null)
  log_doze "[INFO] XML overlays: $overlay_count"

  local has_unwl="NO"
  [ -f /data/system/deviceidle.xml ] && \
    grep -q "<un-wl n=\"${GMS_PKG//[\.]/\\.}\"" /data/system/deviceidle.xml 2>/dev/null && has_unwl="YES"
  log_doze "[INFO] deviceidle.xml <un-wl>: $has_unwl"

  local has_wl="NO"
  [ -f /data/system/deviceidle.xml ] && \
    grep -q "<wl n=\"${GMS_PKG//[\.]/\\.}\"" /data/system/deviceidle.xml 2>/dev/null && has_wl="YES"
  log_doze "[INFO] deviceidle.xml <wl>: $has_wl"

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

patch_xml() {
  if _is_patched; then
    local existing=0
    [ -f "$OVERLAYS_FILE" ] && existing=$(grep -c '.' "$OVERLAYS_FILE" 2>/dev/null)
    log_doze "[OK] $existing overlay(s) already generated"
    return 0
  fi

  log_doze "Scanning for GMS whitelist XMLs..."
  local count=0 scanned=0 seen=""

  for _p in $_PARTITIONS; do
    [ -d "$_p" ] || continue
    for _dir in "$_p/etc" "$_p/oplus" "$_p/oppo"; do
      [ -d "$_dir" ] || continue
      for xml in $(find "$_dir" -type f -name "*.xml" -depth -maxdepth 2 2>/dev/null); do
        local real=$(readlink -f "$xml" 2>/dev/null)
        [ -z "$real" ] && real="$xml"
        case "$seen" in *"|$real|"*) continue ;; esac
        seen="${seen}|${real}|"
        scanned=$((scanned + 1))

        grep -qE "$_GMS_GREP" "$xml" 2>/dev/null || continue

        # Store at the correct root for the partition — separate partitions
        # (product, vendor, odm) must NOT be nested under system/ or
        # Magisk will try to mount them via the /system/<partition> symlink
        # which fails on devices where those partitions have their own mount point.
        local relative="${real#/}"
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
          log_doze "[OK] Patched: $real -> $relative"
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
    log_doze "[OK] $count XML(s) overlaid from $scanned scanned — reboot to mount"
    # Clear cache of GMS to fix possible notification delays
    rm -rf "/data/data/$GMS_PKG/cache/*" 2>/dev/null && \
      log_doze "[OK] GMS cache cleared"
  fi
}

remove_xml() {
  if _is_patched; then
    local count=0
    while IFS= read -r file; do
      [ -f "$file" ] && rm -f "$file" && count=$((count + 1))
    done < "$OVERLAYS_FILE"
    rm -f "$OVERLAYS_FILE"
    log_doze "[OK] Removed $count overlay files"
  fi

  for _root in system product vendor odm system_ext; do
    [ -d "$MODDIR/$_root" ] && find "$MODDIR/$_root" -type d -empty -delete 2>/dev/null
  done
}

apply() {
  echo "Frosty v${MODVER:-?} - GMS Doze (APPLY) - $(date '+%Y-%m-%d %H:%M:%S')" > "$DOZE_LOG"

  if [ "$ENABLE_GMS_DOZE" != "1" ]; then
    log_doze "[SKIP] GMS Doze disabled by user"
    return 0
  fi

  log_doze "Applying GMS Doze..."

  # 1. Create XML overlays for root manager to mount
  patch_xml

  # 2. Disable device admin receivers
  local admin_count=0
  for user_id in $(_get_user_ids); do
    for admin in "$GMS_ADMIN1" "$GMS_ADMIN2"; do
      if pm disable --user "$user_id" "$admin" >/dev/null 2>&1; then
        log_doze "[OK] Disabled: $admin (user $user_id)"
        admin_count=$((admin_count + 1))
      fi
    done
  done
  log_doze "Disabled $admin_count device admin receiver(s)"

  for pkg in $_PKGS_TO_PATCH "$GMS_PKG";do
    pkg="${pkg#\*}"
    log_doze "Patching \"$pkg\"..."

    # 3. Runtime whitelist removal
    dumpsys deviceidle whitelist -"$pkg" >/dev/null 2>&1
    log_doze "[OK] Removed from user whitelist"

    local sys_out=$(cmd deviceidle sys-whitelist -"$GMS_PKG" 2>&1)
    case "$sys_out" in
      *[Uu]nknown*|*[Ee]rror*) log_doze "[INFO] sys-whitelist not available" ;;
      *) log_doze "[OK] sys-whitelist: ${sys_out:-executed}" ;;
    esac
    
    # Best-effort: try except-idle removal (only affects user tier of except-idle,
    cmd deviceidle except-idle-whitelist -"$pkg" >/dev/null 2>&1

    # 4. Remove persistent <wl> from deviceidle.xml
    if [ -f /data/system/deviceidle.xml ] && \
        grep -q "<wl n=\"${pkg//[\.]/\\.}\"" /data/system/deviceidle.xml 2>/dev/null; then
      sed -i "/<wl n=\"${pkg//[\.]/\\.}\"/d" /data/system/deviceidle.xml
      restorecon /data/system/deviceidle.xml 2>/dev/null
      log_doze "[OK] Removed persistent <wl> from deviceidle.xml"
    fi
  done

  # GMS loses allow-in-power-save via sysconfig, so the OS is now allowed to
  # kill its processes during idle. Warm it back up here so Camera, PayPal, and
  # other GMS-dependent apps don't crash on first open after doze is applied.
  am start-service -n "$GMS_PKG/.checkin.CheckinService" >/dev/null 2>&1 || true
  log_doze "[OK] GMS warmed up"

  # 5. Full status
  log_status "apply"
}

revert() {
  echo "Frosty v${MODVER:-?} - GMS Doze (REVERT) - $(date '+%Y-%m-%d %H:%M:%S')" > "$DOZE_LOG"

  log_doze "Reverting GMS Doze..."

  # 1. Remove XML overlays
  remove_xml

  # 2. Restore whitelists
  dumpsys deviceidle whitelist +"$GMS_PKG" >/dev/null 2>&1
  log_doze "[OK] Restored to user whitelist"

  local sys_out=$(cmd deviceidle sys-whitelist +"$GMS_PKG" 2>&1)
  case "$sys_out" in
    *[Uu]nknown*|*[Ee]rror*) log_doze "[INFO] sys-whitelist not available" ;;
    *) log_doze "[OK] sys-whitelist restore: ${sys_out:-executed}" ;;
  esac

  # 3. Re-enable device admin receivers
  local admin_count=0
  for user_id in $(_get_user_ids); do
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
  log_status "revert"
}

case "$1" in
  apply|freeze) apply ;;
  revert|stock) revert ;;
esac
exit 0
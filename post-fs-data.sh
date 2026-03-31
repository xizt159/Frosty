#!/system/bin/sh
# FROSTY - Post-FS-Data

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"

[ -f "$MODDIR/config/user_prefs" ] && . "$MODDIR/config/user_prefs"

# GMS Doze: deviceidle.xml + conflicting module patching
_DIXML="/data/system/deviceidle.xml"
_GMS="com.google.android.gms"

# Partitions that may carry sysconfig or deviceidle XMLs with GMS whitelist entries
_ALL_PARTITIONS="/india /my_bigball /my_carrier /my_company /my_engineering /my_heytap \
                 /my_manifest /my_preload /my_product /my_region /my_reserve /my_stock \
                 /odm /product /system /system_ext /vendor"

_PARTITIONS=""

_GMS_PATTERNS="allow-in-power-save.*${_GMS//[\.]/\\.} \
               allow-in-data-usage-save.*${_GMS//[\.]/\\.} \
               <wl[^>]*>[[:space:]]*${_GMS//[\.]/\\.}[[:space:]]*</wl>"


if [ "$ENABLE_GMS_DOZE" = "1" ]; then
  _GREP_PATTERN=""
  _SED_PATTERN=""

  # Filter partitions by existence
  for _p in $_ALL_PARTITIONS;do
    [ -d "$_p" ] || continue
    _PARTITIONS="${_PARTITIONS:+$_PARTITIONS }/${_p#/}"
  done

  # Convert _GMS_PATTERNS to _GREP_PATTERN & _SED_PATTERN
  for _pattern in $_GMS_PATTERNS; do
    _GREP_PATTERN="${_GREP_PATTERN:+$_GREP_PATTERN|}$_pattern"
    _SED_PATTERN="$_SED_PATTERN/${_pattern/\//\\/}/d;"
  done

  # Patch deviceidle.xml
  if [ -f "$_DIXML" ]; then
    _tmp="${_DIXML}.frosty.tmp"
    cp -af "$_DIXML" "$_tmp" 2>/dev/null
    _changed=0

    # Clean up invalid <un n="...">
    if grep -q '<un n="' "$_tmp" 2>/dev/null; then
      sed -i '/<un n="/d' "$_tmp"
      _changed=1
    fi

    # Clean up literal \n from non-portable sed
    if grep -q '\\n' "$_tmp" 2>/dev/null; then
      sed -i 's/\\n//g' "$_tmp"
      _changed=1
    fi

    # Remove <wl> entry for GMS (prevents user tier re-add on boot)
    if grep -q "<wl n=\"$_GMS\"" "$_tmp" 2>/dev/null; then
      sed -i "/<wl n=\"$_GMS\"/d" "$_tmp"
      _changed=1
    fi

    # Inject <un-wl> to remove GMS from system whitelist tier
    if ! grep -q "<un-wl n=\"$_GMS\"" "$_tmp" 2>/dev/null; then
      sed -i '/<\/config>/d' "$_tmp"
      echo "<un-wl n=\"$_GMS\" />" >> "$_tmp"
      echo "</config>" >> "$_tmp"
      _changed=1
    fi

    # Validate and apply
    if [ "$_changed" -eq 1 ] && grep -q '</config>' "$_tmp" 2>/dev/null; then
      cat "$_tmp" > "$_DIXML"
      restorecon "$_DIXML" 2>/dev/null
    fi
    rm -f "$_tmp" 2>/dev/null

    # Defense in depth: re-verify <wl> is gone from the actual file
    if grep -q "<wl n=\"$_GMS\"" "$_DIXML" 2>/dev/null; then
      sed -i "/<wl n=\"$_GMS\"/d" "$_DIXML"
      restorecon "$_DIXML" 2>/dev/null
    fi
  fi

  # Early bind mount of patched sysconfig and whitelist XMLs — must happen before system_server
  # starts (which populates system-excidle by reading sysconfig).
  # On first boot after enabling GMS Doze the patched XMLs don't exist yet
  # gms_doze.sh creates them in service.sh, and they'll be mounted here from the next boot.
  for _p in $_PARTITIONS; do
    find "$MODDIR" -path "*/${_p#/}/*.xml" -type f 2>/dev/null | while IFS= read -r _src; do
      _dst="${_src#$MODDIR}"
      # Separate partition layout: $MODDIR/product/... → /product/...
      [ ! -f "$_dst" ] && _dst="${_dst#/system}"
      [ ! -f "$_dst" ] && continue
      # Only mount if destination still has the GMS entry (overlay not already effective)
      grep -qE "$_GREP_PATTERN" "$_dst" 2>/dev/null || continue
      # Match SELinux context of destination
      _ctx=$(stat -c %C "$_dst" 2>/dev/null)
      [ -n "$_ctx" ] && chcon "$_ctx" "$_src" 2>/dev/null
      mount --bind "$_src" "$_dst" 2>/dev/null
    done
  done

  # Patch conflicting modules search entire modules/ tree
  # KSU moves partition dirs (product/, vendor/) out of system/ to module root
  for _p in $_PARTITIONS; do
    find /data/adb/modules -path "*/${_p#/}/*.xml" -type f 2>/dev/null |
    while IFS= read -r _xml; do
      case "$_xml" in "$MODDIR/"*) continue ;; esac
      if grep -qE "$_GREP_PATTERN" "$_xml" 2>/dev/null; then
        sed -i "$_SED_PATTERN" "$_xml"
      fi
    done
  done

else
  # GMS Doze disabled, clean up deviceidle.xml
  if [ -f "$_DIXML" ]; then
    _changed=0

    if grep -q '<un n="' "$_DIXML" 2>/dev/null; then
      sed -i '/<un n="/d' "$_DIXML"
      _changed=1
    fi

    if grep -q '\\n' "$_DIXML" 2>/dev/null; then
      sed -i 's/\\n//g' "$_DIXML"
      _changed=1
    fi

    if grep -q "<un-wl n=\"$_GMS\"" "$_DIXML" 2>/dev/null; then
      sed -i "/<un-wl n=\"$_GMS\"/d" "$_DIXML"
      _changed=1
    fi

    [ "$_changed" -eq 1 ] && restorecon "$_DIXML" 2>/dev/null
  fi
fi

unset _DIXML _GMS _changed _tmp _xml _src _dst _ctx

# Blur Disable
if [ "$ENABLE_BLUR_DISABLE" = "1" ]; then
  resetprop -n disableBlurs true
  resetprop -n enable_blurs_on_windows 0
  resetprop -n ro.launcher.blur.appLaunch 0
  resetprop -n ro.sf.blurs_are_expensive 0
  resetprop -n ro.surface_flinger.supports_background_blur 0
fi

# Log Killing
INITDIR="$MODDIR/system/etc/init"
BINDIR="$MODDIR/system/bin"

if [ "$ENABLE_LOG_KILLING" = "1" ]; then
  resetprop -n tombstoned.max_tombstone_count 0
  resetprop -n tombstoned.max_anr_count 0
  resetprop -n ro.lmk.debug false
  resetprop -n ro.lmk.log_stats false
  resetprop -n dalvik.vm.dex2oat-minidebuginfo false
  resetprop -n dalvik.vm.minidebuginfo false

  resetprop -n sys.wifitracing.started 0
  resetprop -n persist.vendor.wifienhancelog 0

  mkdir -p "$INITDIR"
  for rc in atrace atrace_userdebug bugreport dmesgd \
            dumpstate logcat logcatd logd logtagd lpdumpd tombstoned \
            traced traced_perf traced_probes traceur; do
    [ ! -f "$INITDIR/${rc}.rc" ] && : > "$INITDIR/${rc}.rc"
  done

  mkdir -p "$BINDIR"
  for bin in atrace bugreport bugreport_procdump bugreportz \
            diag_socket_log dmabuf_dump dmesgd \
            dumpstate i2cdump log logcat logcatd logd logger logname \
            logpersist.cat logpersist.start logpersist.stop \
            lpdump lpdumpd notify_traceur.sh tcpdump tombstoned traced \
            traced_perf traced_probes tracepath tracepath6 traceroute6; do
    if [ ! -f "$BINDIR/$bin" ]; then
      : > "$BINDIR/$bin"
      chmod 755 "$BINDIR/$bin"
    fi
  done
else
  if [ -d "$INITDIR" ]; then
    rm -f "$INITDIR"/*.rc
    rmdir "$INITDIR" 2>/dev/null
  fi
  if [ -d "$BINDIR" ]; then
    rm -f "$BINDIR"/*
    rmdir "$BINDIR" 2>/dev/null
  fi
  rmdir "$MODDIR/system/etc" 2>/dev/null
  [ -d "$MODDIR/system" ] && [ -z "$(ls -A "$MODDIR/system" 2>/dev/null)" ] && rmdir "$MODDIR/system" 2>/dev/null
fi

#!/system/bin/sh
# Frosty - Post-FS-Data

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"

[ -f "$MODDIR/config/user_prefs" ] && . "$MODDIR/config/user_prefs"

DIXML="/data/system/deviceidle.xml"
GMS_PKG="com.google.android.gms"

_GMS_GREP="allow-in-power-save.*com\.google\.android\.gms|allow-in-data-usage-save.*com\.google\.android\.gms"

if [ "$ENABLE_GMS_DOZE" = "1" ]; then
  if [ -f "$DIXML" ]; then
    _tmp="${DIXML}.frosty.tmp"
    cp -af "$DIXML" "$_tmp" 2>/dev/null
    _changed=0

    if grep -q '<un n="' "$_tmp" 2>/dev/null; then
      sed -i '/<un n="/d' "$_tmp"
      _changed=1
    fi

    if grep -q '\\n' "$_tmp" 2>/dev/null; then
      sed -i 's/\\n//g' "$_tmp"
      _changed=1
    fi

    if grep -q "<wl n=\"$GMS_PKG\"" "$_tmp" 2>/dev/null; then
      sed -i "/<wl n=\"$GMS_PKG\"/d" "$_tmp"
      _changed=1
    fi

    if ! grep -q "<un-wl n=\"$GMS_PKG\"" "$_tmp" 2>/dev/null; then
      sed -i '/<\/config>/d' "$_tmp"
      echo "<un-wl n=\"$GMS_PKG\" />" >> "$_tmp"
      echo "</config>" >> "$_tmp"
      _changed=1
    fi

    if [ "$_changed" -eq 1 ] && grep -q '</config>' "$_tmp" 2>/dev/null; then
      cat "$_tmp" > "$DIXML"
      restorecon "$DIXML" 2>/dev/null
    fi
    rm -f "$_tmp" 2>/dev/null

    if grep -q "<wl n=\"$GMS_PKG\"" "$DIXML" 2>/dev/null; then
      sed -i "/<wl n=\"$GMS_PKG\"/d" "$DIXML"
      restorecon "$DIXML" 2>/dev/null
    fi
  fi

  # Bind mount fallback for patched sysconfig XMLs — must happen before system_server
  # starts. On first boot after enabling, patched XMLs don't exist yet (created later
  # by gms_doze.sh in service.sh); they'll be mounted from the next boot.
  find "$MODDIR" -path "*/sysconfig/*.xml" -type f 2>/dev/null | while IFS= read -r _src; do
    _dst="${_src#$MODDIR}"
    # For known separate partitions, the path is already correct and must NOT be
    # resolved through the /system/<partition> symlink — doing so causes stale
    # bind mounts that stack across boots on devices where these are separate mount points.
    case "$_dst" in
      /product/*|/vendor/*|/odm/*|/system_ext/*) ;;
      *) [ ! -f "$_dst" ] && _dst="${_dst#/system}" ;;
    esac
    [ ! -f "$_dst" ] && continue
    grep -qE "$_GMS_GREP" "$_dst" 2>/dev/null || continue
    _ctx=$(stat -c %C "$_dst" 2>/dev/null)
    [ -n "$_ctx" ] && chcon "$_ctx" "$_src" 2>/dev/null
    mount --bind "$_src" "$_dst" 2>/dev/null
  done

  # Patch conflicting modules that re-add GMS to power-save whitelists
  find /data/adb/modules -path "*/sysconfig/*.xml" -type f 2>/dev/null |
  while IFS= read -r _xml; do
    case "$_xml" in "$MODDIR/"*) continue ;; esac
    if grep -qE "$_GMS_GREP" "$_xml" 2>/dev/null; then
      sed -i '/allow-in-power-save.*com\.google\.android\.gms/d;/allow-in-data-usage-save.*com\.google\.android\.gms/d' "$_xml"
    fi
  done

else
  if [ -f "$DIXML" ]; then
    _changed=0
    if grep -q '<un n="' "$DIXML" 2>/dev/null; then
      sed -i '/<un n="/d' "$DIXML"
      _changed=1
    fi
    if grep -q '\\n' "$DIXML" 2>/dev/null; then
      sed -i 's/\\n//g' "$DIXML"
      _changed=1
    fi
    if grep -q "<un-wl n=\"$GMS_PKG\"" "$DIXML" 2>/dev/null; then
      sed -i "/<un-wl n=\"$GMS_PKG\"/d" "$DIXML"
      _changed=1
    fi
    [ "$_changed" -eq 1 ] && restorecon "$DIXML" 2>/dev/null
  fi
fi

unset DIXML GMS_PKG _GMS_GREP _changed _tmp _xml _src _dst _ctx

# Blur Disable
if [ "$ENABLE_BLUR_DISABLE" = "1" ]; then
  resetprop -n disableBlurs true
  resetprop -n enable_blurs_on_windows 0
  resetprop -n ro.launcher.blur.appLaunch 0
  resetprop -n ro.sf.blurs_are_expensive 0
  resetprop -n ro.surface_flinger.supports_background_blur 0
fi

# Log Binary Stubs
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

  mkdir -p "$INITDIR" "$BINDIR"

  for rc in atrace atrace_userdebug bugreport dmesgd \
            dumpstate logcat logcatd logd logtagd lpdumpd \
            traced traced_perf traced_probes traceur; do
    : > "$INITDIR/${rc}.rc"
  done

  for bin in atrace bugreport bugreport_procdump bugreportz \
            diag_socket_log dmabuf_dump dmesgd \
            dumpstate i2cdump log logcat logcatd logd logger logname \
            logpersist.cat logpersist.start logpersist.stop logwrapper \
            lpdump lpdumpd notify_traceur.sh tcpdump traced \
            traced_perf traced_probes tracepath tracepath6 traceroute6; do
    printf '#!/system/bin/sh\nexit 0\n' > "$BINDIR/$bin"
    chmod 755 "$BINDIR/$bin"
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
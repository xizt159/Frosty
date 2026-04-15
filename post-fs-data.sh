#!/system/bin/sh
# Frosty - Post-FS-Data

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/Frosty"

[ -f "$MODDIR/config/user_prefs" ] && . "$MODDIR/config/user_prefs"

_DIXML="/data/system/deviceidle.xml"
_GMS="com.google.android.gms"

_GMS_GREP="allow-in-power-save.*com\.google\.android\.gms|allow-in-data-usage-save.*com\.google\.android\.gms"

if [ "$ENABLE_GMS_DOZE" = "1" ]; then
  if [ -f "$_DIXML" ]; then
    _tmp="${_DIXML}.frosty.tmp"
    cp -af "$_DIXML" "$_tmp" 2>/dev/null
    _changed=0

    if grep -q '<un n="' "$_tmp" 2>/dev/null; then
      sed -i '/<un n="/d' "$_tmp"
      _changed=1
    fi

    if grep -q '\\n' "$_tmp" 2>/dev/null; then
      sed -i 's/\\n//g' "$_tmp"
      _changed=1
    fi

    if grep -q "<wl n=\"$_GMS\"" "$_tmp" 2>/dev/null; then
      sed -i "/<wl n=\"$_GMS\"/d" "$_tmp"
      _changed=1
    fi

    if ! grep -q "<un-wl n=\"$_GMS\"" "$_tmp" 2>/dev/null; then
      sed -i '/<\/config>/d' "$_tmp"
      echo "<un-wl n=\"$_GMS\" />" >> "$_tmp"
      echo "</config>" >> "$_tmp"
      _changed=1
    fi

    if [ "$_changed" -eq 1 ] && grep -q '</config>' "$_tmp" 2>/dev/null; then
      cat "$_tmp" > "$_DIXML"
      restorecon "$_DIXML" 2>/dev/null
    fi
    rm -f "$_tmp" 2>/dev/null

    if grep -q "<wl n=\"$_GMS\"" "$_DIXML" 2>/dev/null; then
      sed -i "/<wl n=\"$_GMS\"/d" "$_DIXML"
      restorecon "$_DIXML" 2>/dev/null
    fi
  fi

  # Bind mount fallback for patched sysconfig XMLs, must happen before system_server starts. On first boot after enabling, patched XMLs don't exist yet (created later by gms_doze.sh in service.sh); they'll be mounted from the next boot.
  find "$MODDIR" \( -path "*/sysconfig/*.xml" -o -path "*/oplus/*.xml" -o -path "*/oppo/*.xml" \) -type f 2>/dev/null | while IFS= read -r _src; do
    _dst="${_src#$MODDIR}"
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
  find /data/adb/modules \( -path "*/sysconfig/*.xml" -o -path "*/oplus/*.xml" -o -path "*/oppo/*.xml" \) -type f 2>/dev/null |
  while IFS= read -r _xml; do
    case "$_xml" in "$MODDIR/"*) continue ;; esac
    if grep -qE "$_GMS_GREP" "$_xml" 2>/dev/null; then
      sed -i '/allow-in-power-save.*com\.google\.android\.gms/d;/allow-in-data-usage-save.*com\.google\.android\.gms/d' "$_xml"
    fi
  done

else
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

unset _GMS _GMS_GREP _xml _src _dst _ctx

# Custom App Doze - bind mount patched sysconfig XML overlays
# Same mechanism as GMS Doze: mount before system_server reads sysconfig.
_CAD_OVERLAYS="$MODDIR/config/cad_overlays.txt"
if [ "$ENABLE_CUSTOM_APP_DOZE" = "1" ] && [ -f "$_CAD_OVERLAYS" ]; then
  while IFS= read -r _src; do
    case "$_src" in '###'*|'#'*|'') continue ;; esac
    [ -f "$_src" ] || continue
    _dst="${_src#$MODDIR}"
    case "$_dst" in
      /product/*|/vendor/*|/odm/*|/system_ext/*|\
      /my_product/*|/my_heytap/*|/my_region/*|/my_bigball/*|/my_carrier/*|\
      /my_company/*|/my_engineering/*|/my_manifest/*|/my_preload/*|\
      /my_reserve/*|/my_stock/*|/india/*) ;;
      *) [ ! -f "$_dst" ] && _dst="${_dst#/system}" ;;
    esac
    [ ! -f "$_dst" ] && continue
    _ctx=$(stat -c %C "$_dst" 2>/dev/null)
    [ -n "$_ctx" ] && chcon "$_ctx" "$_src" 2>/dev/null
    mount --bind "$_src" "$_dst" 2>/dev/null
  done < "$_CAD_OVERLAYS"
fi
unset _CAD_OVERLAYS _src _dst _ctx

# Custom App Doze - deviceidle.xml patching
# Always wipe every <un-wl> entry Frosty previously wrote, then re-inject
# only what is currently in the list. Android never writes <un-wl> entries
# itself, so removing all of them is safe regardless of feature state.
_CAD_PATCHES="$MODDIR/config/doze_patches.txt"

if [ -f "$_DIXML" ] && grep -q '<un-wl ' "$_DIXML" 2>/dev/null; then
  sed -i '/<un-wl /d' "$_DIXML"
  restorecon "$_DIXML" 2>/dev/null
fi

if [ "$ENABLE_CUSTOM_APP_DOZE" = "1" ] && [ -f "$_CAD_PATCHES" ] && [ -f "$_DIXML" ]; then
  _cad_pkgs=$(sed 's/###.*//;s/#.*//;s/[[:space:]]//g' "$_CAD_PATCHES" 2>/dev/null | grep -v '^$')
  if [ -n "$_cad_pkgs" ]; then
    _tmp="${_DIXML}.cad.tmp"
    cp -af "$_DIXML" "$_tmp" 2>/dev/null

    grep -q '\n' "$_tmp" 2>/dev/null && sed -i 's/\n//g' "$_tmp"

    for _pkg in $_cad_pkgs; do
      sed -i "/<wl n=\"$_pkg\"/d" "$_tmp" 2>/dev/null
      sed -i '/<\/config>/d' "$_tmp"
      echo "<un-wl n=\"$_pkg\" />" >> "$_tmp"
      echo "</config>" >> "$_tmp"
    done

    if grep -q '</config>' "$_tmp" 2>/dev/null; then
      cat "$_tmp" > "$_DIXML"
      restorecon "$_DIXML" 2>/dev/null
    fi
    rm -f "$_tmp" 2>/dev/null
  fi
fi

unset _DIXML _CAD_PATCHES _cad_pkgs _pkg _tmp

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
  rm -rf "$INITDIR" "$BINDIR"
  rmdir "$MODDIR/system/etc" 2>/dev/null
  rmdir "$MODDIR/system" 2>/dev/null
fi
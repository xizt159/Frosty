#!/system/bin/sh
# Frosty - GMS Freezer / Battery Saver
# Author: Drsexo (GitHub)

TIMEOUT=30

COLS=$(stty size 2>/dev/null | awk '{print $2}')
case "$COLS" in ''|*[!0-9]*) COLS=40 ;; esac
[ "$COLS" -gt 54 ] && COLS=54; [ "$COLS" -lt 20 ] && COLS=40

_iw=$((COLS - 4))
LINE="" _i=0
while [ $_i -lt $_iw ]; do
  LINE="${LINE}─"
  _i=$((_i + 1))
done
BOX_TOP="  ┌${LINE}┐"
BOX_BOT="  └${LINE}┘"
unset _i _iw

if ! command -v timeout >/dev/null 2>&1; then
  timeout() { shift; "$@"; }
fi

HAS_GETEVENT=1
if ! command -v getevent >/dev/null 2>&1; then
  HAS_GETEVENT=0
fi

print_banner() {
  ui_print ""
  ui_print "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣤⡀⠀⣠⡆⠀⠀⠀⠀⠀⠀⠀⠀⣤⠀⠀⠀⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠈⢻⣿⠋⠀⠀⠀⠀⠀⢸⣧⠀⢀⣾⣦⣤⣤⣄⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⢿⡇⠀⣶⠀⠀⠺⣦⣼⣧⣴⡿⠀⠀⠀⠀⠀⢻⣦⣾⣛⠉⠉⠉⠁⠀⠀"
  ui_print "⠀⠀⢶⣶⣤⣼⣧⣰⣏⠀⠀⠀⠈⠹⣿⠋⠀⠀⠀⠀⠀⢀⣾⠟⠛⠛⠻⠿⠂⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⢠⣬⣿⣿⣿⡀⢀⡄⢠⣤⣿⣤⡦⠀⢿⣄⣴⣟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⠀⠀⠀⢈⣿⣿⣇⠀⠙⣿⠋⠀⠀⣨⡿⠟⠛⠃⠀⠀⠀⢀⣶⠀⣠⡀⠀"
  ui_print "⠀⠀⠀⠀⠀⠀⢠⡀⠀⠀⠀⠀⠈⠙⢷⣤⣿⡆⢀⣴⠟⠀⠀⠀⣠⡟⠀⢀⣾⢃⣴⠟⠁⠀"
  ui_print "⠰⣦⡀⠀⠘⢿⣄⠀⢰⣦⣀⣀⣀⣹⣿⣷⣿⣷⣤⣴⡶⢾⣿⣷⡾⢿⣿⡟⠿⣶⣄⠀"
  ui_print "⠀⠈⣿⣷⣶⣶⣿⣿⠿⢿⣿⠟⠋⣹⣿⡟⠻⣿⣄⠀⠀⠀⠈⠙⠀⠀⠙⢿⣦⠀⠙⠁"
  ui_print "⠰⠾⠋⠀⠀⣾⠟⠁⠀⣾⡁⢀⣴⠟⠸⣧⠀⠈⠻⣷⣶⣤⡤⠀⠀⠀⠀⠀⠀⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⠀⣀⠀⠀⠈⣻⣿⣿⠀⠀⣿⠀⠀⠀⢸⡟⠻⣦⣄⣀⣠⣤⣄⡀⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⠀⠙⠛⢻⣾⡟⠉⠃⠀⣠⣿⣄⠀⠀⠈⠁⠀⢸⣿⢿⣿⡷⠾⠃⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⢶⣶⣦⣶⡟⢿⠃⠀⠀⠚⠋⢻⡟⠗⠀⠀⠀⠀⠘⠿⠀⢿⡄⠀⠀⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⠀⢨⡿⠀⠈⠀⠀⠀⠀⠀⣸⣧⡀⠀⠀⠀⠀⠀⠀⠀⠘⠁⠀⠀⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⢀⣴⠿⣿⡿⢶⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
  ui_print "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⠟⠀⠀⠛⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
  ui_print ""
  ui_print "        _______  ____  ____________  __"
  ui_print "       / __/ _ \/ __ \/ __/_  __/\ \/ /"
  ui_print "      / _// , _/ /_/ /\ \  / /    \  / "
  ui_print "     /_/ /_/|_|\____/___/ /_/     /_/  "
  ui_print ""
  ui_print "        ❆  Freeze your battery drain  ❆"
  ui_print ""
}

print_section() {
  local text="$1"
  local len=${#text}
  local inner=$((COLS - 4))
  local offset=$(( (inner - len) / 2 ))
  [ "$offset" -lt 0 ] && offset=0
  local pad=$((offset + 3))
  local lpad="" _p=0
  while [ $_p -lt $pad ]; do lpad="${lpad} "; _p=$((_p+1)); done
  ui_print ""
  ui_print "$BOX_TOP"
  ui_print "${lpad}${text}"
  ui_print "$BOX_BOT"
}

# Permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/frosty.sh" 0 0 0755
set_perm "$MODPATH/gms_doze.sh" 0 0 0755
set_perm "$MODPATH/deep_doze.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
mkdir -p "$MODPATH/config"
mkdir -p "$MODPATH/logs"

# GMS check
if ! pm list packages 2>/dev/null | grep -q "com.google.android.gms"; then
  ui_print ""
  ui_print "  ⚠️  Google Play Services not found!"
  ui_print "  GMS freezing and doze features will not work."
  ui_print ""
fi

print_banner

# Language Selection

_detect_lang() {
  local loc
  loc=$(getprop persist.sys.locale 2>/dev/null)
  [ -z "$loc" ] && loc=$(getprop ro.product.locale 2>/dev/null)
  [ -z "$loc" ] && loc=$(getprop persist.sys.language 2>/dev/null)
  echo "$loc" | cut -d'-' -f1 | cut -d'_' -f1 | tr '[:upper:]' '[:lower:]'
}

_LANG=$(_detect_lang)
INSTALL_LANG="en"

case "$_LANG" in
  fr) _LANG_FLAG="🇫🇷"; _LANG_NAME="Français" ;;
  de) _LANG_FLAG="🇩🇪"; _LANG_NAME="Deutsch" ;;
  pl) _LANG_FLAG="🇵🇱"; _LANG_NAME="Polski" ;;
  it) _LANG_FLAG="🇮🇹"; _LANG_NAME="Italiano" ;;
  es) _LANG_FLAG="🇪🇸"; _LANG_NAME="Español" ;;
  pt) _LANG_FLAG="🇧🇷"; _LANG_NAME="Português" ;;
  tr) _LANG_FLAG="🇹🇷"; _LANG_NAME="Türkçe" ;;
  id) _LANG_FLAG="🇮🇩"; _LANG_NAME="Indonesia" ;;
  ru) _LANG_FLAG="🇷🇺"; _LANG_NAME="Русский" ;;
  uk) _LANG_FLAG="🇺🇦"; _LANG_NAME="Українська" ;;
  zh) _LANG_FLAG="🇨🇳"; _LANG_NAME="中文" ;;
  ja) _LANG_FLAG="🇯🇵"; _LANG_NAME="日本語" ;;
  ar) _LANG_FLAG="🇸🇦"; _LANG_NAME="العربية" ;;
  *)  _LANG_FLAG="";  _LANG_NAME="" ;;
esac

if [ -n "$_LANG_NAME" ]; then
  print_section "$_LANG_NAME detected"
  ui_print ""
  ui_print "  ⬆️ Vol UP   = Use $_LANG_NAME"
  ui_print "  ⬇️ Vol DOWN = Keep English 🇬🇧"
  ui_print "  ⏱️ ${TIMEOUT}s timeout → English"
  ui_print ""

  _chosen_lang="en"
  if [ "$HAS_GETEVENT" -eq 0 ]; then
    ui_print "  → English (auto - no getevent)"
  else
    while :; do
      _ev=$(timeout "$TIMEOUT" getevent -qlc 1 2>/dev/null)
      _ec=$?
      if [ "$_ec" -eq 124 ] || [ "$_ec" -eq 143 ]; then
        ui_print "  → 🇬🇧 English (timeout)"
        _chosen_lang="en"
        break
      fi
      if echo "$_ev" | grep -q "KEY_VOLUMEUP.*DOWN"; then
        ui_print "  → $_LANG_FLAG $_LANG_NAME ✅"
        _chosen_lang="$_LANG"
        break
      fi
      if echo "$_ev" | grep -q "KEY_VOLUMEDOWN.*DOWN"; then
        ui_print "  → 🇬🇧 English ✅"
        _chosen_lang="en"
        break
      fi
    done
  fi
  INSTALL_LANG="$_chosen_lang"
fi

s() {
  local key="$1"
  case "${INSTALL_LANG}:${key}" in

    fr:cfg_detected)  echo "Configuration existante detectee !" ;;
    de:cfg_detected)  echo "Bestehende Konfiguration erkannt!" ;;
    pl:cfg_detected)  echo "Wykryto istniejaca konfiguracje!" ;;
    it:cfg_detected)  echo "Configurazione esistente rilevata!" ;;
    es:cfg_detected)  echo "Configuracion existente detectada!" ;;
    pt:cfg_detected)  echo "Configuracao existente detectada!" ;;
    tr:cfg_detected)  echo "Mevcut yapilandirma tespit edildi!" ;;
    id:cfg_detected)  echo "Konfigurasi saat ini terdeteksi!" ;;
    ru:cfg_detected)  echo "Obnaruzhena sushchestvuyushchaya konfiguraciya!" ;;
    uk:cfg_detected)  echo "Vyyavleno nayavnu konfiguraciyu!" ;;
    zh:cfg_detected)  echo "Existing configuration detected!" ;;
    ja:cfg_detected)  echo "Existing configuration detected!" ;;
    ar:cfg_detected)  echo "Existing configuration detected!" ;;
     *:cfg_detected)  echo "Existing configuration detected!" ;;

    fr:cfg_vol_keep)  echo "  ⬆️ Vol HAUT   = Garder config & whitelist" ;;
    de:cfg_vol_keep)  echo "  ⬆️ Vol HOCH   = Konfig & Whitelist behalten" ;;
    pl:cfg_vol_keep)  echo "  ⬆️ Vol GORA   = Zachowaj config i whiteliste" ;;
    it:cfg_vol_keep)  echo "  ⬆️ Vol SU     = Mantieni config & whitelist" ;;
    es:cfg_vol_keep)  echo "  ⬆️ Vol ARRIBA = Mantener config y whitelist" ;;
    pt:cfg_vol_keep)  echo "  ⬆️ Vol CIMA   = Manter config e whitelist" ;;
    tr:cfg_vol_keep)  echo "  ⬆️ Ses YUKARI = Ayarlari ve Whitelist'i koru" ;;
    id:cfg_vol_keep)  echo "  ⬆️ Vol ATAS   = Simpan config & whitelist" ;;
    ru:cfg_vol_keep)  echo "  ⬆️ Grom +     = Ostavit' konfig i Whitelist" ;;
    uk:cfg_vol_keep)  echo "  ⬆️ Guchn. +   = Zberegty konfig ta Whitelist" ;;
    zh:cfg_vol_keep)  echo "  ⬆️ Vol UP     = Keep existing config & whitelist" ;;
    ja:cfg_vol_keep)  echo "  ⬆️ Vol UP     = Keep existing config & whitelist" ;;
    ar:cfg_vol_keep)  echo "  ⬆️ Vol UP     = Keep existing config & whitelist" ;;
     *:cfg_vol_keep)  echo "  ⬆️ Vol UP     = Keep existing config & whitelist" ;;

    fr:cfg_vol_reset) echo "  ⬇️ Vol BAS    = Reinit. (tout desactive)" ;;
    de:cfg_vol_reset) echo "  ⬇️ Vol RUNTER = Zurucksetzen (alles aus)" ;;
    pl:cfg_vol_reset) echo "  ⬇️ Vol DOL    = Resetuj (wszystko wyl.)" ;;
    it:cfg_vol_reset) echo "  ⬇️ Vol GIU    = Ripristina (tutto off)" ;;
    es:cfg_vol_reset) echo "  ⬇️ Vol ABAJO  = Restablecer (todo off)" ;;
    pt:cfg_vol_reset) echo "  ⬇️ Vol BAIXO  = Redefinir (tudo off)" ;;
    tr:cfg_vol_reset) echo "  ⬇️ Ses ASAGI  = Sifirla (her sey kapali)" ;;
    id:cfg_vol_reset) echo "  ⬇️ Vol BAWAH  = Reset (semua nonaktif)" ;;
    ru:cfg_vol_reset) echo "  ⬇️ Grom -     = Sbros (vsyo otklyucheno)" ;;
    uk:cfg_vol_reset) echo "  ⬇️ Guchn. -   = Skydannya (vse vymkneno)" ;;
    zh:cfg_vol_reset) echo "  ⬇️ Vol DOWN   = Reset to defaults (everything off)" ;;
    ja:cfg_vol_reset) echo "  ⬇️ Vol DOWN   = Reset to defaults (everything off)" ;;
    ar:cfg_vol_reset) echo "  ⬇️ Vol DOWN   = Reset to defaults (everything off)" ;;
     *:cfg_vol_reset) echo "  ⬇️ Vol DOWN   = Reset to defaults (everything off)" ;;

    fr:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → conserve la configuration" ;;
    de:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → behalt Konfiguration" ;;
    pl:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → zachowuje konfiguracje" ;;
    it:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → mantiene configurazione" ;;
    es:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → conserva la configuracion" ;;
    pt:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → mantem a configuracao" ;;
    tr:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → mevcut ayarlari korur" ;;
    id:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → pertahankan konfigurasi" ;;
    ru:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → sohranyaet konfiguraciyu" ;;
    uk:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s → zberigae konfiguraciyu" ;;
    zh:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s timeout → keeps existing" ;;
    ja:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s timeout → keeps existing" ;;
    ar:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s timeout → keeps existing" ;;
     *:cfg_timeout)   echo "  ⏱️ ${TIMEOUT}s timeout → keeps existing" ;;

    fr:cfg_kept)      echo "  → Configuration existante conservee ✅" ;;
    de:cfg_kept)      echo "  → Bestehende Konfiguration beibehalten ✅" ;;
    pl:cfg_kept)      echo "  → Istniejaca konfiguracja zachowana ✅" ;;
    it:cfg_kept)      echo "  → Configurazione esistente mantenuta ✅" ;;
    es:cfg_kept)      echo "  → Configuracion existente conservada ✅" ;;
    pt:cfg_kept)      echo "  → Configuracao existente mantida ✅" ;;
    tr:cfg_kept)      echo "  → Mevcut yapilandirma korundu ✅" ;;
    id:cfg_kept)      echo "  → Konfigurasi saat ini dipertahankan ✅" ;;
    ru:cfg_kept)      echo "  → Tekushchaya konfiguraciya sohranena ✅" ;;
    uk:cfg_kept)      echo "  → Potochna konfiguraciya zberezhena ✅" ;;
    zh:cfg_kept)      echo "  → Keeping existing config ✅" ;;
    ja:cfg_kept)      echo "  → Keeping existing config ✅" ;;
    ar:cfg_kept)      echo "  → Keeping existing config ✅" ;;
     *:cfg_kept)      echo "  → Keeping existing config ✅" ;;

    fr:cfg_reset)     echo "  → Reinitialisation aux valeurs par defaut" ;;
    de:cfg_reset)     echo "  → Auf Standardwerte zuruckgesetzt" ;;
    pl:cfg_reset)     echo "  → Zresetowano do ustawien domyslnych" ;;
    it:cfg_reset)     echo "  → Ripristinato ai valori predefiniti" ;;
    es:cfg_reset)     echo "  → Restableciendo valores por defecto" ;;
    pt:cfg_reset)     echo "  → Redefinindo para os padroes" ;;
    tr:cfg_reset)     echo "  → Varsayilan ayarlara sifirlandi" ;;
    id:cfg_reset)     echo "  → Mengembalikan ke default" ;;
    ru:cfg_reset)     echo "  → Sbros do nastroek po umolchaniyu" ;;
    uk:cfg_reset)     echo "  → Skydannya do typovyh nalashtuvan'" ;;
    zh:cfg_reset)     echo "  → Resetting to defaults" ;;
    ja:cfg_reset)     echo "  → Resetting to defaults" ;;
    ar:cfg_reset)     echo "  → Resetting to defaults" ;;
     *:cfg_reset)     echo "  → Resetting to defaults" ;;

    fr:save_title)    echo "Sauvegarde de la Configuration" ;;
    de:save_title)    echo "Konfiguration speichern" ;;
    pl:save_title)    echo "Zapisywanie konfiguracji" ;;
    it:save_title)    echo "Salvataggio configurazione" ;;
    es:save_title)    echo "Guardando Configuracion" ;;
    pt:save_title)    echo "Salvando Configuracao" ;;
    tr:save_title)    echo "Yapilandirma Kaydediliyor" ;;
    id:save_title)    echo "Menyimpan Konfigurasi" ;;
    ru:save_title)    echo "Sohranenie konfiguracii" ;;
    uk:save_title)    echo "Zberezhennya konfiguracii" ;;
    zh:save_title)    echo "Saving Configuration" ;;
    ja:save_title)    echo "Saving Configuration" ;;
    ar:save_title)    echo "Saving Configuration" ;;
     *:save_title)    echo "Saving Configuration" ;;

    fr:save_kept)     echo "  ✓ Configuration existante conservee" ;;
    de:save_kept)     echo "  ✓ Bestehende Konfiguration beibehalten" ;;
    pl:save_kept)     echo "  ✓ Istniejaca konfiguracja zachowana" ;;
    it:save_kept)     echo "  ✓ Configurazione esistente mantenuta" ;;
    es:save_kept)     echo "  ✓ Configuracion existente conservada" ;;
    pt:save_kept)     echo "  ✓ Configuracao existente mantida" ;;
    tr:save_kept)     echo "  ✓ Mevcut yapilandirma korundu" ;;
    id:save_kept)     echo "  ✓ Konfigurasi yang ada dipertahankan" ;;
    ru:save_kept)     echo "  ✓ Sushchestvuyushchaya konfiguraciya sohranena" ;;
    uk:save_kept)     echo "  ✓ Nayavnu konfiguraciyu zberezheno" ;;
    zh:save_kept)     echo "  ✓ Existing configuration kept" ;;
    ja:save_kept)     echo "  ✓ Existing configuration kept" ;;
    ar:save_kept)     echo "  ✓ Existing configuration kept" ;;
     *:save_kept)     echo "  ✓ Existing configuration kept" ;;

    fr:save_wl)       echo "  ↩ Whitelist Doze preservee" ;;
    de:save_wl)       echo "  ↩ Doze-Whitelist beibehalten" ;;
    pl:save_wl)       echo "  ↩ Biala lista Doze zachowana" ;;
    it:save_wl)       echo "  ↩ Whitelist Doze preservata" ;;
    es:save_wl)       echo "  ↩ Lista blanca Doze preservada" ;;
    pt:save_wl)       echo "  ↩ Lista branca Doze preservada" ;;
    tr:save_wl)       echo "  ↩ Doze beyaz listesi korundu" ;;
    id:save_wl)       echo "  ↩ Daftar putih Doze dipertahankan" ;;
    ru:save_wl)       echo "  ↩ Belyj spisok Doze sohranyeon" ;;
    uk:save_wl)       echo "  ↩ Bilyj spysok Doze zberezheno" ;;
    zh:save_wl)       echo "  ↩ Doze whitelist preserved" ;;
    ja:save_wl)       echo "  ↩ Doze whitelist preserved" ;;
    ar:save_wl)       echo "  ↩ Doze whitelist preserved" ;;
     *:save_wl)       echo "  ↩ Doze whitelist preserved" ;;

    fr:save_default)  echo "  ✓ Config par defaut appliquee (tout desactive)" ;;
    de:save_default)  echo "  ✓ Standardkonfiguration angewendet (alles aus)" ;;
    pl:save_default)  echo "  ✓ Konfiguracja domyslna (wszystko wylaczone)" ;;
    it:save_default)  echo "  ✓ Config predefinita applicata (tutto off)" ;;
    es:save_default)  echo "  ✓ Configuracion por defecto (todo desactivado)" ;;
    pt:save_default)  echo "  ✓ Configuracao padrao aplicada (tudo off)" ;;
    tr:save_default)  echo "  ✓ Varsayilan yapilandirma uygulandi (hepsi kapali)" ;;
    id:save_default)  echo "  ✓ Konfigurasi default diterapkan (semua nonaktif)" ;;
    ru:save_default)  echo "  ✓ Primenena konfiguraciya po umolchaniyu (vsyo vykl.)" ;;
    uk:save_default)  echo "  ✓ Zastosovano typovu konfiguraciyu (vse vymk.)" ;;
    zh:save_default)  echo "  ✓ Default config applied (everything off)" ;;
    ja:save_default)  echo "  ✓ Default config applied (everything off)" ;;
    ar:save_default)  echo "  ✓ Default config applied (everything off)" ;;
     *:save_default)  echo "  ✓ Default config applied (everything off)" ;;

    fr:done_title)    echo "Installation Terminee" ;;
    de:done_title)    echo "Installation Abgeschlossen" ;;
    pl:done_title)    echo "Instalacja Zakonczona" ;;
    it:done_title)    echo "Installazione Completata" ;;
    es:done_title)    echo "Instalacion Completada" ;;
    pt:done_title)    echo "Instalacao Concluida" ;;
    tr:done_title)    echo "Kurulum Tamamlandi" ;;
    id:done_title)    echo "Instalasi Selesai" ;;
    ru:done_title)    echo "Ustanovka Zavershena" ;;
    uk:done_title)    echo "Vstanovlennya Zaversheno" ;;
    zh:done_title)    echo "Installation Complete" ;;
    ja:done_title)    echo "Installation Complete" ;;
    ar:done_title)    echo "Installation Complete" ;;
     *:done_title)    echo "Installation Complete" ;;

    fr:done_reboot)   echo "  > Redemarrez votre appareil" ;;
    de:done_reboot)   echo "  > Gerat neu starten" ;;
    pl:done_reboot)   echo "  > Uruchom ponownie urzadzenie" ;;
    it:done_reboot)   echo "  > Riavvia il dispositivo" ;;
    es:done_reboot)   echo "  > Reinicia tu dispositivo" ;;
    pt:done_reboot)   echo "  > Reinicie seu dispositivo" ;;
    tr:done_reboot)   echo "  > Cihazi yeniden baslat" ;;
    id:done_reboot)   echo "  > Restart perangkat Anda" ;;
    ru:done_reboot)   echo "  > Perezagruzite ustrojstvo" ;;
    uk:done_reboot)   echo "  > Perezavantazhte pristrij" ;;
    zh:done_reboot)   echo "  > Reboot your device" ;;
    ja:done_reboot)   echo "  > Reboot your device" ;;
    ar:done_reboot)   echo "  > Reboot your device" ;;
     *:done_reboot)   echo "  > Reboot your device" ;;

    fr:done_webui)    echo "  > Ouvrez la WebUI pour activer les fonctionnalites" ;;
    de:done_webui)    echo "  > Offne die WebUI, um Funktionen zu aktivieren" ;;
    pl:done_webui)    echo "  > Otworz WebUI, aby aktywowac funkcje" ;;
    it:done_webui)    echo "  > Apri la WebUI per abilitare le funzionalita" ;;
    es:done_webui)    echo "  > Abre la WebUI para activar las funciones" ;;
    pt:done_webui)    echo "  > Abra a WebUI para ativar os recursos" ;;
    tr:done_webui)    echo "  > Ozellikleri acmak icin WebUI'yi kullanin" ;;
    id:done_webui)    echo "  > Buka WebUI untuk mengaktifkan fitur" ;;
    ru:done_webui)    echo "  > Otkrojte WebUI dlya vklyucheniya funkcij" ;;
    uk:done_webui)    echo "  > Vidkryjte WebUI dlya uvimknennya funkcij" ;;
    zh:done_webui)    echo "  > Open WebUI to enable features" ;;
    ja:done_webui)    echo "  > Open WebUI to enable features" ;;
    ar:done_webui)    echo "  > Open WebUI to enable features" ;;
     *:done_webui)    echo "  > Open WebUI to enable features" ;;

    fr:done_off)      echo "    (tout commence DESACTIVE par defaut)" ;;
    de:done_off)      echo "    (alles startet DEAKTIVIERT)" ;;
    pl:done_off)      echo "    (domyslnie wszystko jest WYLACZONE)" ;;
    it:done_off)      echo "    (tutto parte DISATTIVATO di default)" ;;
    es:done_off)      echo "    (todo comienza DESACTIVADO por defecto)" ;;
    pt:done_off)      echo "    (tudo comeca DESATIVADO por padrao)" ;;
    tr:done_off)      echo "    (varsayilan olarak her sey KAPALI baslar)" ;;
    id:done_off)      echo "    (semuanya DINONAKTIFKAN secara default)" ;;
    ru:done_off)      echo "    (po umolchaniyu vsyo OTKLYUCHENO)" ;;
    uk:done_off)      echo "    (za zamovchuvannyam use VYMKNENO)" ;;
    zh:done_off)      echo "    (everything starts OFF by default)" ;;
    ja:done_off)      echo "    (everything starts OFF by default)" ;;
    ar:done_off)      echo "    (everything starts OFF by default)" ;;
     *:done_off)      echo "    (everything starts OFF by default)" ;;

    fr:done_logs)     echo "  > Journaux : /data/adb/modules/Frosty/logs/" ;;
    de:done_logs)     echo "  > Logs: /data/adb/modules/Frosty/logs/" ;;
    pl:done_logs)     echo "  > Logi: /data/adb/modules/Frosty/logs/" ;;
    it:done_logs)     echo "  > Log: /data/adb/modules/Frosty/logs/" ;;
    es:done_logs)     echo "  > Registros: /data/adb/modules/Frosty/logs/" ;;
    pt:done_logs)     echo "  > Logs: /data/adb/modules/Frosty/logs/" ;;
    tr:done_logs)     echo "  > Gunlukler: /data/adb/modules/Frosty/logs/" ;;
    id:done_logs)     echo "  > Log: /data/adb/modules/Frosty/logs/" ;;
    ru:done_logs)     echo "  > Logi: /data/adb/modules/Frosty/logs/" ;;
    uk:done_logs)     echo "  > Logy: /data/adb/modules/Frosty/logs/" ;;
    zh:done_logs)     echo "  > Logs: /data/adb/modules/Frosty/logs/" ;;
    ja:done_logs)     echo "  > Logs: /data/adb/modules/Frosty/logs/" ;;
    ar:done_logs)     echo "  > Logs: /data/adb/modules/Frosty/logs/" ;;
     *:done_logs)     echo "  > Logs: /data/adb/modules/Frosty/logs/" ;;

    fr:stay_frosty)   echo "Stay Frosty!" ;;
    de:stay_frosty)   echo "Stay Frosty!" ;;
    pl:stay_frosty)   echo "Stay Frosty!" ;;
    it:stay_frosty)   echo "Stay Frosty!" ;;
    es:stay_frosty)   echo "Stay Frosty!" ;;
    pt:stay_frosty)   echo "Stay Frosty!" ;;
    tr:stay_frosty)   echo "Stay Frosty!" ;;
    id:stay_frosty)   echo "Stay Frosty!" ;;
    ru:stay_frosty)   echo "Stay Frosty!" ;;
    uk:stay_frosty)   echo "Stay Frosty!" ;;
    zh:stay_frosty)   echo "Stay Frosty!" ;;
    ja:stay_frosty)   echo "Stay Frosty!" ;;
    ar:stay_frosty)   echo "Stay Frosty!" ;;
     *:stay_frosty)   echo "Stay Frosty!" ;;

  esac
}

# Existing config detection
EXISTING_PREFS="/data/adb/modules/$MODID/config/user_prefs"
EXISTING_WHITELIST="/data/adb/modules/$MODID/config/doze_whitelist.txt"
USE_EXISTING=0

if [ -f "$EXISTING_PREFS" ]; then
  print_section "$(s cfg_detected)"
  ui_print ""
  ui_print "$(s cfg_vol_keep)"
  ui_print "$(s cfg_vol_reset)"
  ui_print "$(s cfg_timeout)"
  ui_print ""

  if [ "$HAS_GETEVENT" -eq 0 ]; then
    ui_print "$(s cfg_kept) (auto - no getevent)"
    USE_EXISTING=1
  else
    while :; do
      event=$(timeout "$TIMEOUT" getevent -qlc 1 2>/dev/null)
      code=$?
      if [ "$code" -eq 124 ] || [ "$code" -eq 143 ]; then
        ui_print "$(s cfg_kept) (timeout)"
        USE_EXISTING=1
        break
      fi
      if echo "$event" | grep -q "KEY_VOLUMEUP.*DOWN"; then
        ui_print "$(s cfg_kept)"
        USE_EXISTING=1
        break
      fi
      if echo "$event" | grep -q "KEY_VOLUMEDOWN.*DOWN"; then
        ui_print "$(s cfg_reset)"
        USE_EXISTING=0
        break
      fi
    done
  fi
fi

# Save Configuration
print_section "$(s save_title)"
mkdir -p "$MODPATH/config"

if [ "$USE_EXISTING" -eq 1 ]; then
  cp -f "$EXISTING_PREFS" "$MODPATH/config/user_prefs"
  ui_print ""
  ui_print "$(s save_kept)"
  if [ -f "$EXISTING_WHITELIST" ]; then
    cp -f "$EXISTING_WHITELIST" "$MODPATH/config/doze_whitelist.txt"
    ui_print "$(s save_wl)"
  fi
  . "$MODPATH/config/user_prefs"
  SYSPROP="$MODPATH/system.prop"
  SYSPROP_OLD="$MODPATH/system.prop.old"
  if [ "${ENABLE_SYSTEM_PROPS:-0}" -eq 1 ]; then
    [ -f "$SYSPROP_OLD" ] && mv "$SYSPROP_OLD" "$SYSPROP"
  else
    [ -f "$SYSPROP" ] && mv "$SYSPROP" "$SYSPROP_OLD"
  fi
else
  ui_print ""
  ui_print "$(s save_default)"
  SYSPROP="$MODPATH/system.prop"
  SYSPROP_OLD="$MODPATH/system.prop.old"
  [ -f "$SYSPROP" ] && mv "$SYSPROP" "$SYSPROP_OLD"
fi

print_section "$(s done_title)"
ui_print ""
ui_print "$(s done_reboot)"
ui_print "$(s done_webui)"
ui_print "$(s done_off)"
ui_print "$(s done_logs)"
ui_print ""
print_section "$(s stay_frosty)"
ui_print ""

rm -rf "$MODPATH/README.md" "$MODPATH/readme" "$MODPATH/LICENSE" \
  "$MODPATH/CHANGELOG.md" "$MODPATH/update.json" "$MODPATH"/.git*
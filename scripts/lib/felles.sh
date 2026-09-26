# Felles hjelpefunksjoner for skriptene. Kildes, kjøres ikke:
#   . "$(dirname "$0")/lib/felles.sh"
# shellcheck shell=bash

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_KLAR_SEK=150   # configen er først komplett ca. 150 s etter oppstart

ok()   { printf '  [OK]    %s\n' "$*"; }
info() { printf '  [INFO]  %s\n' "$*"; }
# shellcheck disable=SC2034  # fail leses av skriptet som kilder denne filen
bad()  { printf '  [%s]  %s\n' "${BAD_TAG:-FEIL}" "$*"; fail=1; }

# config_verdi <nøkkel> [standard]: verdi fra zyxel_nr7302.yml med zyxel_nr7302.local.yml
# lagt oppå. Manglende/null verdi gir standardverdien.
config_verdi() {
  local v
  v="$(python3 "$BASE/scripts/lib/config-verdi.py" "$1" 2>/dev/null)" || v=""
  printf '%s\n' "${v:-${2:-}}"
}

# finn_iface: IFACE fra miljøet, ellers pc.nettverkskort i yml, ellers første kablede kort.
finn_iface() {
  local i="${IFACE:-$(config_verdi pc.nettverkskort auto)}"
  if [[ "$i" == auto ]]; then
    i="$(nmcli -t -f DEVICE,TYPE device 2>/dev/null \
      | awk -F: '$2=="ethernet" && $1 !~ /^(veth|docker|br-|virbr)/ {print $1; exit}')"
  fi
  printf '%s\n' "$i"
}

# privat_mappe <sti>: mappe bare eieren kan lese (backup inneholder passord og nøkler).
privat_mappe() { (umask 077 && mkdir -p "$1") && chmod 700 "$1"; }

# gi_til_bruker <sti>...: filer laget under sudo skal eies av brukeren som kjørte sudo.
gi_til_bruker() { [[ -n "${SUDO_UID:-}" ]] && chown "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$@" 2>/dev/null; return 0; }

adb_sh() { adb shell "$@" </dev/null | tr -d '\r'; }

# adb_skriv_config <lokal.json>: skriver config til /xdata/zcfg_config.json uten å kunne
# etterlate en halvskrevet fil. Filen legges ved siden av originalen (med samme eier og
# rettigheter), md5 kontrolleres, og så byttes den inn med mv (atomisk).
adb_skriv_config() {
  local f="$1" maal=/xdata/zcfg_config.json ny=/xdata/zcfg_config.json.ny lokal fjern
  python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$f" \
    || { echo "Ugyldig JSON: $f – skriver ikke." >&2; return 1; }
  lokal="$(md5sum "$f" | cut -d' ' -f1)"
  adb push "$f" /tmp/zcfg_ny.json >/dev/null || { echo "adb push feilet." >&2; return 1; }
  adb_sh "cp -p $maal $ny && cat /tmp/zcfg_ny.json > $ny && rm -f /tmp/zcfg_ny.json && sync" >/dev/null || true
  fjern="$(adb_sh "md5sum $ny 2>/dev/null" | cut -d' ' -f1)" || true
  if [[ "$fjern" != "$lokal" ]]; then
    adb_sh "rm -f $ny" >/dev/null || true
    echo "md5 på enheten (${fjern:-ingen}) er ikke lik lokal ($lokal) – config er IKKE endret." >&2
    return 1
  fi
  adb_sh "mv -f $ny $maal && sync && md5sum $maal" | grep -q "^$lokal " \
    || { echo "Kontroll etter bytte feilet – ikke start enheten på nytt før du har sjekket $maal." >&2; return 1; }
}

# adb_omstart_og_vent [maks-sek]: starter enheten på nytt og venter til den er borte, oppe
# igjen og har vært oppe i CONFIG_KLAR_SEK sekunder.
# shellcheck disable=SC2120  # maks-sek er valgfri
adb_omstart_og_vent() {
  local maks="${1:-480}" slutt up borte=0
  adb_sh reboot >/dev/null 2>&1 || true
  for _ in $(seq 60); do
    adb get-state >/dev/null 2>&1 </dev/null || { borte=1; break; }
    sleep 1
  done
  (( borte )) || { echo "Enheten startet ikke på nytt (adb er fortsatt oppe etter 60 s)." >&2; return 1; }
  slutt=$((SECONDS + maks))
  while :; do
    up="$(timeout 5 adb shell 'cut -d. -f1 /proc/uptime' </dev/null 2>/dev/null | tr -d '\r')" || true
    if [[ "$up" =~ ^[0-9]+$ ]]; then
      (( up >= CONFIG_KLAR_SEK )) && return 0
      printf '\r  oppe i %3d s, venter til %d s ...' "$up" "$CONFIG_KLAR_SEK"
    fi
    (( SECONDS >= slutt )) && { echo; echo "Enheten ble ikke klar innen $maks s." >&2; return 1; }
    sleep 5
  done
}

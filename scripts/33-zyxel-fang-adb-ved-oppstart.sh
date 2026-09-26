#!/usr/bin/env bash
# Fase 3/4/7: Venter på at adb dukker opp når NR7302 starter, og leser da status og config.
# Endrer ingenting på enheten.
#
# Med DTAG-firmware (Telekom) er USB/adb bare tilgjengelig i ca. 30 sekunder rett etter
# oppstart; deretter slår firmwaren av USB. Start skriptet, og slå så av og på strømmen
# (PoE) med USB-kabelen tilkoblet.
#
#   ./33-zyxel-fang-adb-ved-oppstart.sh            vent i inntil 15 min
#   ./33-zyxel-fang-adb-ved-oppstart.sh 5          vent i inntil 5 min
#
# Resultat: backup/adb-<tid>/ med zcfg_config.json og modemstatus (git-ignorert).
set -uo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
MIN="${1:-15}"
OUT="$BASE/backup/adb-$(date +%Y%m%d-%H%M%S)"

echo "Venter på adb i inntil $MIN min. Slå av og på strømmen til antennen nå (USB tilkoblet)."
end=$((SECONDS + MIN * 60))
until [[ "$(timeout 3 adb get-state 2>/dev/null)" == device ]]; do
  (( SECONDS >= end )) && { echo "Ingen adb innen $MIN min." >&2; exit 1; }
  sleep 1
done

mkdir -p "$OUT"; chmod 700 "$OUT"
echo "$(date +%T) adb oppe – henter (oppetid $(timeout 5 adb shell 'cut -d" " -f1 /proc/uptime' | tr -d '\r') s)"
timeout 25 adb pull /xdata/zcfg_config.json "$OUT/zcfg_config.json" >/dev/null 2>&1 \
  && chmod 600 "$OUT/zcfg_config.json" && echo "  config -> $OUT/zcfg_config.json" \
  || echo "  kunne ikke hente config (for tidlig i oppstarten?)"
timeout 40 adb shell '
  for c in "AT+CPIN?" "AT+COPS?" "AT+CEREG?" "AT+CGDCONT?" "AT+CGPADDR" "AT+QCFG=\"usbcfg\""; do
    echo ">>> $c"; timeout 4 atcmd "$c" </dev/null 2>&1 | grep "^+"
  done' 2>/dev/null | tr -d '\r' | tee "$OUT/modem.txt"
echo "$(date +%T) ferdig: $OUT"
echo "Tips: 41-zyxel-vis-config.py $OUT/zcfg_config.json"

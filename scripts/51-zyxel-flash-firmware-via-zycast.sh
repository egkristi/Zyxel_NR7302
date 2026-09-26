#!/usr/bin/env bash
# Flash firmware til NR7302 med zycast (multicast), for soft-brick eller cross-flash.
#
#   sudo ./51-zyxel-flash-firmware-via-zycast.sh <firmware.bin> [sekunder-etter-link]
#
# Kjør "sudo ./50-pc-sett-nettverkskort-for-zycast.sh" først. Antennen skal være UTEN strøm når du starter.
# Skriptet venter til kabelen får link (= du har koblet på PoE), teller ned og starter
# zycast. Standard er 50 s: iflg. repo-issue #5 tar Telenor-enheter imot pakker bare i et
# vindu ca. 50–85 s etter strøm på. Virker det ikke, prøv igjen med 55, 60, 65 ...
# zycast startes på nytt automatisk hvis den avslutter med feil. Stopp med Ctrl+C når
# begge LED-ene lyser fast grønt.
set -uo pipefail

IFACE="${IFACE:-$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="ethernet"{print $1; exit}')}"  # første kablede kort, eller IFACE=...
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ZYCAST="$BASE/tools/zycast_flash"
FW="${1:-}"
DELAY="${2:-50}"

[[ $EUID -eq 0 ]] || { echo "Kjør med sudo." >&2; exit 1; }
[[ -f "$FW" ]] || { echo "Finner ikke firmwarefil: '$FW'" >&2; exit 1; }
[[ -x "$ZYCAST" ]] || { echo "Mangler $ZYCAST" >&2; exit 1; }
ip -br addr show "$IFACE" | grep -q "192.168.1.4/24" \
  || { echo "$IFACE har ikke 192.168.1.4/24. Kjør: sudo $BASE/scripts/50-pc-sett-nettverkskort-for-zycast.sh" >&2; exit 1; }

LOG="$BASE/logg/zycast-$(date +%Y%m%d-%H%M%S).log"
echo "Firmware: $FW ($(stat -c %s "$FW") byte, sha256 $(sha256sum "$FW" | cut -c1-16)…)" | tee "$LOG"

if [[ "$(cat /sys/class/net/$IFACE/carrier 2>/dev/null)" == "1" ]]; then
  echo "ADVARSEL: $IFACE har allerede link. Antennen skal være strømløs nå." | tee -a "$LOG"
  echo "Trekk PoE-strømmen, vent 10 s, og trykk Enter (eller Ctrl+C for å avbryte)."
  read -r
fi

echo "Koble på PoE-strøm nå. Venter på link på $IFACE ..."
until [[ "$(cat /sys/class/net/$IFACE/carrier 2>/dev/null)" == "1" ]]; do sleep 0.5; done
echo "$(date +%T) Link oppe. Starter zycast om $DELAY s." | tee -a "$LOG"
for ((i=DELAY; i>0; i--)); do printf '\r  %3d s ' "$i"; sleep 1; done; echo

trap 'echo; echo "$(date +%T) Stoppet av bruker." | tee -a "$LOG"; exit 0' INT
echo "$(date +%T) zycast startet. Forventet: LED-er blinker oransje etter tur, så samtidig; ferdig = fast grønt (1–2 t)." | tee -a "$LOG"
while true; do
  "$ZYCAST" -i "$IFACE" -t 20 -f "$FW" 2>&1 | tee -a "$LOG"
  echo "$(date +%T) zycast avsluttet (link nede?). Starter på nytt om 2 s ..." | tee -a "$LOG"
  sleep 2
done

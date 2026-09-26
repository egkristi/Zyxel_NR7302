#!/usr/bin/env bash
# Fase 7: Måler hastighet og ping gjennom NR7302, med trafikken tvunget ut på det kablede
# nettverkskortet (curl --interface / ping -I). WiFi kan stå på uten å påvirke målingen.
# Endrer ingenting.
#
#   ./71-pc-mal-hastighet-og-ping-via-zyxel.sh          20 s nedlasting + 20 s opplasting
#   SEK=30 ./71-pc-mal-hastighet-og-ping-via-zyxel.sh   lengre måling
#   IFACE=enx... ./71-pc-mal-hastighet-og-ping-via-zyxel.sh
#
# Krever at PC-en har en rute ut via antennen på kablet kort, dvs. DHCP fra antennen
# (80-pc-tilbakestill-nettverkskort.sh). Med fast IP uten gateway (30-…) fungerer det ikke.
set -uo pipefail
export LC_ALL=C
IFACE="${IFACE:-$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="ethernet"{print $1; exit}')}"
SEK="${SEK:-20}"
UA="Mozilla/5.0 (X11; Linux x86_64) Chrome/125"
DL=(https://nbg1-speed.hetzner.com/1GB.bin https://proof.ovh.net/files/1Gb.dat)
UL=https://speed.cloudflare.com/__up
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "== Kort: $IFACE"
[[ "$(cat "/sys/class/net/$IFACE/carrier" 2>/dev/null)" == 1 ]] \
  || { echo "Ingen link på $IFACE – er nettverkskabelen til PoE-injektoren tilkoblet?" >&2; exit 1; }
ip -4 -br addr show "$IFACE"
echo "== Operatør sett fra internett (via $IFACE)"
info="$(curl -s --interface "$IFACE" --max-time 8 https://ipinfo.io/json 2>/dev/null)"
[[ -n "$info" ]] || { echo "Ingen internettforbindelse via $IFACE (fast IP uten gateway? kjør 80-…)." >&2; exit 1; }
grep -E '"org"' <<<"$info" | sed 's/^ */  /'

echo "== Ping uten last (10 s)"
ping -I "$IFACE" -c 20 -i 0.5 1.1.1.1 | tail -2 | sed 's/^/  /'

echo "== Nedlasting ${SEK} s (${#DL[@]} strømmer) med ping samtidig"
( ping -I "$IFACE" -c $((SEK * 2)) -i 0.5 1.1.1.1 > "$tmp/pdl" ) &
for u in "${DL[@]}"; do
  ( curl -sL --interface "$IFACE" -A "$UA" -o /dev/null --max-time "$SEK" \
      -w '%{speed_download} %{size_download}\n' "$u" >> "$tmp/dl" ) &
done
wait
awk '{s+=$1; b+=$2} END {printf "  %.1f Mbit/s (%.0f MB)\n", s*8/1e6, b/1e6}' "$tmp/dl"
tail -1 "$tmp/pdl" | sed 's/^/  ping under last: /'

echo "== Opplasting ${SEK} s med ping samtidig"
( ping -I "$IFACE" -c $((SEK * 2)) -i 0.5 1.1.1.1 > "$tmp/pul" ) &
head -c 200000000 /dev/urandom | curl -s --interface "$IFACE" -A "$UA" -o /dev/null \
  --max-time "$SEK" -X POST --data-binary @- -w '%{speed_upload}\n' "$UL" \
  | awk '{printf "  %.1f Mbit/s\n", $1*8/1e6}'
wait
tail -1 "$tmp/pul" | sed 's/^/  ping under last: /'
echo
echo "Ping-linjene: min/snitt/maks/avvik i ms. Stor økning under last = bufferbloat (se docs)."

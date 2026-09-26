#!/usr/bin/env bash
# Fase 2: Laster ned zycast.c fra OpenWrt firmware-utils (GPL-2.0) og kompilerer
# tools/zycast_flash. Trengs bare for flashing/redning (fase 5 og 9).
#   ./21-pc-bygg-zycast.sh
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
URL="https://github.com/openwrt/firmware-utils/raw/refs/heads/master/src/zycast.c"
mkdir -p "$BASE/tools"
cd "$BASE/tools"
command -v gcc >/dev/null || { echo "Mangler gcc: sudo apt install build-essential" >&2; exit 1; }
echo "== Laster ned $URL"
curl -fsSL -o zycast.c "$URL"
echo "== Kompilerer"
gcc -O2 -Wall zycast.c -o zycast_flash
chmod +x zycast_flash
usage="$(./zycast_flash 2>&1 || true)"   # viser bruksanvisning og avslutter med feilkode
if grep -q -- '-i interface' <<<"$usage"; then
  echo "OK: tools/zycast_flash (zycast.c sha256 $(sha256sum zycast.c | cut -c1-16)…)"
else
  echo "FEIL: tools/zycast_flash kjører ikke som forventet" >&2; exit 1
fi

#!/usr/bin/env bash
# Skriver en config-fil til enheten over adb (atomisk, md5-kontrollert), starter på nytt og
# venter til configen er klar.
#   ./90-zyxel-gjenopprett-config-fra-backup.sh <sti-til-zcfg_config.json>
set -euo pipefail
. "$(dirname "$0")/lib/felles.sh"
F="${1:-}"
[[ -f "$F" ]] || { echo "Bruk: $0 <backup zcfg_config.json>" >&2; exit 1; }
adb wait-for-device
echo "== Skriver $F til enheten"
adb_skriv_config "$F"
echo "== Starter på nytt og venter til configen er klar (ca. 3 min)"
adb_omstart_og_vent; echo
echo "Ferdig: enheten kjører med configen fra $F."
echo "Sjekk med: $BASE/scripts/70-zyxel-verifiser-config-og-innlogging.sh"

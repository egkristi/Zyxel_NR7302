#!/usr/bin/env bash
# Setter APN og slår av operatørens fjernstyring på NR7302, over adb. Tar backup først.
# Hva som slås av styres av fjernstyring.* og administrasjon.wan_admin_i_passthrough i yml.
#
#   ./62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh <APN>      f.eks. ice.net eller telia
#   ./62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh            bruker mobil.apn fra zyxel_nr7302(.local).yml
#
# APN-profilene som endres er mobil.apn_profiler i yml (standard 0,1 som i Telenor-oppsettet).
# Endringene er beskrevet i lib/lag-apn-og-fjernstyring-config.py. Angre med:
#   ./90-zyxel-gjenopprett-config-fra-backup.sh backup/apn-<tid>/zcfg_config.FØR.json
set -euo pipefail
. "$(dirname "$0")/lib/felles.sh"

APN="${1:-$(config_verdi mobil.apn)}"
PROFILER="$(config_verdi mobil.apn_profiler 0,1)"
[[ -n "$APN" ]] || { echo "Oppgi operatørens APN: $0 <APN>  (eller sett mobil.apn i zyxel_nr7302.local.yml)" >&2; exit 1; }
at() { adb_sh "timeout 8 atcmd '$1' </dev/null 2>&1" | grep -v '^$' || true; }

adb wait-for-device
BK="$BASE/backup/apn-$(date +%Y%m%d-%H%M%S)"; privat_mappe "$BK"
echo "== Backup -> $BK"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.FØR.json" >/dev/null

echo "== Lager ny config (APN=$APN på profil $PROFILER)"
"$BASE/scripts/lib/lag-apn-og-fjernstyring-config.py" "$BK/zcfg_config.FØR.json" "$BK/zcfg_config.NY.json" \
  --apn "$APN" --profiler "$PROFILER" | tee "$BK/endringer.txt"
chmod 600 "$BK"/*

echo "== Skriver til enheten"
adb_skriv_config "$BK/zcfg_config.NY.json"
echo "== Starter på nytt og venter til configen er klar (ca. 3 min)"
adb_omstart_og_vent; echo

echo "== Verifiserer"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.ETTER.json" >/dev/null
chmod 600 "$BK/zcfg_config.ETTER.json"
# Alle verdier som ble endret skal ha overlevd omstarten.
python3 - "$BASE/scripts/lib" "$BK/zcfg_config.FØR.json" "$BK/zcfg_config.NY.json" "$BK/zcfg_config.ETTER.json" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import zcfg
før, ny, etter = (zcfg.load(p) for p in sys.argv[2:5])
etter_flat = dict(zcfg.flat(etter))
feil = 0
for sti, _, verdi in zcfg.changes(før, ny):
    har = etter_flat.get(sti)
    if har == verdi:
        print(f"  [OK]   {sti} = {str(verdi)[:40]!r}")
    elif sti.endswith("SshKeyBaseAuthPublicKey"):
        # Legges inn på nytt fra factory ved hver oppstart på Telenor-enheter. Uskadelig så
        # lenge SSH bare er åpen på LAN og WAN-administrasjon er av.
        print(f"  [INFO] {sti}: operatørens SSH-nøkkel er lagt inn på nytt fra factory")
    else:
        print(f"  [FEIL] {sti}: forventet {str(verdi)[:40]!r}, enheten har {str(har)[:40]!r}")
        feil = 1
sys.exit(feil)
PY
echo "  -- Modem:"
at 'AT+COPS?'; at 'AT+CGDCONT?' | grep -E 'CGDCONT: [12],' || true; at 'AT+CGPADDR=1,2'
echo "  -- Kjørende fjernstyringsprosesser (skal være tomt):"
adb_sh 'ps | grep -iE "mqtt|usp|obuspa|cwmp|tr069" | grep -v grep' || true
echo "  -- authorized_keys for root:"
adb_sh 'cat /home/root/.ssh/authorized_keys 2>/dev/null || echo "(ingen)"'
echo "  -- Internett fra enheten:"
adb_sh 'ping -c 3 -W 3 1.1.1.1 2>&1 | tail -2'
echo
echo "Ferdig. Backup: $BK/zcfg_config.FØR.json"

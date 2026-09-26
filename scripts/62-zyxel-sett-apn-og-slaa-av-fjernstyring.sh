#!/usr/bin/env bash
# Setter APN og slår av all operatør-fjernstyring på NR7302, over adb. Tar backup først.
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
python3 - "$BK/zcfg_config.ETTER.json" "$APN" "$PROFILER" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); apn = sys.argv[2]
prof = [int(x) for x in sys.argv[3].split(",")]
ok = True
def chk(label, cond):
    global ok
    print(f"  [{'OK' if cond else 'FEIL'}] {label}"); ok &= cond
aps = d["Cellular"]["AccessPoint"]
chk(f"APN {','.join(map(str, prof))} = {apn}", all(aps[i]["APN"] == apn for i in prof))
chk("CWMP av og ACS-URL tom", not d["ManagementServer"]["EnableCWMP"] and not d["ManagementServer"]["URL"])
chk("USP-kontroller av", not any(c["Enable"] for c in d.get("LocalAgent", {}).get("Controller", [])))
chk("MQTT-klienter av", not any(c["Enable"] for c in d.get("MQTT", {}).get("Client", [])))
if any(a.get("SshKeyBaseAuthPublicKey") for g in d["X_ZYXEL_LoginCfg"]["LogGp"] for a in g["Account"]):
    # Legges inn på nytt fra factory-partisjonen ved hver oppstart. Uskadelig så lenge SSH er
    # LAN_ONLY og WAN-administrasjon er av (operatøren når ikke enheten over et annet nett).
    print("  [INFO] Operatørens SSH-nøkkel for root er lagt inn på nytt fra factory (SSH er kun LAN)")
chk("WAN-administrasjon (passthrough) av",
    not any(s["Enable"] for s in d.get("X_ZYXEL_RemoteManagement_IP_PassThrough", {}).get("Service", [])))
sys.exit(0 if ok else 1)
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

#!/usr/bin/env bash
# Setter APN og slår av all Telenor-fjernstyring på NR7302, over adb. Tar backup først.
#
#   ./62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh [APN]        (standard APN: ice.net)
#
# Endringene er beskrevet i lib/lag-apn-og-fjernstyring-config.py. Angre med:
#   ./90-zyxel-gjenopprett-config-fra-backup.sh backup/ice-<tid>/zcfg_config.FØR.json
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
APN="${1:-ice.net}"
at() { adb shell "timeout 8 atcmd '$1' </dev/null 2>&1" | tr -d '\r' | grep -v '^$'; }

adb wait-for-device
BK="$BASE/backup/ice-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BK"
echo "== Backup -> $BK"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.FØR.json" >/dev/null

echo "== Lager ny config (APN=$APN)"
"$BASE/scripts/lib/lag-apn-og-fjernstyring-config.py" "$BK/zcfg_config.FØR.json" "$BK/zcfg_config.NY.json" --apn "$APN" \
  | tee "$BK/endringer.txt"

echo "== Skriver til enheten og starter på nytt"
adb push "$BK/zcfg_config.NY.json" /tmp/zcfg_new.json >/dev/null
adb shell 'cat /tmp/zcfg_new.json > /xdata/zcfg_config.json && sync'
adb shell reboot >/dev/null 2>&1 || true
echo "== Venter på enheten (ca. 3 min)"
sleep 25; timeout 220 adb wait-for-device; sleep 150

echo "== Verifiserer"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.ETTER.json" >/dev/null
python3 - "$BK/zcfg_config.ETTER.json" "$APN" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); apn = sys.argv[2]
ok = True
def chk(label, cond):
    global ok
    print(f"  [{'OK' if cond else 'FEIL'}] {label}"); ok &= cond
chk(f"APN 0/1 = {apn}", all(d["Cellular"]["AccessPoint"][i]["APN"] == apn for i in (0, 1)))
chk("CWMP av og ACS-URL tom", not d["ManagementServer"]["EnableCWMP"] and not d["ManagementServer"]["URL"])
chk("USP-kontroller av", not any(c["Enable"] for c in d["LocalAgent"]["Controller"]))
chk("MQTT-klienter av", not any(c["Enable"] for c in d["MQTT"]["Client"]))
if any(a.get("SshKeyBaseAuthPublicKey") for g in d["X_ZYXEL_LoginCfg"]["LogGp"] for a in g["Account"]):
    # Legges inn på nytt fra factory-partisjonen ved hver oppstart. Uskadelig så lenge SSH er
    # LAN_ONLY og WAN-administrasjon er av (Telenor når ikke enheten over Ice).
    print("  [INFO] Telenors SSH-nøkkel for root er lagt inn på nytt fra factory (SSH er kun LAN)")
chk("WAN-administrasjon (passthrough) av", not any(s["Enable"] for s in d["X_ZYXEL_RemoteManagement_IP_PassThrough"]["Service"]))
sys.exit(0 if ok else 1)
PY
echo "  -- Modem:"
at 'AT+COPS?'; at 'AT+CGDCONT?' | grep -E 'CGDCONT: [12],'; at 'AT+CGPADDR=1,2'
echo "  -- Kjørende Telenor-prosesser (skal være tomt):"
adb shell 'ps | grep -iE "mqtt|usp|obuspa|cwmp|tr069" | grep -v grep' | tr -d '\r' || true
echo "  -- authorized_keys for root:"
adb shell 'cat /home/root/.ssh/authorized_keys 2>/dev/null || echo "(ingen)"' | tr -d '\r'
echo "  -- Internett fra enheten:"
adb shell 'ping -c 3 -W 3 1.1.1.1 2>&1 | tail -2' | tr -d '\r'
echo
echo "Ferdig. Backup: $BK/zcfg_config.FØR.json"

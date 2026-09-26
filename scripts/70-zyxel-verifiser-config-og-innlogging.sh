#!/usr/bin/env bash
# Fase 7: Henter enhetens gjeldende config (via adb) og sjekker at innstillingene fra fase 6
# er på plass, og at web-grensesnittet svarer. Endrer ingenting på enheten.
#   ./70-zyxel-verifiser-config-og-innlogging.sh
#   Annen adresse:  ENHET=192.168.1.1 ./70-zyxel-verifiser-config-og-innlogging.sh
set -uo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ENHET="${ENHET:-192.168.2.1}"
adb get-state >/dev/null 2>&1 || { echo "adb ser ingen enhet (se 32-zyxel-sjekk-tilkobling.sh)." >&2; exit 1; }

up=$(adb shell 'cut -d. -f1 /proc/uptime' | tr -d '\r')
if (( up < 150 )); then
  echo "Enheten har bare vært oppe i ${up} s. Config er først komplett etter ca. 150 s – vent litt."
  exit 1
fi

OUT="$BASE/backup/verifiser-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OUT"
adb pull /xdata/zcfg_config.json "$OUT/zcfg_config.json" >/dev/null || { echo "Kunne ikke hente config." >&2; exit 1; }
chmod 600 "$OUT/zcfg_config.json"

echo "== Config ($OUT)"
python3 - "$OUT/zcfg_config.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
fail = 0
def chk(label, cond, info=False):
    global fail
    tag = "OK" if cond else ("INFO" if info else "FEIL")
    print(f"  [{tag:<4}] {label}")
    if not cond and not info:
        fail = 1
svc = {s.get("Name"): s for s in d["X_ZYXEL_RemoteManagement"]["Service"]}
acc = {a.get("Username"): a for g in d["X_ZYXEL_LoginCfg"]["LogGp"] for a in g["Account"]}
chk("Endringer beholdes ved omstart (BootFromFactoryDefault = false)", d["X_ZYXEL_EXT"]["BootFromFactoryDefault"] is False)
chk("DHCP-server på LAN", d["DHCPv4"]["Server"]["Enable"] is True)
chk("HTTPS på LAN", svc["HTTPS"]["Enable"] and svc["HTTPS"].get("Mode") in ("LAN_ONLY", "LAN_WAN"))
chk("SSH på LAN", svc["SSH"]["Enable"] and svc["SSH"].get("Mode") in ("LAN_ONLY", "LAN_WAN"))
chk("admin-konto aktiv", acc.get("admin", {}).get("Enabled") is True)
chk("supervisor-konto aktiv", acc.get("supervisor", {}).get("Enabled") is True, info=True)
ms = d["ManagementServer"]
chk("TR-069/CWMP av, ingen ACS-URL", not ms["EnableCWMP"] and not ms.get("URL"))
chk("TR-369/USP-kontroller av", not any(c.get("Enable") for c in d.get("LocalAgent", {}).get("Controller", [])))
chk("MQTT-klienter av", not any(c.get("Enable") for c in d.get("MQTT", {}).get("Client", [])))
pt = d.get("X_ZYXEL_RemoteManagement_IP_PassThrough", {}).get("Service", [])
chk("WAN-administrasjon i passthrough av", not any(s.get("Enable") for s in pt))
apns = [a.get("APN") for a in d["Cellular"]["AccessPoint"] if a.get("Enable")]
print(f"  [INFO] Aktive APN: {', '.join(apns) or '(ingen)'}")
if any(a.get("SshKeyBaseAuthPublicKey") for a in acc.values()):
    print("  [INFO] Operatørens SSH-nøkkel for root er lagt inn fra factory (SSH er kun LAN)")
sys.exit(fail)
PY
cfg=$?

echo "== Web-grensesnitt"
code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 6 "https://$ENHET/" 2>/dev/null || true)"
if [[ "$code" == 200 ]]; then echo "  [OK  ] https://$ENHET/ svarer"; else echo "  [FEIL] https://$ENHET/ svarte HTTP $code"; cfg=1; fi
echo "  Innlogging testes av 60-zyxel-sett-admin-passord.sh når passordet settes."
echo
(( cfg )) && echo "Avvik funnet – se [FEIL] over." || echo "Config er i orden."
exit $cfg

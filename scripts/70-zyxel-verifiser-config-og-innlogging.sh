#!/usr/bin/env bash
# Fase 7: Henter enhetens gjeldende config (via adb) og sjekker at den stemmer med ønsket
# oppsett i zyxel_nr7302.yml (+ .local.yml), og at web-grensesnittet svarer. Endrer ingenting.
#   ./70-zyxel-verifiser-config-og-innlogging.sh
#   Annen adresse:  ENHET=192.168.1.1 ./70-zyxel-verifiser-config-og-innlogging.sh
set -uo pipefail
. "$(dirname "$0")/lib/felles.sh"
ENHET="${ENHET:-$(config_verdi pc.enhet_adresse 192.168.2.1)}"
adb get-state >/dev/null 2>&1 || { echo "adb ser ingen enhet (se 32-zyxel-sjekk-tilkobling.sh)." >&2; exit 1; }

up=$(adb_sh 'cut -d. -f1 /proc/uptime')
if (( up < CONFIG_KLAR_SEK )); then
  echo "Enheten har bare vært oppe i ${up} s. Config er først komplett etter ca. $CONFIG_KLAR_SEK s – vent litt."
  exit 1
fi

OUT="$BASE/backup/verifiser-$(date +%Y%m%d-%H%M%S)"; privat_mappe "$OUT"
adb pull /xdata/zcfg_config.json "$OUT/zcfg_config.json" >/dev/null || { echo "Kunne ikke hente config." >&2; exit 1; }
chmod 600 "$OUT/zcfg_config.json"

echo "== Config mot zyxel_nr7302(.local).yml ($OUT)"
"$BASE/scripts/lib/sjekk-oppsett.py" "$OUT/zcfg_config.json"
cfg=$?

echo "== Web-grensesnitt"
code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 6 "https://$ENHET/" 2>/dev/null || true)"
if [[ "$code" == 200 ]]; then echo "  [OK  ] https://$ENHET/ svarer"; else echo "  [FEIL] https://$ENHET/ svarte HTTP $code"; cfg=1; fi
echo "  Innlogging testes av 60-zyxel-sett-admin-passord.sh når passordet settes."
echo
(( cfg )) && echo "Avvik funnet – se [FEIL] over." || echo "Config er i orden."
exit $cfg

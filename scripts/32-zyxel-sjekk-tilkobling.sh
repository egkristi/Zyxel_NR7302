#!/usr/bin/env bash
# Fase 3: Sjekker kontakten med NR7302 over USB (adb) og nettverk. Endrer ingenting.
#   ./32-zyxel-sjekk-tilkobling.sh
#   Annen adresse:  ENHET=192.168.1.1 ./32-zyxel-sjekk-tilkobling.sh
. "$(dirname "$0")/lib/felles.sh"
ENHET="${ENHET:-$(config_verdi pc.enhet_adresse 192.168.2.1)}"
fail=0

echo "== USB"
if lsusb | grep -qiE '2c7c:|05c6:|0586:'; then
  ok "$(lsusb | grep -iE '2c7c:|05c6:|0586:' | head -1 | cut -d' ' -f6-)"
else bad "ingen Quectel/Zyxel-enhet på USB (datakabel? prøv en USB-A-port)"; fi

echo "== adb"
state="$(adb get-state 2>/dev/null || true)"
if [[ "$state" == "device" ]]; then
  ok "adb tilkoblet"
  id="$(adb_sh id 2>/dev/null)"
  [[ "$id" == uid=0* ]] && ok "root-skall" || bad "ikke root: $id"
  ok "oppetid: $(adb_sh 'cut -d" " -f1 /proc/uptime') s"
else
  bad "adb ser ingen enhet (adb av? se «Slå på adb» i README)"
fi

echo "== Nettverk mot $ENHET"
ping -c1 -W2 "$ENHET" >/dev/null 2>&1 && ok "ping" || bad "svarer ikke på ping (kjør 30-pc-sett-nettverkskort-mot-zyxel.sh)"
code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 6 "https://$ENHET/" 2>/dev/null || true)"
[[ "$code" == 200 ]] && ok "web-grensesnitt https://$ENHET/" || bad "web-grensesnitt svarer ikke (HTTP $code) – normalt før fase 6"
timeout 3 bash -c "</dev/tcp/$ENHET/22022" 2>/dev/null && ok "SSH-port 22022 åpen" || info "SSH-port 22022 lukket – normalt før fase 6"

echo
(( fail )) && echo "Noe mangler – se [FEIL] over." || echo "Tilkoblingen er i orden."
exit $fail

#!/usr/bin/env bash
# Fase 3: Sjekker kontakten med NR7302 over USB (adb) og nettverk. Endrer ingenting.
#   ./32-zyxel-sjekk-tilkobling.sh
#   Annen adresse:  ENHET=192.168.1.1 ./32-zyxel-sjekk-tilkobling.sh
ENHET="${ENHET:-192.168.2.1}"
fail=0
ok()  { printf '  [OK]    %s\n' "$*"; }
bad() { printf '  [FEIL]  %s\n' "$*"; fail=1; }

echo "== USB"
if lsusb | grep -qiE '2c7c:|05c6:|0586:'; then
  ok "$(lsusb | grep -iE '2c7c:|05c6:|0586:' | head -1 | cut -d' ' -f6-)"
else bad "ingen Quectel/Zyxel-enhet på USB (datakabel? prøv en USB-A-port)"; fi

echo "== adb"
state="$(adb get-state 2>/dev/null || true)"
if [[ "$state" == "device" ]]; then
  ok "adb tilkoblet"
  id="$(adb shell id 2>/dev/null | tr -d '\r')"
  [[ "$id" == uid=0* ]] && ok "root-skall" || bad "ikke root: $id"
  ok "oppetid: $(adb shell 'cut -d" " -f1 /proc/uptime' | tr -d '\r') s"
else
  bad "adb ser ingen enhet (adb av? se «Slå på adb» i README)"
fi

echo "== Nettverk mot $ENHET"
ping -c1 -W2 "$ENHET" >/dev/null 2>&1 && ok "ping" || bad "svarer ikke på ping (kjør 30-pc-sett-nettverkskort-mot-zyxel.sh)"
code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 6 "https://$ENHET/" 2>/dev/null || true)"
[[ "$code" == 200 ]] && ok "web-grensesnitt https://$ENHET/" || bad "web-grensesnitt svarer ikke (HTTP $code) – normalt før fase 6"
timeout 3 bash -c "</dev/tcp/$ENHET/22022" 2>/dev/null && ok "SSH-port 22022 åpen" || printf '  [INFO]  SSH-port 22022 lukket – normalt før fase 6\n'

echo
(( fail )) && echo "Noe mangler – se [FEIL] over." || echo "Tilkoblingen er i orden."
exit $fail

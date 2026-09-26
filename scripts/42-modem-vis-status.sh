#!/usr/bin/env bash
# Fase 4 og 7: Viser modemets status via adb (enhetens eget atcmd). Bare lesekommandoer.
#   ./42-modem-vis-status.sh
#
#   AT+CPIN?      SIM klart (READY) eller venter på PIN
#   AT+COPS?      operatør og teknologi (7 = LTE, 13 = LTE+NR/NSA)
#   AT+CEREG?     LTE-registrering (…,1 = hjemmenett, …,5 = roaming)
#   AT+C5GREG?    5G SA-registrering
#   AT+CGDCONT?   APN-profiler
#   AT+CGPADDR    IP-adresse per profil (0.0.0.0 = ingen)
#   servingcell   bånd, celle, RSRP / RSRQ / SINR
adb get-state >/dev/null 2>&1 || { echo "adb ser ingen enhet (se 32-zyxel-sjekk-tilkobling.sh)." >&2; exit 1; }
for c in 'AT+CPIN?' 'AT+QSIMDET?' 'AT+CIMI' 'AT+COPS?' 'AT+CEREG?' 'AT+C5GREG?' \
         'AT+CGDCONT?' 'AT+CGPADDR' 'AT+QENG=\"servingcell\"' 'AT+QNWPREFCFG=\"mode_pref\"'; do
  echo ">>> ${c//\\/}"
  adb shell "timeout 8 atcmd \"$c\" </dev/null 2>&1" | tr -d '\r' | grep -v '^$' \
    | sed -E 's/^([0-9]{5})[0-9]+$/\1xxxxxxxxxx  (IMSI, skjult)/'
done

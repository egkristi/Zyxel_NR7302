#!/usr/bin/env bash
# Setter admin-passordet (og valgfritt supervisor/root) på NR7302 til en kjent verdi.
#
#   ./60-zyxel-sett-admin-passord.sh [passord] [--alle]
#
# Metode (bekreftet på denne enheten 2026-09-26): zcmd krypterer klartekst som legges i
# Password-feltet i /xdata/zcfg_config.json ved oppstart. Vi skriver derfor ønsket passord
# som klartekst, starter på nytt, og verifiserer at det ble kryptert (_encrypt_) og at
# web-grensesnittet svarer. Bytt passordet selv i web-grensesnittet etterpå.
#
#   passord   Ønsket passord (min. 8 tegn). Uten argument brukes serienummeret fra enheten.
#   --alle    Sett samme passord for admin, supervisor og root (ellers bare admin).
#
# Alt gjøres over adb (USB). Full backup av config tas først. Kan rulles tilbake med
# 90-zyxel-gjenopprett-config-fra-backup.sh <backupfil>.
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
PW="${1:-}"; ALL="no"
[[ "${1:-}" == "--alle" ]] && { PW=""; ALL="ja"; }
[[ "${2:-}" == "--alle" ]] && ALL="ja"

adb wait-for-device

TS="$(date +%Y%m%d-%H%M%S)"
BK="$BASE/backup/config-$TS"; mkdir -p "$BK"
echo "== Tar backup av config -> $BK"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.FØR.json" >/dev/null
adb shell 'cp /xdata/zcfg_config.json /xdata/zcfg_config.json.bakadm' >/dev/null

# Standardpassord = enhetens serienummer (DeviceInfo.SerialNumber, samme som på etiketten).
# Hentes fra enheten, ikke fra det interne modem-serienummeret i /proc/cmdline.
if [[ -z "$PW" ]]; then
  PW="$(python3 -c "import json;print(json.load(open('$BK/zcfg_config.FØR.json')).get('DeviceInfo',{}).get('SerialNumber',''))")"
  [[ -z "$PW" ]] && PW="$(adb shell 'zycli sys atsh 2>/dev/null' | tr -d '\r' | awk -F: '/Serial Number/{gsub(/ /,"",$2);print $2}' | head -1)"
  [[ -z "$PW" ]] && PW="Zyxel$(date +%y%m%d)"
  echo "== Bruker standardpassord (enhetens serienummer): $PW"
fi
if [[ ${#PW} -lt 8 ]]; then echo "Passordet må være minst 8 tegn (fikk '${PW}')." >&2; exit 1; fi

echo "== Lager ny config: admin$([[ $ALL == ja ]] && echo ', supervisor, root') = '$PW'"
python3 - "$BK/zcfg_config.FØR.json" "$BK/zcfg_config.NY.json" "$PW" "$ALL" <<'PY'
import json,sys
src,dst,pw,allacc=sys.argv[1:5]
users={'admin'} if allacc!='ja' else {'admin','supervisor','root'}
d=json.load(open(src,encoding='utf-8'))
n=0
for g in d['X_ZYXEL_LoginCfg']['LogGp']:
    for a in g['Account']:
        if a.get('Username') in users:
            a['Password']=pw            # klartekst -> zcmd krypterer ved boot
            a['Enabled']=True
            a['PasswordHash']=''
            n+=1
assert n>0, "fant ingen kontoer å endre"
json.dump(d,open(dst,'w',encoding='utf-8'),separators=(',',':'),ensure_ascii=False)
print(f"  endret {n} konto(er)")
PY

echo "== Skriver til enheten og starter på nytt"
adb push "$BK/zcfg_config.NY.json" /tmp/zcfg_new.json >/dev/null
adb shell 'cat /tmp/zcfg_new.json > /xdata/zcfg_config.json && sync' >/dev/null
adb shell 'reboot' >/dev/null || true

echo "== Venter på at enheten kommer opp igjen (kan ta 3 min)"
sleep 25; timeout 220 adb wait-for-device; sleep 150

echo "== Verifiserer"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.ETTER.json" >/dev/null
enc="$(python3 - "$BK/zcfg_config.ETTER.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
for g in d['X_ZYXEL_LoginCfg']['LogGp']:
    for a in g['Account']:
        if a.get('Username')=='admin': print(a['Password'])
PY
)"
echo "  admin Password = $enc"
GW="$(adb shell 'ip -4 addr show bridge0 2>/dev/null' | tr -d '\r' | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)"
[[ -z "$GW" ]] && GW="192.168.2.1"
if echo "$enc" | grep -q '_encrypt_'; then
  # Test faktisk innlogging mot web-grensesnittet
  res="$(curl -sk --max-time 10 -H 'Content-Type: application/json' -X POST "https://$GW/UserLogin" \
        --data "{\"Input_Account\":\"admin\",\"Input_Passwd\":\"$(printf %s "$PW" | base64)\",\"currLang\":\"en\",\"RememberPassword\":0,\"SHA512_password\":false}" 2>/dev/null)"
  if echo "$res" | grep -q ZCFG_SUCCESS; then
    echo "  OK: innlogging på web-grensesnittet bekreftet."
  else
    echo "  ADVARSEL: kryptert, men login-test svarte: $res" >&2
  fi
else
  echo "  ADVARSEL: forventet _encrypt_. Sjekk manuelt før du stoler på det." >&2
fi
echo
echo "FERDIG. Logg inn på https://$GW med:  admin / $PW"
[[ $ALL == ja ]] && echo "Samme passord for supervisor og root (SSH: ssh -p 22022 root@$GW)."
echo "Bytt passordet i web-grensesnittet nå. Backup av forrige config: $BK/zcfg_config.FØR.json"

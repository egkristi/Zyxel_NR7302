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
#   passord   Ønsket passord (min. 8 tegn). Uten argument brukes passord.admin fra
#             zyxel_nr7302.local.yml, ellers serienummeret fra enheten.
#   --alle    Sett samme passord for admin, supervisor og root (ellers bare admin).
#
# Alt gjøres over adb (USB). Backup av config tas først. Kan rulles tilbake med
# 90-zyxel-gjenopprett-config-fra-backup.sh <backupfil>.
set -euo pipefail
. "$(dirname "$0")/lib/felles.sh"

PW=""; ALL="nei"
for a in "$@"; do
  case "$a" in
    --alle) ALL="ja" ;;
    -*) echo "Ukjent valg: $a" >&2; exit 1 ;;
    *) PW="$a" ;;
  esac
done
VIS_PW="nei"   # passordet skrives bare ut når skriptet har valgt det selv
[[ -z "$PW" ]] && PW="$(config_verdi passord.admin)"

adb wait-for-device

BK="$BASE/backup/config-$(date +%Y%m%d-%H%M%S)"; privat_mappe "$BK"
echo "== Tar backup av config -> $BK"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.FØR.json" >/dev/null

# Standardpassord = enhetens serienummer (DeviceInfo.SerialNumber, samme som på etiketten).
# Hentes fra enheten, ikke fra det interne modem-serienummeret i /proc/cmdline.
if [[ -z "$PW" ]]; then
  PW="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("DeviceInfo",{}).get("SerialNumber",""))' "$BK/zcfg_config.FØR.json")"
  [[ -z "$PW" ]] && PW="$(adb_sh 'zycli sys atsh 2>/dev/null' | awk -F: '/Serial Number/{gsub(/ /,"",$2);print $2}' | head -1)" || true
  [[ -z "$PW" ]] && { echo "Fant ikke serienummeret. Oppgi passord: $0 <passord>" >&2; exit 1; }
  VIS_PW="ja"
  echo "== Bruker standardpassord (enhetens serienummer): $PW"
fi
if [[ ${#PW} -lt 8 ]]; then echo "Passordet må være minst 8 tegn (fikk ${#PW})." >&2; exit 1; fi

echo "== Lager ny config: admin$([[ $ALL == ja ]] && echo ', supervisor, root')"
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
chmod 600 "$BK"/*.json

echo "== Skriver til enheten"
adb_skriv_config "$BK/zcfg_config.NY.json"
echo "== Starter på nytt og venter til configen er klar (ca. 3 min)"
adb_omstart_og_vent; echo

echo "== Verifiserer"
adb pull /xdata/zcfg_config.json "$BK/zcfg_config.ETTER.json" >/dev/null
chmod 600 "$BK/zcfg_config.ETTER.json"
enc="$(python3 - "$BK/zcfg_config.ETTER.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
for g in d['X_ZYXEL_LoginCfg']['LogGp']:
    for a in g['Account']:
        if a.get('Username')=='admin': print(a['Password'])
PY
)"
GW="$(adb_sh 'ip -4 addr show bridge0 2>/dev/null' | awk '/inet /{print $2}' | cut -d/ -f1 | head -1)" || true
[[ -z "$GW" ]] && GW="$(config_verdi pc.enhet_adresse 192.168.2.1)"
if [[ "$enc" == _encrypt_* ]]; then
  echo "  admin-passordet er kryptert av enheten."
  # Test faktisk innlogging mot web-grensesnittet
  res="$(curl -sk --max-time 10 -H 'Content-Type: application/json' -X POST "https://$GW/UserLogin" \
        --data "{\"Input_Account\":\"admin\",\"Input_Passwd\":\"$(printf %s "$PW" | base64 -w0)\",\"currLang\":\"en\",\"RememberPassword\":0,\"SHA512_password\":false}" 2>/dev/null || true)"
  if grep -q ZCFG_SUCCESS <<<"$res"; then
    echo "  OK: innlogging på web-grensesnittet bekreftet."
  else
    echo "  ADVARSEL: kryptert, men login-test svarte: ${res:-(ingen svar)}" >&2
  fi
else
  echo "  ADVARSEL: forventet _encrypt_, men passordfeltet er ikke kryptert. Sjekk manuelt." >&2
fi
echo
if [[ $VIS_PW == ja ]]; then
  echo "FERDIG. Logg inn på https://$GW med:  admin / $PW"
else
  echo "FERDIG. Logg inn på https://$GW med brukeren admin og passordet du valgte."
fi
[[ $ALL == ja ]] && echo "Samme passord for supervisor og root (SSH: ssh -p 22022 root@$GW)."
echo "Bytt passordet i web-grensesnittet nå. Backup av forrige config: $BK/zcfg_config.FØR.json"

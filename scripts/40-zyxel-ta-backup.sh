#!/usr/bin/env bash
# Full backup av NR7302 over adb (USB-C). Kun lesing – endrer ingenting på enheten.
#
#   ./40-zyxel-ta-backup.sh
#
# Lager backup/<dato-tid>/ med: systeminfo, /xdata, zcfg_config.json (urørt kopi),
# alle MTD-partisjoner (rå), liste over firmwarefiler som ligger igjen på enheten,
# og SHA256SUMS. Sammenligner MD5 på enheten mot PC for hver partisjon.
set -uo pipefail
. "$(dirname "$0")/lib/felles.sh"

OUT="$BASE/backup/$(date +%Y%m%d-%H%M%S)"
privat_mappe "$OUT"; privat_mappe "$OUT/mtd"
umask 077
exec > >(tee "$OUT/backup.log") 2>&1

sh_() { adb_sh "$@"; }

echo "== Venter på enhet (adb) ..."
adb wait-for-device
adb devices -l

echo "== Systeminfo"
{
  echo "# id";            sh_ id
  echo "# uname -a";      sh_ uname -a
  echo "# /proc/cmdline"; sh_ cat /proc/cmdline
  echo "# /proc/mtd";     sh_ cat /proc/mtd
  echo "# df";            sh_ df -h
  echo "# mount";         sh_ mount
  echo "# ip addr";       sh_ ip addr
  echo "# ls -la /xdata"; sh_ ls -la /xdata
  echo "# fw_version";    sh_ 'cat /etc/fw_version /etc/version /xdata/*version* 2>/dev/null'
} > "$OUT/systeminfo.txt"
head -40 "$OUT/systeminfo.txt"

if ! sh_ id | grep -q 'uid=0'; then
  echo "!! adb-skallet er IKKE root. Backup av /xdata og MTD kan feile. Stopp og rapporter."
fi
if sh_ '[ -f /xdata/.zdbg ] && echo JA' | grep -q JA; then
  echo "!! /xdata/.zdbg finnes – enheten er i debug-modus (kjent årsak til boot-problemer)."
fi

echo "== /xdata"
adb pull /xdata "$OUT/xdata"
cp -p "$OUT/xdata/zcfg_config.json" "$OUT/zcfg_config.ORIGINAL.json" 2>/dev/null \
  && chmod a-w "$OUT/zcfg_config.ORIGINAL.json" \
  || echo "!! Fant ikke /xdata/zcfg_config.json"

echo "== MTD-partisjoner"
# efs2 eies av modemprosessoren; rålesing fra Linux krasjet enheten (2026-09-26). Hoppes over.
SKIP=" efs2 "
# Viktigste først: eID/fabrikkdata, deretter firmware, til slutt store/logg-partisjoner.
FIRST=" rom-d factory cust_info rawdata sys_rev devinfo misc oemdata "
# TrustZone/sikker sone: kan være låst for Linux og krasje enheten ved lesing – tas sist.
RISKY=" syslog usrdata tz tz_devcfg qhee sec apdp aop ddr xbl_config xbl_ramdump logfs "
mtdlist=$(sh_ cat /proc/mtd | awk -F'[: ]+' '/^mtd/ {gsub(/"/,"",$4); print $1, $2, $4}')
inorder() { awk -v o="$1" 'index(o," "$3" ") {print index(o," "$3" "), $0}' <<<"$mtdlist" | sort -n | cut -d' ' -f2-; }
ordered=$( { inorder "$FIRST"
             awk -v o="$FIRST$RISKY" '!index(o," "$3" ")' <<<"$mtdlist"
             inorder "$RISKY"; } )
while read -r dev size name; do
  if [[ "$SKIP" == *" $name "* ]]; then printf '  %-6s %-20s hoppet over (modem-eid)\n' "$dev" "$name"; continue; fi
  if ! adb get-state >/dev/null 2>&1 < /dev/null; then
    echo "!! Mistet kontakt med enheten før $dev ($name). Avbryter – ikke kjør videre før vi har sett på dette."
    exit 1
  fi
  f="$OUT/mtd/${dev}_${name}.img"
  printf '  %-6s %-20s %8d KiB ... ' "$dev" "$name" $((16#$size / 1024))
  adb exec-out "dd if=/dev/$dev bs=128k 2>/dev/null" > "$f" < /dev/null
  have=$(stat -c %s "$f")
  dev_md5=$(sh_ "md5sum /dev/$dev 2>/dev/null" < /dev/null | cut -d' ' -f1)
  pc_md5=$(md5sum "$f" | cut -d' ' -f1)
  if [[ "$have" -ne $((16#$size)) ]]; then echo "FEIL størrelse ($have byte)"
  elif [[ -n "$dev_md5" && "$dev_md5" != "$pc_md5" ]]; then echo "FEIL md5 (enhet $dev_md5)"
  else echo "ok"; fi
done <<<"$ordered"

echo "== Leter etter firmwarefiler som ligger igjen på enheten (mulig Telenor-original)"
sh_ 'find / -xdev \( -name "*.bin" -o -name "*.zip" -o -name "fotaconfig.xml" -o -name "*ACHA*" \) -size +1000k 2>/dev/null; for d in /cache /data /xdata /tmp /var; do find $d \( -name "*.bin" -o -name "*.zip" -o -name "fotaconfig.xml" -o -name "*ACHA*" \) 2>/dev/null; done' \
  | sort -u | tee "$OUT/firmwarefiler-paa-enheten.txt"

echo "== Sjekksummer"
# shellcheck disable=SC2094  # SHA256SUMS er utelatt i find
(cd "$OUT" && find . -type f ! -name SHA256SUMS ! -name backup.log -print0 | xargs -0 sha256sum > SHA256SUMS)
du -sh "$OUT"
echo "Ferdig: $OUT"
echo "Kopier HELE mappen til et sted til (minnepenn/sky) før du går videre."

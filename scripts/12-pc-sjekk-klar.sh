#!/usr/bin/env bash
# Sjekker at alt er installert, lastet ned og riktig før du begynner. Endrer ingenting.
#   ./12-pc-sjekk-klar.sh
. "$(dirname "$0")/lib/felles.sh"
IFACE="$(finn_iface)"   # første kablede kort, pc.nettverkskort i yml, eller IFACE=...
BAD_TAG=MANGLER
fail=0

echo "== Programmer"
for c in adb fastboot gcc git jq python3 nmcli curl unzip xdg-open; do
  command -v "$c" >/dev/null && ok "$c" || bad "$c  (kjør: sudo $BASE/scripts/10-pc-installer-pakker.sh)"
done

python3 -c "import yaml" 2>/dev/null && ok "python3-yaml" || bad "python3-yaml (kjør: sudo $BASE/scripts/10-pc-installer-pakker.sh)"
for c in binwalk unsquashfs mksquashfs ubinize; do
  command -v "$c" >/dev/null && info "$c (valgfri, for upstream-metoden med modifisert firmware)" \
    || info "$c mangler (valgfri, bare for upstream-metoden med modifisert firmware)"
done

echo "== udev / tilganger"
[[ -f /etc/udev/rules.d/52-zyxel-nr7302.rules ]] && ok "udev-regel for Quectel/Zyxel" || bad "udev-regel (sudo ./11-pc-sett-udev-regler.sh)"
id -nG | grep -qw plugdev && ok "bruker i gruppe plugdev" || bad "bruker ikke i plugdev"

echo "== zycast"
if [[ -x "$BASE/tools/zycast_flash" ]] && "$BASE/tools/zycast_flash" 2>&1 | grep -q -- '-i interface'; then
  ok "tools/zycast_flash kompilert og kjører"
else bad "tools/zycast_flash (se tools/README.md)"; fi

echo "== Upstream (valgfritt)"
[[ -d "$BASE/repo/.git" ]] && info "upstream-repo i repo/ ($(git -C "$BASE/repo" log -1 --format='%h %cs'))" || info "upstream-repo (valgfritt): git clone https://github.com/davidohne/Zyxel_NR7302 repo"

echo "== Nettverkskort"
if [[ -z "$IFACE" ]]; then
  bad "fant ikke noe kablet nettverkskort (sett IFACE=... eller pc.nettverkskort i yml)"
elif ip link show "$IFACE" >/dev/null 2>&1; then ok "$IFACE finnes"
else bad "$IFACE finnes ikke"; fi
andre="$(ip -4 -br addr | awk -v i="$IFACE" '$1!=i && $1!="lo"')"
for nett in 192.168.1 192.168.2; do
  if grep -q " ${nett//./\\.}\." <<<"$andre"; then
    bad "Et annet grensesnitt bruker $nett.0/24 – konflikt med Zyxel. Koble fra det nettet."
  else ok "ingen IP-konflikt med $nett.0/24"; fi
done
info "Andre grensesnitt: $(awk '{print $1" "$3}' <<<"$andre" | tr "\n" " ")"

echo "== Firmware (firmware/*.bin)"
shopt -s nullglob
fws=("$BASE"/firmware/*.bin)
if (( ${#fws[@]} == 0 )); then
  bad "ingen firmware i firmware/ (trengs først i fase 4 / ved brick)"
else
  "$BASE/scripts/22-pc-sjekk-firmwarefil.py" "${fws[@]}" | sed 's/^/  /' || fail=1
fi

echo "== Diskplass"
info "$(df -h "$BASE" | awk 'NR==2 {print $4 " ledig"}')"

echo "== USB / adb (bare hvis antennen er koblet til)"
if lsusb | grep -qiE '2c7c|05c6|0586'; then
  lsusb | grep -iE '2c7c|05c6|0586' | sed 's/^/  [INFO]  /'
else info "ingen Qualcomm/Quectel/Zyxel-enhet på USB nå"; fi
adb devices 2>/dev/null | sed -n '2,$p' | grep . | sed 's/^/  [INFO]  adb: /' || true

echo
(( fail )) && echo "Noe mangler – se [MANGLER] over." || echo "Alt klart."
exit $fail

#!/usr/bin/env bash
# Nettverksoppsett mot Zyxel NR7302 på kablet port, med full tilbakerulling.
#
#   sudo ./pc-nettverkskort.sh admin    Statisk 192.168.2.4/24 via NetworkManager (webgrensesnitt/SSH).
#                                Telenor-oppsettet har LAN (bridge0) på 192.168.2.1, ikke 192.168.1.1.
#                                Ingen gateway: WiFi beholder internett og default-rute.
#   sudo ./pc-nettverkskort.sh zycast   192.168.1.4/24 (bootloaderen/zycast). Tar porten ut av NetworkManager og setter IP direkte,
#                                slik at adressen overlever at linken går ned/opp under
#                                oppstart av antennen. Slår av WiFi (anbefalt i repoet).
#   sudo ./pc-nettverkskort.sh down     Rull tilbake alt: fjern profil, gi porten tilbake til
#                                NetworkManager, slå WiFi på igjen hvis det var på.
#   ./pc-nettverkskort.sh status        Vis nåværende tilstand.
#
# Adressene hentes fra pc.* i zyxel_nr7302(.local).yml. Miljøvariablene IFACE, ADMIN_ADDR og
# ADMIN_GW overstyrer.
set -euo pipefail
# shellcheck source=felles.sh
. "$(dirname "$0")/felles.sh"

IFACE="$(finn_iface)"
PROFILE="zyxel-nr7302"
ADMIN_ADDR="${ADMIN_ADDR:-$(config_verdi pc.admin_adresse 192.168.2.4/24)}"
ADMIN_GW="${ADMIN_GW:-$(config_verdi pc.enhet_adresse 192.168.2.1)}"
ZYCAST_ADDR="$(config_verdi pc.zycast_adresse 192.168.1.4/24)"
STATE="$BASE/logg/.wifi-var-paa"
[[ -n "$IFACE" ]] || { echo "Fant ikke kablet nettverkskort. Sett IFACE=... eller pc.nettverkskort i yml." >&2; exit 1; }

need_root() { [[ $EUID -eq 0 ]] || { echo "Kjør med sudo: sudo $0 $1" >&2; exit 1; }; }

status() {
  echo "== Grensesnitt $IFACE"
  ip -br addr show "$IFACE"
  echo "== NetworkManager"
  nmcli -t -f DEVICE,STATE,CONNECTION device status | grep -E "^($IFACE|wlp)" || true
  nmcli -t -f NAME connection show | grep -qx "$PROFILE" && echo "Profil $PROFILE finnes" || echo "Profil $PROFILE finnes ikke"
  echo "== WiFi: $(nmcli radio wifi)"
  echo "== Default-rute"
  ip route show default
  local target=""
  ip -br addr show "$IFACE" | grep -q "${ADMIN_ADDR%/*}" && target="$ADMIN_GW"
  ip -br addr show "$IFACE" | grep -q "${ZYCAST_ADDR%/*}" && target="${ZYCAST_ADDR%.*}.1"
  if [[ -n "$target" ]]; then
    ping -c1 -W1 -I "$IFACE" "$target" >/dev/null 2>&1 && echo "$target svarer på ping" || echo "$target svarer ikke (ennå)"
  fi
}

admin() {
  need_root admin
  nmcli device set "$IFACE" managed yes
  nmcli -t -f NAME connection show | grep -qx "$PROFILE" && nmcli connection delete "$PROFILE" >/dev/null
  nmcli connection add type ethernet ifname "$IFACE" con-name "$PROFILE" \
    ipv4.method manual ipv4.addresses "$ADMIN_ADDR" \
    ipv4.never-default yes ipv4.ignore-auto-dns yes \
    ipv6.method disabled \
    connection.autoconnect yes connection.autoconnect-priority 100 >/dev/null
  # Uten link (antenne av) feiler "up"; profilen aktiveres da automatisk når linken kommer.
  nmcli connection up "$PROFILE" >/dev/null 2>&1 \
    && echo "Profil $PROFILE aktiv." \
    || echo "Profil $PROFILE lagret; aktiveres automatisk når kabelen får link."
  status
}

zycast() {
  need_root zycast
  nmcli -t -f NAME connection show | grep -qx "$PROFILE" && nmcli connection down "$PROFILE" >/dev/null 2>&1 || true
  nmcli device set "$IFACE" managed no
  ip addr flush dev "$IFACE"
  ip addr add "$ZYCAST_ADDR" dev "$IFACE"
  ip link set "$IFACE" up
  if [[ "$(nmcli radio wifi)" == "enabled" ]]; then
    mkdir -p "$(dirname "$STATE")"; touch "$STATE"
    nmcli radio wifi off
    echo "WiFi slått av (slås på igjen med: sudo $0 down)."
  fi
  status
}

down() {
  need_root down
  ip addr flush dev "$IFACE" || true
  nmcli device set "$IFACE" managed yes
  nmcli -t -f NAME connection show | grep -qx "$PROFILE" && nmcli connection delete "$PROFILE" >/dev/null
  if [[ -f "$STATE" ]]; then
    nmcli radio wifi on
    rm -f "$STATE"
  fi
  echo "Tilbakerullet. Porten styres igjen av NetworkManager («Wired connection 1», DHCP)."
  status
}

case "${1:-}" in
  admin|zycast|down|status) "$1" ;;
  *) sed -n '2,16p' "$0"; exit 1 ;;
esac

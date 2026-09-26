#!/usr/bin/env bash
# Fase 8 (valgfri): Fjerner udev-reglene som 10-pc-installer-pakker-og-udev.sh la inn
# (adb-tilgang og ModemManager-unntak for Quectel/Zyxel). Installerte pakker beholdes.
#   sudo ./81-pc-fjern-udev-regler.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Kjør med sudo." >&2; exit 1; }
rm -fv /etc/udev/rules.d/52-zyxel-nr7302.rules /etc/udev/rules.d/53-zyxel-nr7302-mm-ignore.rules
udevadm control --reload-rules
systemctl restart ModemManager 2>/dev/null || true
echo "udev-regler fjernet."

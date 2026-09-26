#!/usr/bin/env bash
# Fase 1: Udev-regler slik at vanlig bruker får adb-tilgang til NR7302 over USB, og slik at
# ModemManager på PC-en ikke tar over modemet (AT-port/QMI).
#   sudo ./11-pc-sett-udev-regler.sh
# Fjernes igjen med 81-pc-fjern-udev-regler.sh. Trekk ut og sett i USB-kabelen etterpå.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Kjør med sudo." >&2; exit 1; }

# udev: la vanlig bruker (gruppe plugdev) snakke med adb på enheten uten sudo.
# 05c6 = Qualcomm (dekket av 51-android.rules fra før), 2c7c = Quectel, 0586 = Zyxel.
cat > /etc/udev/rules.d/52-zyxel-nr7302.rules <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="2c7c", MODE="0660", GROUP="plugdev", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="0586", MODE="0660", GROUP="plugdev", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", MODE="0660", GROUP="plugdev", TAG+="uaccess"
EOF
# Hindre ModemManager på PC-en i å ta over modemet (AT-port/QMI) når antennen er koblet på USB.
cat > /etc/udev/rules.d/53-zyxel-nr7302-mm-ignore.rules <<'EOF'
ACTION=="add|change", SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c7c", ENV{ID_MM_DEVICE_IGNORE}="1"
EOF
udevadm control --reload-rules
udevadm trigger
systemctl restart ModemManager
echo "Ferdig. Fjern senere med: sudo rm /etc/udev/rules.d/5[23]-zyxel-nr7302*.rules"

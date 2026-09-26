#!/usr/bin/env bash
# Fase 1: Installerer pakkene som skriptene trenger (Debian/Ubuntu/Linux Mint).
#   sudo ./10-pc-installer-pakker.sh
# Udev-regler for USB-tilgang settes av 11-pc-sett-udev-regler.sh.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Kjør med sudo." >&2; exit 1; }
apt-get update
apt-get install -y \
  adb fastboot usbutils \
  curl unzip jq xdg-utils \
  python3 python3-yaml \
  build-essential git
echo "Ferdig. Neste: sudo ./11-pc-sett-udev-regler.sh"

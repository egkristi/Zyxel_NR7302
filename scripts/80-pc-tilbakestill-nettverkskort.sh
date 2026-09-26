#!/usr/bin/env bash
# Fase 8: Setter PCens nettverkskort tilbake slik det var: fjerner profilen fra fase 3/5,
# gir kortet tilbake til NetworkManager (DHCP) og slår på WiFi igjen hvis fase 5 slo det av.
#   sudo ./80-pc-tilbakestill-nettverkskort.sh
exec "$(dirname "$0")/lib/pc-nettverkskort.sh" down

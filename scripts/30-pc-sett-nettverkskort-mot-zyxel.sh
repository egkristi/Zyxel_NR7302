#!/usr/bin/env bash
# Fase 3: Gir PCens kablede nettverkskort en fast adresse mot NR7302 sitt LAN (standard
# 192.168.2.4/24, Telenor-firmware har enheten på 192.168.2.1). Ingen gateway, så WiFi
# beholder internett. Rulles tilbake med 80-pc-tilbakestill-nettverkskort.sh.
#   sudo ./30-pc-sett-nettverkskort-mot-zyxel.sh
#   Annen adresse:  sudo ADMIN_ADDR=192.168.1.4/24 ADMIN_GW=192.168.1.1 ./30-pc-sett-nettverkskort-mot-zyxel.sh
exec "$(dirname "$0")/lib/pc-nettverkskort.sh" admin

#!/usr/bin/env bash
# Fase 5 (valgfri) / nødverktøy: Nettoppsett for flashing med zycast. Tar kortet ut av
# NetworkManager, setter 192.168.1.4/24 direkte (overlever at linken går ned) og slår av WiFi.
# Rulles tilbake med 80-pc-tilbakestill-nettverkskort.sh.
#   sudo ./50-pc-sett-nettverkskort-for-zycast.sh
exec "$(dirname "$0")/lib/pc-nettverkskort.sh" zycast

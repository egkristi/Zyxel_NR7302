# tools/

Verktøy som bygges lokalt. **Kommer ikke med i git.**

## zycast

Flasher firmware via multicast når enheten ikke kan oppdateres på vanlig måte. Kildekoden er fra
OpenWrt firmware-utils (GPL-2.0):

```bash
cd tools
wget https://github.com/openwrt/firmware-utils/raw/refs/heads/master/src/zycast.c
gcc -O2 -Wall zycast.c -o zycast_flash
```

Brukes av `scripts/51-zyxel-flash-firmware-via-zycast.sh`.

# tools/

🇳🇴 Norsk · [🇬🇧 English](README.en.md)

Verktøy som bygges lokalt. **Kommer ikke med i git.**

## zycast

Flasher firmware via multicast når enheten ikke kan oppdateres på vanlig måte. Kildekoden er fra
OpenWrt firmware-utils (GPL-2.0). Lastes ned og kompileres av:

```bash
scripts/21-pc-bygg-zycast.sh      # gir tools/zycast_flash
```

Brukes av `scripts/51-zyxel-flash-firmware-via-zycast.sh`.

# tools/

[🇳🇴 Norsk](README.md) · 🇬🇧 English

Tools that are built locally. **Do not go into git.**

## zycast

Flashes firmware via multicast when the device cannot be updated the normal way. The source
code is from OpenWrt firmware-utils (GPL-2.0). Downloaded and compiled by:

```bash
scripts/21-pc-bygg-zycast.sh      # produces tools/zycast_flash
```

Used by `scripts/51-zyxel-flash-firmware-via-zycast.sh`.

# firmware/

[🇳🇴 Norsk](README.md) · 🇬🇧 English

Put firmware files (`.bin`) here. They are copyrighted and **do not go into git**.

Telekom (DTAG) publishes NR7302 firmware at
<https://www.telekom.de/hilfe/geraete/router/weitere/zyxel> ("5G Outdoor Router NR7302 Firmware-Update").
`scripts/20-pc-last-ned-telekom-firmware.sh` fetches it, unpacks the `.bin` file here and
checks it. If the site blocks the script, the links are opened in your browser. By hand:

```bash
unzip -j ~/Downloads/firmware-5g-outdoor-router-nr7302.zip "*.bin" -d firmware/
scripts/22-pc-sjekk-firmwarefil.py firmware/*.bin
```

It must show `RESULTAT: OK` (result: OK) before the file is used.

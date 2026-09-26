# firmware/

🇳🇴 Norsk · [🇬🇧 English](README.en.md)

Legg firmwarefiler (`.bin`) her. De er opphavsrettslig beskyttet og **kommer ikke med i git**.

Telekom (DTAG) legger ut NR7302-firmware på
<https://www.telekom.de/hilfe/geraete/router/weitere/zyxel> («5G Outdoor Router NR7302 Firmware-Update»).
`scripts/20-pc-last-ned-telekom-firmware.sh` henter den, pakker ut `.bin`-filen hit og sjekker
den. Blokkerer nettstedet skriptet, åpnes lenkene i nettleseren. For hånd:

```bash
unzip -j ~/Nedlastinger/firmware-5g-outdoor-router-nr7302.zip "*.bin" -d firmware/
scripts/22-pc-sjekk-firmwarefil.py firmware/*.bin
```

Må vise `RESULTAT: OK` før filen brukes.

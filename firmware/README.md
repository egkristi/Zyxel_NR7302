# firmware/

Legg firmwarefiler (`.bin`) her. De er opphavsrettslig beskyttet og **kommer ikke med i git**.

Telekom (DTAG) legger ut NR7302-firmware på
<https://www.telekom.de/hilfe/geraete/router/weitere/zyxel> («5G Outdoor Router NR7302 Firmware-Update»).
Nettstedet stopper nedlasting fra skript, så last ned ZIP-filen i nettleseren, pakk ut `.bin`-filen hit og sjekk den:

```bash
unzip -j ~/Nedlastinger/firmware-5g-outdoor-router-nr7302.zip "*.bin" -d firmware/
scripts/22-pc-sjekk-firmwarefil.py firmware/*.bin
```

Må vise `RESULTAT: OK` før filen brukes.

# Skript

Skriptene er nummerert etter fase, og navnet sier **hvor** noe skjer og **om** noe endres.

## Navneregel

```
<fase><steg>-<mål>-<handling>[-<objekt>]
```

| Del | Betydning |
|---|---|
| **fase** (første siffer) | 1 PC-oppsett · 2 nedlasting · 3 tilkobling · 4 kartlegging/backup · 5 flashing (valgfri) · 6 konfigurasjon · 7 verifisering · 8 avslutning · 9 nødverktøy |
| **mål** | `pc` = Linux-maskinen · `zyxel` = routerdelen av NR7302 (config, web-grensesnitt, adb) · `modem` = Quectel-modemet inni (AT-kommandoer) |
| **handling** | `sjekk`, `vis`, `ta-backup`, `lag` **endrer ingenting på enheten**. `sett`, `aktiver`, `flash`, `gjenopprett`, `tilbakestill`, `fjern` **gjør endringer** |

Skript som må kjøres med `sudo` sier fra selv. Alt som hentes fra enheten havner i
`backup/` og `logg/`, som aldri kommer med i git.

## Oversikt

| Fase | Skript | Mål | Endrer? | Hva |
|---|---|---|---|---|
| 1 | `10-pc-installer-pakker-og-udev.sh` | PC | ja (sudo) | apt-pakker, udev-regler for adb, ModemManager-unntak |
| 1 | `11-pc-sjekk-klar.sh` | PC | nei | sjekker pakker, udev, zycast, nettverkskort, firmwarefiler |
| 2 | `22-pc-sjekk-firmwarefil.py` | PC | nei | validerer firmware-.bin (ZIP, MD5 i fotaconfig.xml, modell-ID 0x7302) |
| 3 | `30-pc-sett-nettverkskort-mot-zyxel.sh` | PC | ja (sudo) | fast IP mot enhetens LAN, uten gateway |
| 4 | `40-zyxel-ta-backup.sh` | zyxel | nei | rå flash-backup av alle partisjoner (unntatt `efs2`) og `/xdata` |
| 4 | `41-zyxel-vis-config.py` | zyxel | nei | viser relevante felt fra en `zcfg_config.json` |
| 5 | `50-pc-sett-nettverkskort-for-zycast.sh` | PC | ja (sudo) | nettoppsett for zycast, slår av WiFi |
| 5 | `51-zyxel-flash-firmware-via-zycast.sh` | zyxel | **ja** (sudo) | flasher .bin med zycast, venter på riktig tidsvindu |
| 6 | `60-zyxel-sett-admin-passord.sh` | zyxel | **ja** | setter kjent admin-passord (standard: serienummeret) og tester innlogging |
| 6 | `61-zyxel-lag-config-lokal-administrasjon.py` | zyxel | nei* | lager config med lokal administrasjon (se under) |
| 6 | `62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh` | zyxel | **ja** | APN + slår av operatørens fjernstyring, verifiserer etter omstart |
| 8 | `80-pc-tilbakestill-nettverkskort.sh` | PC | ja (sudo) | kortet tilbake til NetworkManager/DHCP, WiFi på igjen |
| 8 | `81-pc-fjern-udev-regler.sh` | PC | ja (sudo) | fjerner udev-reglene fra fase 1 (pakker beholdes) |
| 9 | `90-zyxel-gjenopprett-config-fra-backup.sh` | zyxel | **ja** | skriver en `zcfg_config.json` til enheten og starter den på nytt |

\* `61` skriver bare en fil lokalt. Den legges på enheten med `90-…`.

### `lib/` – hjelpeverktøy (kjøres av andre skript eller for hånd)

| Fil | Hva |
|---|---|
| `lib/pc-nettverkskort.sh` | `admin` / `zycast` / `down` / `status` for PCens kablede kort. Brukes av 30, 50 og 80 |
| `lib/modem-at.py` | sender AT-kommandoer til modemet via USB (`/dev/ttyUSB*`), logger til `logg/` |
| `lib/lag-apn-og-fjernstyring-config.py` | lager config for fase 6-skript 62 (kun lokalt) |

## Faser uten eget skript ennå

| Fase | Gjør slik |
|---|---|
| 2 Nedlasting | Last ned «5G Outdoor Router NR7302 Firmware-Update» fra [Telekom](https://www.telekom.de/hilfe/geraete/router/weitere/zyxel). Nettstedet stopper skriptnedlasting, så bruk nettleseren. Pakk ut `.bin` til `firmware/` og kjør `22-pc-sjekk-firmwarefil.py firmware/*.bin`. zycast: se `tools/README.md` |
| 3 Slå på adb | Se «Slå på adb» i hoved-README |
| 7 Verifisering | Se «Verifisering» i hoved-README |

## Nettverkskort

Skriptene bruker første kablede kort som NetworkManager kjenner. Velg et annet med
`IFACE=`, for eksempel `sudo IFACE=enx00e04c680001 ./30-pc-sett-nettverkskort-mot-zyxel.sh`.

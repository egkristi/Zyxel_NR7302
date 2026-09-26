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
| **handling** | `sjekk`, `vis`, `ta-backup`, `lag`, `fang`, `mal` (måle), `last-ned`, `bygg` **endrer ingenting på enheten**. `sett`, `aktiver`, `flash`, `gjenopprett`, `tilbakestill`, `fjern` **gjør endringer** |

Skript som må kjøres med `sudo` sier fra selv. Alt som hentes fra enheten havner i
`backup/` og `logg/`, som aldri kommer med i git.

## Oversikt

| Fase | Skript | Mål | Endrer? | Hva |
|---|---|---|---|---|
| 1 | `10-pc-installer-pakker.sh` | PC | ja (sudo) | apt-pakker skriptene trenger |
| 1 | `11-pc-sett-udev-regler.sh` | PC | ja (sudo) | udev-regler for adb uten sudo, ModemManager-unntak for modemet |
| 1 | `12-pc-sjekk-klar.sh` | PC | nei | sjekker pakker, udev, zycast, nettverkskort, firmwarefiler |
| 2 | `20-pc-last-ned-telekom-firmware.sh` | PC | nei* | henter NR7302-firmware fra Telekom (nettleser ved blokkering), pakker ut og validerer |
| 2 | `21-pc-bygg-zycast.sh` | PC | nei* | laster ned og kompilerer zycast til `tools/` |
| 2 | `22-pc-sjekk-firmwarefil.py` | PC | nei | validerer firmware-.bin (ZIP, MD5 i fotaconfig.xml, modell-ID 0x7302) |
| 3 | `30-pc-sett-nettverkskort-mot-zyxel.sh` | PC | ja (sudo) | fast IP mot enhetens LAN, uten gateway |
| 3 | `32-zyxel-sjekk-tilkobling.sh` | zyxel | nei | USB, adb/root, ping, web, SSH |
| 3 | `33-zyxel-fang-adb-ved-oppstart.sh` | zyxel | nei | venter på adb-vinduet ved oppstart (Telekom-firmware) og henter config + modemstatus |
| 4 | `40-zyxel-ta-backup.sh` | zyxel | nei | rå flash-backup av alle partisjoner (unntatt `efs2`) og `/xdata` |
| 4 | `41-zyxel-vis-config.py` | zyxel | nei | viser relevante felt fra en `zcfg_config.json` |
| 4 | `42-modem-vis-status.sh` | modem | nei | SIM, operatør, registrering, APN, IP, serving cell (via adb) |
| 5 | `50-pc-sett-nettverkskort-for-zycast.sh` | PC | ja (sudo) | nettoppsett for zycast, slår av WiFi |
| 5 | `51-zyxel-flash-firmware-via-zycast.sh` | zyxel | **ja** (sudo) | flasher .bin med zycast, venter på riktig tidsvindu |
| 6 | `60-zyxel-sett-admin-passord.sh` | zyxel | **ja** | setter kjent admin-passord (standard: serienummeret) og tester innlogging |
| 6 | `61-zyxel-lag-config-lokal-administrasjon.py` | zyxel | nei** | lager config med lokal administrasjon (verdier fra `zyxel_nr7302.yml`) |
| 6 | `62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh` | zyxel | **ja** | APN (argument eller `mobil.apn` i yml) + operatørens fjernstyring etter `fjernstyring.*` i yml, verifiserer etter omstart |
| 7 | `70-zyxel-verifiser-config-og-innlogging.sh` | zyxel | nei | sjekker enhetens config mot `zyxel_nr7302.yml`, og web-grensesnittet |
| 7 | `71-pc-mal-hastighet-og-ping-via-zyxel.sh` | PC | nei | hastighet og ping under last, tvunget ut på kablet kort |
| 8 | `80-pc-tilbakestill-nettverkskort.sh` | PC | ja (sudo) | kortet tilbake til NetworkManager/DHCP, WiFi på igjen |
| 8 | `81-pc-fjern-udev-regler.sh` | PC | ja (sudo) | fjerner udev-reglene fra fase 1 (pakker beholdes) |
| 9 | `90-zyxel-gjenopprett-config-fra-backup.sh` | zyxel | **ja** | skriver en `zcfg_config.json` til enheten (atomisk, md5-kontrollert), starter på nytt og venter til den er klar |

\* Skriver bare filer lokalt på PC-en.
\*\* `61` skriver bare en fil lokalt. Den legges på enheten med `90-…`. Kan kjøres flere ganger;
verdier som allerede er riktige hoppes over.

### `lib/` – hjelpeverktøy (kjøres av andre skript eller for hånd)

| Fil | Hva |
|---|---|
| `lib/felles.sh` | felles funksjoner: atomisk config-skriving (`adb_skriv_config`), omstart og venting (`adb_omstart_og_vent`), private backupmapper, valg av nettverkskort, verdier fra yml |
| `lib/oppsett.py` | ønsket oppsett fra `zyxel_nr7302.yml` + `.local.yml`: hva 61/62 skriver og 70 sjekker |
| `lib/config-verdi.py` | skriver ut én verdi fra yml (brukes av skallskriptene) |
| `lib/sjekk-oppsett.py` | sjekker en `zcfg_config.json` mot yml (brukes av 70) |
| `lib/zcfg.py` | Python-hjelpere for `zcfg_config.json`: oppslag på navn, sammenligning |
| `lib/pc-nettverkskort.sh` | `admin` / `zycast` / `down` / `status` for PCens kablede kort. Brukes av 30, 50 og 80 |
| `lib/modem-at.py` | sender AT-kommandoer til modemet via USB (`/dev/ttyUSB*`), logger til `logg/`. Brukes til å slå på adb |
| `lib/lag-apn-og-fjernstyring-config.py` | lager config for 62 (kun lokalt) |

## Uten eget skript

| Hva | Gjør slik |
|---|---|
| Slå på adb (Telenor-firmware) | «Slå på adb» i [hoved-README](../README.md#slå-på-adb) |
| Flashing via web-grensesnittet (Telenor → Telekom) | [docs/flash-telenor-til-dtag.md](../docs/flash-telenor-til-dtag.md) |

## Nettverkskort og adresser

Skriptene bruker første kablede kort som NetworkManager kjenner. Velg et annet med
`IFACE=`, for eksempel `sudo IFACE=enx00e04c680001 ./30-pc-sett-nettverkskort-mot-zyxel.sh`,
eller fast med `pc.nettverkskort` i `zyxel_nr7302.local.yml`. Adressene (`pc.admin_adresse`,
`pc.enhet_adresse`, `pc.zycast_adresse`) hentes også derfra.

## Tester

```bash
python3 -m unittest discover -s tests -v     # Python-skriptene og lib/felles.sh (med falsk adb)
shellcheck scripts/*.sh scripts/lib/*.sh
```

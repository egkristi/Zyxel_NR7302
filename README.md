# Zyxel NR7302 – fri bruk uavhengig av operatør

🇳🇴 Norsk · [🇬🇧 English](README.en.md)

Skript og fremgangsmåte for å ta kontroll over en **operatørlåst Zyxel NR7302** (5G-antenne
for utendørs montering) fra en Linux-PC, slik at den kan brukes med **hvilken som helst
mobiloperatør**, administreres lokalt og ikke lenger fjernstyres av operatøren.

Utviklet og verifisert på en **Telenor-NR7302** (firmware `1.00(ACHA.1)b3_E0`) med SIM fra
**Ice** og **Telia**, på **Linux Mint 22.3** (Ubuntu 24.04-base). Enheten ble deretter flashet
til Telekom-firmware `1.00(ACHA.5)b1_F0`. Bygger på funnene i
[davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302).

> [!WARNING]
> Du endrer enhetens interne konfigurasjon og kan i verste fall gjøre den ubrukelig
> (soft-brick). Ta backup i fase 4 før du endrer noe, og les hele fasen før du kjører den.
> Alt gjøres på eget ansvar.

## Hva du oppnår

| Før (Telenor) | Etter |
|---|---|
| Konfigurasjonen nullstilles ved hver omstart | Endringer blir værende |
| Web-grensesnitt og SSH bare fra operatørens side (WAN) | Tilgjengelig fra ditt eget LAN |
| Ingen kjente kontoer/passord | Kjent admin-passord som du bytter selv |
| Operatørens APN, fungerer bare på Telenor | Din operatørs APN (verifisert med Ice og Telia) |
| Fjernstyrt av operatøren (TR-069, TR-369/USP via MQTT) | Fjernstyring slått av |
| Firmware oppdateres bare via operatørens nett | Valgfritt: Telekom-firmware som kan oppdateres manuelt ([docs](docs/flash-telenor-til-dtag.md)) |

## Forutsetninger

- **Zyxel NR7302 med USB-C-port.** Telenor-enhetene har porten montert. Andre varianter
  (f.eks. Telekom, A1) har den ofte ikke, se upstream-repoet for lodding.
- PoE-injektoren som hører til antennen, nettverkskabel og en **USB-C-kabel som overfører
  data** (bruk en USB-A-port på PC-en hvis USB-C-porten ikke virker, f.eks. Thunderbolt-porter).
- Debian-basert Linux med NetworkManager og `sudo`.
- Valgfritt: en enkel switch. Trengs ved flashing med zycast.

## Fasene

Skriptene ligger i [`scripts/`](scripts/README.md) og er nummerert etter fase.
Navnet sier om skriptet gjelder `pc`, `zyxel` (routerdelen) eller `modem` (Quectel-modemet),
og verbet sier om det endrer noe (`sett`, `flash` …) eller bare leser (`sjekk`, `vis` …).

| Fase | Hva | Skript / fremgangsmåte |
|---|---|---|
| **1 PC-oppsett** | pakker, udev-regler, sjekk | `10-pc-installer-pakker.sh`, `11-pc-sett-udev-regler.sh`, `12-pc-sjekk-klar.sh` |
| **2 Nedlasting** | Telekom-firmware, zycast | `20-pc-last-ned-telekom-firmware.sh`, `21-pc-bygg-zycast.sh`, `22-pc-sjekk-firmwarefil.py` |
| **3 Tilkobling** | nett mot enheten, adb | `30-pc-sett-nettverkskort-mot-zyxel.sh`, [Slå på adb](#slå-på-adb), `32-zyxel-sjekk-tilkobling.sh`, `33-zyxel-fang-adb-ved-oppstart.sh` |
| **4 Kartlegging og backup** | full backup, les config og modem | `40-zyxel-ta-backup.sh`, `41-zyxel-vis-config.py`, `42-modem-vis-status.sh` |
| **5 Flashing (valgfri)** | Telekom-firmware *før* konfigurasjon | [docs/flash-telenor-til-dtag.md](docs/flash-telenor-til-dtag.md), `50-…`, `51-…` |
| **6 Konfigurasjon** | lokal administrasjon, passord, APN, fjernstyring av | `61-…` + `90-…`, `60-zyxel-sett-admin-passord.sh`, `62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh` |
| **7 Verifisering** | config, innlogging, mobildata, hastighet | `70-zyxel-verifiser-config-og-innlogging.sh`, `42-modem-vis-status.sh`, `71-pc-mal-hastighet-og-ping-via-zyxel.sh` |
| **8 Avslutning** | PC tilbake som før | `80-pc-tilbakestill-nettverkskort.sh`, `81-pc-fjern-udev-regler.sh` |
| **9 Nødverktøy** | gjenopprett config, zycast-redning | `90-zyxel-gjenopprett-config-fra-backup.sh`, `50-…` + `51-…` |

### Fase 1 – PC-oppsett

```bash
sudo scripts/10-pc-installer-pakker.sh
sudo scripts/11-pc-sett-udev-regler.sh     # trekk ut og sett i USB-kabelen etterpå
scripts/12-pc-sjekk-klar.sh
```

### Fase 2 – Nedlasting

```bash
scripts/20-pc-last-ned-telekom-firmware.sh   # åpner nettleseren hvis telekom.de blokkerer skript
scripts/21-pc-bygg-zycast.sh
```

Firmware og zycast trengs bare for fase 5 og som redning, men bør ligge klart før du starter.

### Fase 3 – Tilkobling

Antenne → PoE-injektor → nettverkskabel til PC-en, og USB-C fra antennen til PC-en.

```bash
sudo scripts/30-pc-sett-nettverkskort-mot-zyxel.sh   # 192.168.2.4/24, enheten er 192.168.2.1
scripts/32-zyxel-sjekk-tilkobling.sh
```

Telenor-firmwaren har LAN på **192.168.2.1**, ikke 192.168.1.1. PC-en får ingen gateway, så
internett går fortsatt over WiFi.

#### Slå på adb

På Telenor-enheten viser USB-porten bare modemets AT-port og RmNet. adb slås på med én
AT-kommando som bare endrer adb-flagget i USB-oppsettet:

```bash
sudo scripts/lib/modem-at.py 'AT+QCFG="usbcfg"'
# Eksempel på svar:  +QCFG: "usbcfg",0x2C7C,0x0801,0,0,0,1,1,0,0
#   rekkefølge:      VID, PID, diag, nmea, at, modem, rmnet, adb, uac
sudo scripts/lib/modem-at.py 'AT+QCFG="usbcfg",0x2C7C,0x0801,0,0,0,1,1,1,0'   # adb = 1, resten likt
```

Bruk verdiene fra ditt eget svar og bytt bare adb-sifferet (nest siste). Behold modem-porten,
ellers mister du AT-tilgangen. Start enheten på nytt (trekk PoE-strømmen), og sjekk:

```bash
adb devices -l
adb shell id        # skal vise uid=0(root)
```

Innstillingen overlever omstart og firmwarebytte. Sett adb-sifferet til `0` igjen for å slå
det av. **Med Telekom-firmware** er USB bare tilgjengelig ca. 30 s etter oppstart; bruk
`33-zyxel-fang-adb-ved-oppstart.sh`.

### Fase 4 – Kartlegging og backup

```bash
scripts/40-zyxel-ta-backup.sh
scripts/41-zyxel-vis-config.py backup/<tid>/zcfg_config.ORIGINAL.json
scripts/42-modem-vis-status.sh
```

Backupen tar alle MTD-partisjoner unntatt `efs2` (modemets eget filsystem – å lese den
rått fikk enheten til å starte på nytt). **Kopier `backup/` til et annet sted.**

### Fase 5 – Flashing (valgfri)

Egen veiledning: **[docs/flash-telenor-til-dtag.md](docs/flash-telenor-til-dtag.md)**.
Gjør dette *før* fase 6, siden en ny firmware kan nullstille innstillingene.

### Fase 6 – Konfigurasjon

Rekkefølgen er viktig: lokal administrasjon først (ellers nullstilles alt ved neste omstart).

```bash
# 6a: beholde endringer, DHCP, HTTPS/SSH på LAN, aktivere admin/supervisor
scripts/61-zyxel-lag-config-lokal-administrasjon.py backup/<tid>/zcfg_config.ORIGINAL.json /tmp/ny.json
scripts/90-zyxel-gjenopprett-config-fra-backup.sh /tmp/ny.json

# 6b: kjent admin-passord (standard: serienummeret på etiketten), testes med innlogging
scripts/60-zyxel-sett-admin-passord.sh            # eller: ... 'EgetPassord' [--alle]

# 6c: operatørens APN og slå av operatørens fjernstyring (sett inn SIM først)
scripts/62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh ice.net
```

Logg inn på `https://192.168.2.1` og bytt passordet under Maintenance → User Account.
Har SIM-kortet PIN, må den skrives inn i web-grensesnittet etter hvert SIM-bytte.

### Fase 7 – Verifisering

```bash
scripts/70-zyxel-verifiser-config-og-innlogging.sh   # config og web (via adb)
scripts/42-modem-vis-status.sh                       # SIM, operatør, APN, IP, signal
scripts/71-pc-mal-hastighet-og-ping-via-zyxel.sh     # hastighet og ping under last
```

`71` krever at PC-en får adresse fra antennen (DHCP, `80-…`), og tvinger trafikken ut på
kablet kort, så WiFi ikke påvirker målingen. Se [docs/ytelse-og-operatorer.md](docs/ytelse-og-operatorer.md)
for tolkning, abonnementsbegrensninger og bufferbloat.

### Fase 8 – Avslutning

```bash
sudo scripts/80-pc-tilbakestill-nettverkskort.sh
sudo scripts/81-pc-fjern-udev-regler.sh    # valgfritt
```

## Tekniske funn

- `BootFromFactoryDefault=true` gjør at konfigurasjonen bygges på nytt ved hver oppstart, og
  den er først komplett **ca. 2 minutter** etter oppstart. Les den ikke før.
- Enheten krypterer passordfeltene selv ved oppstart. Et passord kan derfor settes ved å legge
  det inn i konfigurasjonen og starte på nytt; det eksisterende kan ikke leses ut.
- Operatøren har tre fjernstyringskanaler: TR-069 (CWMP), TR-369/USP over MQTT (full
  tilgang til hele datamodellen) og administrasjon mot WAN i passthrough (port 200xx).
- Telenors SSH-nøkkel for root legges inn på nytt fra `factory`-partisjonen ved hver oppstart.
  Uskadelig så lenge SSH bare er åpen på LAN og WAN-administrasjon er av.
- Ikke kjør enhetens `zcmd` uten argumenter: det starter en ekstra konfigurasjonsdaemon.
- Telenor-oppsettet bruker to APN-profiler (administrasjon og kundetrafikk). Begge får
  din operatørs APN; typisk gir operatøren IP på én av dem.
- En hengende AT-kanal på enheten (`atcmd` får «COMMAND TIMEOUT») løses med omstart.
- Telekom-firmware: USB/adb bare ~30 s etter oppstart, «Enable Customized Settings» må slås
  om, APN-profil 1 står på *Auto* og må settes manuelt. Detaljer i [docs](docs/flash-telenor-til-dtag.md).
- **Et flatt hastighetstak likt begge veier er nesten alltid abonnementet**, ikke antennen.
  Ice *Data Frihet* er begrenset til 25 Mbit/s; et Telia-SIM i samme antenne ga ~230 Mbit/s.
  Se [docs/ytelse-og-operatorer.md](docs/ytelse-og-operatorer.md).

## `zyxel_nr7302.yml`

Beskriver ønsket oppsett og alle innstillingene som er funnet, merket *verifisert* eller
*ikke testet*. **Planlagt:** skriptene leser den ikke ennå. Personlige verdier legges i
`zyxel_nr7302.local.yml`, som er git-ignorert.

## Personvern – hva som ikke er i dette repoet

Backup, logger, enhetskonfigurasjoner, firmware og lokalt bygde verktøy holdes utenfor git
(se [`.gitignore`](.gitignore)). De inneholder serienummer, IMEI, eID, sertifikater og
passord. Del aldri innholdet i `backup/` eller `logg/`. Skjermbilder av web-grensesnittets
statussider viser IMEI, IMSI, ICCID og GPS-posisjon – ikke publiser dem.

## Lisens

MIT – se [LICENSE.md](LICENSE.md). zycast (GPL-2.0) er ikke inkludert, men lastes ned og
bygges lokalt.

## Kreditering

- [davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302) – funn om Telenor-oppsett,
  cross-flash, passordhenting og firmwareformat (valideringen i `22-pc-sjekk-firmwarefil.py`
  bygger på `rebuild_firmware.sh` derfra).
- zycast fra [OpenWrt firmware-utils](https://github.com/openwrt/firmware-utils) (GPL-2.0).
- Chris / xpla@lteforum.at for zycast-veiledningen, og brukerne i upstream-issuene
  (bl.a. tidsvinduet for zycast på Telenor-enheter).

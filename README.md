# Zyxel NR7302 – fri bruk uavhengig av operatør

Skript og fremgangsmåte for å ta kontroll over en **operatørlåst Zyxel NR7302** (5G-antenne
for utendørs montering) fra en Linux-PC, slik at den kan brukes med **hvilken som helst
mobiloperatør**, administreres lokalt og ikke lenger fjernstyres av operatøren.

Utviklet og verifisert på en **Telenor-NR7302** (firmware `1.00(ACHA.1)b3_E0`) med SIM fra
**Ice**, på **Linux Mint 22.3** (Ubuntu 24.04-base). Bygger på funnene i
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
| Operatørens APN, fungerer bare på Telenor | Din operatørs APN (verifisert med Ice) |
| Fjernstyrt av operatøren (TR-069, TR-369/USP via MQTT) | Fjernstyring slått av |
| Firmware oppdateres bare via operatørens nett | Mulighet for å bytte til firmware som kan oppdateres manuelt (valgfritt) |

## Forutsetninger

- **Zyxel NR7302 med USB-C-port.** Telenor-enhetene har porten montert. Andre varianter
  (f.eks. Telekom, A1) har den ofte ikke, se upstream-repoet for lodding.
- PoE-injektoren som hører til antennen, nettverkskabel og en **USB-C-kabel som overfører
  data** (bruk en USB-A-port på PC-en hvis USB-C-porten ikke virker, f.eks. Thunderbolt-porter).
- Debian-basert Linux med NetworkManager og `sudo`.
- Valgfritt: en enkel switch. Trengs ved flashing med zycast.

## Fasene

Skriptene ligger i [`scripts/`](scripts/README.md) og er nummerert etter fase.
Navnet sier om skriptet gjelder `pc`, `zyxel` (routerdelen) eller `modem` (Quectel-modemet).

| Fase | Hva | Skript / fremgangsmåte |
|---|---|---|
| **1 PC-oppsett** | pakker, udev-regler, sjekk | `10-pc-installer-pakker-og-udev.sh`, `11-pc-sjekk-klar.sh` |
| **2 Nedlasting** | firmware (for fase 5 / redning), zycast | [`firmware/README.md`](firmware/README.md), [`tools/README.md`](tools/README.md), `22-pc-sjekk-firmwarefil.py` |
| **3 Tilkobling** | nett mot enheten, slå på adb | `30-pc-sett-nettverkskort-mot-zyxel.sh`, [Slå på adb](#slå-på-adb) |
| **4 Kartlegging og backup** | full backup, les config | `40-zyxel-ta-backup.sh`, `41-zyxel-vis-config.py` |
| **5 Flashing (valgfri)** | bytte firmware *før* konfigurasjon | [Flashing](#flashing-valgfri), `50-…`, `51-…` |
| **6 Konfigurasjon** | lokal administrasjon, passord, APN, fjernstyring av | `61-…` + `90-…`, `60-zyxel-sett-admin-passord.sh`, `62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh` |
| **7 Verifisering** | config, innlogging, mobildata | [Verifisering](#verifisering) |
| **8 Avslutning** | PC tilbake som før | `80-pc-tilbakestill-nettverkskort.sh`, `81-pc-fjern-udev-regler.sh` |
| **9 Nødverktøy** | gjenopprett config, zycast-redning | `90-zyxel-gjenopprett-config-fra-backup.sh`, `51-…` |

### Fase 1 – PC-oppsett

```bash
sudo scripts/10-pc-installer-pakker-og-udev.sh
scripts/11-pc-sjekk-klar.sh
```

### Fase 3 – Tilkobling

Antenne → PoE-injektor → nettverkskabel til PC-en, og USB-C fra antennen til PC-en.

```bash
sudo scripts/30-pc-sett-nettverkskort-mot-zyxel.sh   # 192.168.2.4/24, enheten er 192.168.2.1
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

Innstillingen overlever omstart. Sett adb-sifferet til `0` igjen for å slå det av.

### Fase 4 – Kartlegging og backup

```bash
scripts/40-zyxel-ta-backup.sh
scripts/41-zyxel-vis-config.py backup/<tid>/zcfg_config.ORIGINAL.json
```

Backupen tar alle MTD-partisjoner unntatt `efs2` (modemets eget filsystem – å lese den
rått fikk enheten til å starte på nytt). **Kopier `backup/` til et annet sted.**

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

### Verifisering

```bash
adb shell 'timeout 5 atcmd "AT+COPS?" </dev/null'       # operatør
adb shell 'timeout 5 atcmd "AT+CGPADDR" </dev/null'     # IP fra operatøren
adb shell 'timeout 5 atcmd "AT+QENG=\"servingcell\"" </dev/null'   # bånd, RSRP, RSRQ, SINR
adb shell 'ping -c 3 1.1.1.1'                          # internett fra enheten
```

Ethernet-porten står i IP-passthrough: enheten som kobles til (egen router eller PC med DHCP)
får operatørens IP direkte.

### Fase 8 – Avslutning

```bash
sudo scripts/80-pc-tilbakestill-nettverkskort.sh
sudo scripts/81-pc-fjern-udev-regler.sh    # valgfritt
```

## Flashing (valgfri)

Telenor-firmware oppdateres bare når enheten er på Telenor-nettet. Telekom (DTAG) legger ut
sin NR7302-firmware som fil, så en enhet med DTAG-firmware kan oppdateres manuelt.

- **Fordeler:** nyere programvare og modemfirmware, mulighet for oppdateringer.
- **Ulemper:** ingen vei tilbake til operatørens firmware (den finnes ikke som fil),
  konfigurasjonen nullstilles, eSIM forsvinner trolig. Prosessen er merket «WIP» upstream.
- Flash **før** fase 6, og ta ROM-D-backup (inneholder eID) i web-grensesnittet som supervisor først.
- Fremgangsmåte og redning med zycast: se upstream-repoet og
  `51-zyxel-flash-firmware-via-zycast.sh`. På Telenor-enheter må zycast startes ca. 50–85 s
  etter strøm på (skriptet venter automatisk; standard 50 s).

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

## `zyxel_nr7302.yml`

Beskriver ønsket oppsett og alle innstillingene som er funnet, merket *verifisert* eller
*ikke testet*. **Planlagt:** skriptene leser den ikke ennå. Personlige verdier legges i
`zyxel_nr7302.local.yml`, som er git-ignorert.

## Personvern – hva som ikke er i dette repoet

Backup, logger, enhetskonfigurasjoner, firmware og lokalt bygde verktøy holdes utenfor git
(se [`.gitignore`](.gitignore)). De inneholder serienummer, IMEI, eID, sertifikater og
passord. Del aldri innholdet i `backup/` eller `logg/`.

## Kreditering

- [davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302) – funn om Telenor-oppsett,
  cross-flash, passordhenting og firmwareformat (valideringen i `22-pc-sjekk-firmwarefil.py`
  bygger på `rebuild_firmware.sh` derfra).
- zycast fra [OpenWrt firmware-utils](https://github.com/openwrt/firmware-utils) (GPL-2.0).
- Chris / xpla@lteforum.at for zycast-veiledningen, og brukerne i upstream-issuene
  (bl.a. tidsvinduet for zycast på Telenor-enheter).

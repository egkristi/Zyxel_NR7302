# Telenor → Telekom (DTAG) firmware på NR7302

🇳🇴 Norsk · [🇬🇧 English](flash-telenor-til-dtag.en.md)

Telenor-firmware oppdateres bare når enheten er på Telenor-nettet. Med et annet
operatør-SIM står du fast på den versjonen du har. Telekom (DTAG) legger ut sin
NR7302-firmware som fil, så etter en overgang kan du oppdatere manuelt.

**Gjennomført og verifisert** på én Telenor-enhet:

| | Før | Etter |
|---|---|---|
| Firmware | `1.00(ACHA.1)b3_E0` (2023) | `1.00(ACHA.5)b1_F0` (2025) |
| Modemfirmware | `RG520FEBDER03A01M8G_OCPU_ZYXEL_BETA_20230614A` | `RG520FEBDER03A01M8G_OCPU_ZYXEL` |

> [!WARNING]
> Det finnes **ingen vei tilbake** til Telenor-firmware (den finnes ikke som fil).
> Upstream kaller prosessen «WIP». Les hele dokumentet før du starter.

## Fordeler og ulemper

| Fordeler | Ulemper |
|---|---|
| Kan oppdateres manuelt fra Telekom | Ingen vei tilbake til Telenor-firmware |
| Nyere programvare og sikkerhetsrettinger | USB/adb bare tilgjengelig ca. 30 s etter oppstart (se under) |
| Nyere modemfirmware | Må stille inn APN og «Enable Customized Settings» på nytt |
| Telenors fabrikkoppsett forsvinner (hvis ROM-D slettes) | eSIM-støtte forsvinner trolig |

Forvent ikke høyere hastighet i seg selv. Se [Ytelse og operatører](ytelse-og-operatorer.md).

## Forberedelser

1. **Full backup** (fase 4): `scripts/40-zyxel-ta-backup.sh`. Tar også rå kopi av `rom-d` (eID).
2. **Kjent supervisor-passord:** `scripts/60-zyxel-sett-admin-passord.sh '<passord>' --alle`.
3. **Config-backup i web-grensesnittet:** Maintenance → Backup/Restore → Backup.
4. **Firmware lastet ned og validert:** `scripts/20-pc-last-ned-telekom-firmware.sh`
   (må vise `RESULTAT: OK`).
5. **Redning klar:** `scripts/21-pc-bygg-zycast.sh`, en switch, og fil i `firmware/`.
6. **USB tilkoblet** under hele prosessen.

## Upstream-oppskriften

Fra [davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302#cross-flashing):

1. Logg inn som **supervisor**.
2. Maintenance → Backup/Restore → **ROM-D: Backup** (inneholder eID).
3. **Clear ROM-D**.
4. Maintenance → Firmware Upgrade → huk av **«Restore Default Settings After Firmware Upgrade»**
   → last opp `.bin` (ikke Safari).
5. Vent. Ikke kutt strømmen mens LED-ene blinker.

## Slik gikk det i praksis

Vi lastet opp firmwaren **uten** «Restore Default Settings» og **uten** Clear ROM-D.
Det fungerte, men ga et par ekstra steg:

| Tid | Observasjon |
|---|---|
| 0–2 min | Opplasting. Siden blir blank (web-grensesnittet stopper). Normalt. |
| ~2 min | USB forsvinner. Link på nettverkskabelen er oppe. |
| ~10 min | **Begge LED-er fast grønt** = flashing ferdig. Enheten svarer på ARP, men ingen tjenester (web, SSH) er oppe. |
| ~15 min | Ingen fremgang. **Strømmen trukket i 10 s og satt i igjen** (trygt når LED-ene har vært fast grønne en stund). |
| +1 min | Ny firmware kjører. **Config ble beholdt**: LAN fortsatt `192.168.2.1`, passord og administrasjonsinnstillinger som før. |
| etterpå | **WAN nede.** Se «Etter flashing» under. |

## Etter flashing

1. **LAN-adresse.** Med config beholdt: samme som før (Telenor: `192.168.2.1`).
   Med «Restore Default Settings» forventes DTAG-standard, trolig `192.168.1.1` (ikke verifisert).
   PC-en kan ha adresse i begge nett samtidig:
   `sudo ip addr add 192.168.1.4/24 dev <kort>`.
2. **«Enable Customized Settings»** (forsiden): står i Telekom-modus, som bruker Telekoms
   forhåndsdefinerte oppsett. Må slås over for å bruke andre operatører.
   Upstream [issue #4](https://github.com/davidohne/Zyxel_NR7302/issues/4) beskriver en
   enhet som gikk i oppstartsløkke etter denne endringen. Hos oss gikk det bra, men ha
   zycast-redning klar.
3. **APN.** Broadband → Cellular APN: profil 1 (Cellular WAN 1, standard-gateway) sto på
   **Auto** uten APN. Sett **Manual**, din operatørs APN (f.eks. `ice.net`), Auth None, IPv4.
4. **SIM-PIN** må skrives inn på nytt etter hvert SIM-bytte.
5. **Fjernstyring.** Kontroller at alt er av (config fra Telenor-firmwaren ble med):
   - Maintenance → TR-069 Client: CWMP Active av, Inform av, ACS URL tom.
   - TR-369 Local Agent: MQTT-klienter `false`, Agent-MTP `false`, Controller `false`.
     (Telenors MQTT-oppføringer ligger igjen som avslått og kan slettes.)
   - Remote Management → MGMT Services for IP Passthrough: alle PT-tjenester av.
6. **ROM-D** er fortsatt Telenors hvis den ikke ble slettet. Har bare betydning ved en
   senere fabrikktilbakestilling.

### USB/adb med DTAG-firmware

USB (og dermed adb) er bare tilgjengelig i **ca. 30 sekunder** etter oppstart; deretter
slår firmwaren av USB helt. Innstillingen for adb (`usbcfg`) overlevde flashingen, men
vinduet er kort. Bruk:

```bash
scripts/33-zyxel-fang-adb-ved-oppstart.sh     # start, og slå så av/på strømmen
```

## Gjenoppretting

| Situasjon | Tiltak |
|---|---|
| Fast grønt, men ingen tjenester etter 10–15 min | Trekk strømmen 10 s og sett den i igjen |
| Oppstartsløkke, web svarer ikke | Hold reset-knappen inne når status-LED lyser fast rødt (upstream issue #4) |
| Ingenting hjelper | Flash på nytt med zycast: `sudo scripts/50-pc-sett-nettverkskort-for-zycast.sh` og `sudo scripts/51-zyxel-flash-firmware-via-zycast.sh firmware/<fil>.bin`. Telenor-enheter tar imot i et vindu ca. 50–85 s etter strøm på (skriptet venter 50 s som standard; prøv 55, 60 …) |

## Oppdatere senere

Last ned ny fil fra Telekom (`scripts/20-…`), valider (`22-…`) og last opp i Maintenance →
Firmware Upgrade. Uten «Restore Default Settings» beholdes innstillingene; sjekk likevel APN,
PLMN og fjernstyring etterpå.

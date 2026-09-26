# Ytelse, måling og operatører

🇳🇴 Norsk · [🇬🇧 English](ytelse-og-operatorer.en.md)

Erfaringer fra feilsøking av lav hastighet på NR7302 med norsk mobilabonnement.

## Kort oppsummert

| Oppsett | Nedlasting | Opplasting |
|---|---|---|
| Ice-SIM (abonnement **Data Frihet**), Telenor-firmware | ~25 Mbit/s | ~25 Mbit/s |
| Ice-SIM (Data Frihet), DTAG-firmware ACHA.5 | ~25 Mbit/s | ~25 Mbit/s |
| **Telia-SIM**, samme antenne og plassering | ~230 Mbit/s | – |

Hastigheten var flat ~25 Mbit/s **begge veier** uansett LTE-anker (B20 eller B3), med 5G n78
tilkoblet, over HTTP og HTTPS, med én eller flere strømmer, fra PC-en eller fra enheten selv,
og på både gammel og ny firmware. Årsaken er abonnementet: Ice oppgir at
[Data Frihet har teoretisk hastighet begrenset til 25 Mbps](https://www.ice.no/bedrift/kundeservice/ofte-stilte-sporsmal/internett-pa-mobilen-er-for-tregt-eller-virker-ikke/).

Et flatt tak som er likt begge veier og uavhengig av radioforhold, peker nesten alltid på en
begrensning i abonnementet eller nettet, ikke på antennen. Test med et SIM fra en annen
operatør før du bruker tid på firmware og innstillinger.

Grensen kan ikke omgås med innstillinger på antennen. Mer hastighet krever et annet
abonnement eller en annen operatør.

## Måle riktig

Vanlige feilkilder under testingen:

- **WiFi tar standardruten.** Er PC-en også på WiFi, går nettleser-speedtester ofte der.
  Kablet nett fra antennen får typisk høyere metric enn WiFi.
- **Fast IP uten gateway** (`30-pc-sett-nettverkskort-mot-zyxel.sh`) gir administrasjons-
  tilgang, men ingen internettrute via antennen. Kjør `80-…` for DHCP fra antennen.
- **Sjekk hvem som leverer trafikken:** `curl --interface <kort> https://ipinfo.io/json`
  viser operatørens AS (Ice vises som «Lyse Tele AS»).

Bruk skriptet, som tvinger trafikken ut på kablet kort og måler ping under last:

```bash
scripts/71-pc-mal-hastighet-og-ping-via-zyxel.sh
```

Med adb kan man også laste ned direkte på enheten (`adb shell curl -o /dev/null …`), som
utelukker PC-en og nettverksoppsettet helt.

## Radio: bånd og 5G

```bash
adb shell 'timeout 5 atcmd "AT+QCAINFO" </dev/null'              # aktive bærere
adb shell 'timeout 5 atcmd "AT+QENG=\"servingcell\"" </dev/null'   # LTE + NR5G-NSA-linje
```

- NR7302 bruker 5G **NSA**: et LTE-anker (f.eks. B20 eller B3) + n78. n78-delen vises
  først når det går trafikk.
- Web-grensesnittets «Cellular Lock (LTE)» → Scan viser hvilke celler og operatører
  (MNC) som finnes der antennen står. Nyttig for å se hvilke LTE-bånd operatøren har.
- Med utmerket signal (SINR > 20 dB) gir sikting av antennen lite. Se heller på
  abonnement og operatør.

## Ping under last (bufferbloat)

Til spilling er stabil ping viktigere enn båndbredde. Målt:

| Oppsett | Ping uten last | Ping under last |
|---|---|---|
| Ice 25 Mbit/s, IP-passthrough | ~25 ms | +3–5 ms |
| Ice 25 Mbit/s, router-modus | ~25–39 ms | opptil ~280 ms |
| Telia ~230 Mbit/s | ~32 ms | ~268 ms |

Anbefaling: en egen router bak antennen med **SQM (cake/fq_codel)** satt litt under målt
kapasitet (f.eks. 22–23 Mbit/s på et 25 Mbit/s-abonnement). Da holder pingen seg lav selv
når andre laster ned.

## Holde enheten på operatørens eget nett

Tips (fra en Ice-ansatt, for routere generelt) for å unngå at routeren bruker nasjonal
roaming på et annet nett, der kvoten kan gå fort:

| Tiltak | Hvor på NR7302 |
|---|---|
| APN satt manuelt (Ice: `ice.net`) | Broadband → Cellular APN |
| Velg operatør manuelt (Ice: `ice+`, PLMN 24214) | Broadband → Cellular PLMN → slå av «PLMN Auto Selection» |
| Data Roaming av | Broadband → Cellular WAN |
| Ingen automatiske oppdateringer | TR-069 av (se hoved-README); oppdater manuelt |

Ulempe: faller operatørens egen celle ut, blir du stående uten forbindelse i stedet for å
roame. APN-typen `default,supl` er en telefoninnstilling og finnes ikke på NR7302.

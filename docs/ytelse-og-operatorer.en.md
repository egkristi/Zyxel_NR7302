# Performance, measurement and operators

[🇳🇴 Norsk](ytelse-og-operatorer.md) · 🇬🇧 English

Experience from troubleshooting low speed on the NR7302 with a Norwegian mobile subscription.

## Summary

| Setup | Download | Upload |
|---|---|---|
| Ice SIM (subscription **Data Frihet**), Telenor firmware | ~25 Mbit/s | ~25 Mbit/s |
| Ice SIM (Data Frihet), DTAG firmware ACHA.5 | ~25 Mbit/s | ~25 Mbit/s |
| **Telia SIM**, same antenna and location | ~230 Mbit/s | – |

Speed was a flat ~25 Mbit/s **both ways** regardless of LTE anchor (B20 or B3), with 5G n78
connected, over HTTP and HTTPS, with one or several streams, from the PC or from the device
itself, and on both old and new firmware. The cause is the subscription: Ice states that
[Data Frihet has a theoretical speed limited to 25 Mbps](https://www.ice.no/bedrift/kundeservice/ofte-stilte-sporsmal/internett-pa-mobilen-er-for-tregt-eller-virker-ikke/).

A flat cap that is the same both ways and independent of radio conditions almost always points
to a limit in the subscription or the network, not the antenna. Test with a SIM from another
operator before spending time on firmware and settings.

The limit cannot be worked around with settings on the antenna. More speed requires a
different subscription or a different operator.

## Measuring correctly

Common sources of error during testing:

- **WiFi takes the default route.** If the PC is also on WiFi, browser speed tests often go
  there. The wired network from the antenna typically gets a higher metric than WiFi.
- **Static IP without a gateway** (`30-pc-sett-nettverkskort-mot-zyxel.sh`) gives management
  access, but no internet route via the antenna. Run `80-…` for DHCP from the antenna.
- **Check who delivers the traffic:** `curl --interface <interface> https://ipinfo.io/json`
  shows the operator's AS (Ice shows up as "Lyse Tele AS").

Use the script, which forces traffic out through the wired interface and measures ping under load:

```bash
scripts/71-pc-mal-hastighet-og-ping-via-zyxel.sh
```

With adb you can also download directly on the device (`adb shell curl -o /dev/null …`),
which rules out the PC and the network setup completely.

## Radio: bands and 5G

```bash
adb shell 'timeout 5 atcmd "AT+QCAINFO" </dev/null'              # active carriers
adb shell 'timeout 5 atcmd "AT+QENG=\"servingcell\"" </dev/null'   # LTE + NR5G-NSA line
```

- The NR7302 uses 5G **NSA**: an LTE anchor (e.g. B20 or B3) + n78. The n78 part only
  shows up while there is traffic.
- The web UI's "Cellular Lock (LTE)" → Scan shows which cells and operators (MNC) exist
  where the antenna is. Useful for seeing which LTE bands the operator has.
- With excellent signal (SINR > 20 dB), aiming the antenna gains little. Look at the
  subscription and operator instead.

## Ping under load (bufferbloat)

For gaming, stable ping matters more than bandwidth. Measured:

| Setup | Idle ping | Ping under load |
|---|---|---|
| Ice 25 Mbit/s, IP passthrough | ~25 ms | +3–5 ms |
| Ice 25 Mbit/s, router mode | ~25–39 ms | up to ~280 ms |
| Telia ~230 Mbit/s | ~32 ms | ~268 ms |

Recommendation: a separate router behind the antenna with **SQM (cake/fq_codel)** set a little
below the measured capacity (e.g. 22–23 Mbit/s on a 25 Mbit/s subscription). Ping then stays
low even when others are downloading.

## Keeping the device on the operator's own network

Tips (from an Ice employee, for routers in general) to avoid the router using national
roaming on another network, where the data allowance can run out quickly:

| Measure | Where on the NR7302 |
|---|---|
| APN set manually (Ice: `ice.net`) | Broadband → Cellular APN |
| Choose the operator manually (Ice: `ice+`, PLMN 24214) | Broadband → Cellular PLMN → turn off "PLMN Auto Selection" |
| Data Roaming off | Broadband → Cellular WAN |
| No automatic updates | TR-069 off (see the main README); update manually |

Downside: if the operator's own cell drops out, you are left without a connection instead
of roaming. The APN type `default,supl` is a phone setting and does not exist on the NR7302.

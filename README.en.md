# Zyxel NR7302 – operator-independent use

[🇳🇴 Norsk](README.md) · 🇬🇧 English

Scripts and a step-by-step process for taking control of an **operator-locked Zyxel NR7302**
(outdoor 5G antenna/router) from a Linux PC, so it can be used with **any mobile operator**,
managed locally, and no longer remotely managed by the original operator.

Developed and verified on a **Telenor (Norway) NR7302** (firmware `1.00(ACHA.1)b3_E0`) with SIM
cards from **Ice** and **Telia**, on **Linux Mint 22.3** (Ubuntu 24.04 base). The device was
later cross-flashed to Deutsche Telekom firmware `1.00(ACHA.5)b1_F0`. Builds on the findings in
[davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302).

Script names, messages and the detailed docs are in Norwegian; this page is an English summary.

> [!WARNING]
> You are modifying the device's internal configuration and can soft-brick it. Take the
> backup in phase 4 before changing anything. Everything is at your own risk.

## What you get

| Before (Telenor) | After |
|---|---|
| Configuration is reset on every reboot | Changes persist |
| Web UI and SSH only reachable from the operator side (WAN) | Reachable from your LAN |
| No known accounts/passwords | Known admin password you change yourself |
| Operator APN, only works on Telenor | Your operator's APN (verified with Ice and Telia) |
| Remotely managed (TR-069, TR-369/USP over MQTT) | Remote management disabled |
| Firmware only updated via the operator network | Optional: Telekom firmware that can be updated manually |

## Requirements

- **NR7302 with a USB-C port** (Telenor units have it; others may need soldering, see upstream).
- The PoE injector, an Ethernet cable and a **USB-C data cable** (use a USB-A port on the PC if
  the USB-C/Thunderbolt port does not enumerate the device).
- Debian-based Linux with NetworkManager and `sudo`.
- Optional: a small switch (needed for zycast recovery).

## Phases

Scripts live in [`scripts/`](scripts/README.md), numbered by phase. The name says whether the
script targets the `pc`, `zyxel` (router part) or `modem` (Quectel modem), and the verb whether
it changes something (`sett` = set, `flash`, `gjenopprett` = restore) or only reads
(`sjekk` = check, `vis` = show).

| Phase | Purpose | Scripts |
|---|---|---|
| 1 PC setup | packages, udev rules, readiness check | `10-…`, `11-…`, `12-…` |
| 2 Downloads | Telekom firmware, zycast, validation | `20-…`, `21-…`, `22-…` |
| 3 Connect | static IP towards the device, enable adb, check | `30-…`, `32-…`, `33-…` |
| 4 Backup | raw flash backup (all MTD except `efs2`), config, modem status | `40-…`, `41-…`, `42-…` |
| 5 Flash (optional) | Telenor → Telekom firmware, *before* phase 6 | `50-…`, `51-…`, [docs](docs/flash-telenor-til-dtag.md) |
| 6 Configure | local management, known password, APN, operator remote management off | `60-…`, `61-…`, `62-…`, `90-…` |
| 7 Verify | config, login, mobile data, speed and latency under load | `70-…`, `42-…`, `71-…` |
| 8 Clean up | restore the PC's network settings, remove udev rules | `80-…`, `81-…` |
| 9 Recovery | write back a config backup, zycast re-flash | `90-…`, `50-…` + `51-…` |

### Enabling adb (Telenor firmware)

The USB port initially exposes only the modem's AT port and RmNet. adb is enabled by flipping
only the adb flag in the Quectel USB configuration:

```bash
sudo scripts/lib/modem-at.py 'AT+QCFG="usbcfg"'
# e.g.  +QCFG: "usbcfg",0x2C7C,0x0801,0,0,0,1,1,0,0   (VID,PID,diag,nmea,at,modem,rmnet,adb,uac)
sudo scripts/lib/modem-at.py 'AT+QCFG="usbcfg",0x2C7C,0x0801,0,0,0,1,1,1,0'
```

Keep the modem port enabled so the change can be reverted. Power-cycle, then `adb shell id`
should show root. With Telekom firmware, USB is only available for ~30 s after boot; use
`scripts/33-zyxel-fang-adb-ved-oppstart.sh`.

## Key findings

- Telenor firmware puts the LAN on **192.168.2.1** and resets the config on every boot
  (`BootFromFactoryDefault=true`); the config is only complete ~2 minutes after boot.
- The device encrypts password fields itself at boot, so a known password can be set by writing
  it into the config and rebooting. Existing passwords cannot be read back.
- Operator remote management channels: TR-069, TR-369/USP over MQTT (full data-model access),
  and WAN-side management in IP passthrough (ports 200xx). All can be disabled.
- Telenor's root SSH key is re-installed from the `factory` partition on every boot; harmless
  while SSH is LAN-only.
- Do not read the `efs2` partition raw (it rebooted the device), and do not run `zcmd` without
  arguments (it starts a second config daemon).
- **Cross-flash to Telekom firmware worked** without "Restore Default Settings" and without
  clearing ROM-D; the config was kept, a power cycle was needed after the LEDs turned solid
  green, and the APN and "Enable Customized Settings" had to be set afterwards.
  See [docs/flash-telenor-til-dtag.md](docs/flash-telenor-til-dtag.md) (Norwegian).
- **A flat speed cap that is identical up and down is almost always the subscription.**
  Ice's *Data Frihet* plan is limited to 25 Mbit/s; a Telia SIM in the same antenna reached
  ~230 Mbit/s. For gaming, use SQM (cake) on a router behind the antenna to keep latency low
  under load. See [docs/ytelse-og-operatorer.md](docs/ytelse-og-operatorer.md) (Norwegian).

## Privacy

Backups, logs, device configs, firmware and locally built tools are excluded by
[`.gitignore`](.gitignore); they contain serial number, IMEI, eID, certificates and passwords.
Screenshots of the web UI status pages show IMEI, IMSI, ICCID and GPS position.

## License

MIT – see [LICENSE.md](LICENSE.md). zycast (GPL-2.0) is not included; it is downloaded and built
locally.

## Credits

- [davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302) – Telenor findings,
  cross-flashing, password retrieval and firmware format.
- zycast from [OpenWrt firmware-utils](https://github.com/openwrt/firmware-utils) (GPL-2.0).
- Chris / xpla@lteforum.at for the zycast guide, and the upstream issue authors.

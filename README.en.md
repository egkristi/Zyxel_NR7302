# Zyxel NR7302 – operator-independent use

[🇳🇴 Norsk](README.md) · 🇬🇧 English · 📖 [Documentation site](https://egkristi.github.io/Zyxel_NR7302/en/)

Scripts and a step-by-step process for taking control of an **operator-locked Zyxel NR7302**
(outdoor 5G antenna/router) from a Linux PC, so it can be used with **any mobile operator**,
managed locally, and no longer remotely managed by the operator.

Developed and verified on a **Telenor (Norway) NR7302** (firmware `1.00(ACHA.1)b3_E0`) with SIM
cards from **Ice** and **Telia**, on **Linux Mint 22.3** (Ubuntu 24.04 base). The device was
later flashed to Deutsche Telekom firmware `1.00(ACHA.5)b1_F0`. Builds on the findings in
[davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302).

> [!WARNING]
> You are modifying the device's internal configuration and can, at worst, make it unusable
> (soft-brick). Take the backup in phase 4 before changing anything, and read a whole phase
> before running it. Everything is at your own risk.

## What you get

| Before (Telenor) | After |
|---|---|
| Configuration is reset on every reboot | Changes persist |
| Web UI and SSH only reachable from the operator side (WAN) | Reachable from your own LAN |
| No known accounts/passwords | Known admin password that you change yourself |
| Operator APN, only works on Telenor | Your operator's APN (verified with Ice and Telia) |
| Remotely managed by the operator (TR-069, TR-369/USP over MQTT) | Remote management turned off |
| Firmware only updated via the operator's network | Optional: Telekom firmware that can be updated manually ([docs](docs/flash-telenor-til-dtag.en.md)) |

## Requirements

- **Zyxel NR7302 with a USB-C port.** Telenor units have the port fitted. Other variants
  (e.g. Telekom, A1) often do not; see the upstream repo for soldering.
- The PoE injector that belongs to the antenna, an Ethernet cable and a **USB-C cable that
  carries data** (use a USB-A port on the PC if the USB-C port does not work, e.g. Thunderbolt ports).
- Debian-based Linux with NetworkManager and `sudo`.
- Optional: a simple switch. Needed for flashing with zycast.

## The phases

The scripts live in [`scripts/`](scripts/README.en.md) and are numbered by phase.
Script names and messages are in Norwegian. The name says whether a script targets the `pc`,
`zyxel` (the router part) or `modem` (the Quectel modem), and the verb whether it changes
something or only reads:

| Changes something | Only reads / only writes local files |
|---|---|
| `sett` (set), `flash`, `gjenopprett` (restore), `tilbakestill` (reset), `fjern` (remove), `installer` (install) | `sjekk` (check), `vis` (show), `ta-backup` (take backup), `lag` (create), `fang` (catch), `mal` (measure), `last-ned` (download), `bygg` (build) |

| Phase | What | Scripts / procedure |
|---|---|---|
| **1 PC setup** | packages, udev rules, check | `10-pc-installer-pakker.sh`, `11-pc-sett-udev-regler.sh`, `12-pc-sjekk-klar.sh` |
| **2 Downloads** | Telekom firmware, zycast | `20-pc-last-ned-telekom-firmware.sh`, `21-pc-bygg-zycast.sh`, `22-pc-sjekk-firmwarefil.py` |
| **3 Connect** | network to the device, adb | `30-pc-sett-nettverkskort-mot-zyxel.sh`, [Enable adb](#enable-adb), `32-zyxel-sjekk-tilkobling.sh`, `33-zyxel-fang-adb-ved-oppstart.sh` |
| **4 Survey and backup** | full backup, read config and modem | `40-zyxel-ta-backup.sh`, `41-zyxel-vis-config.py`, `42-modem-vis-status.sh` |
| **5 Flashing (optional)** | Telekom firmware *before* configuration | [docs/flash-telenor-til-dtag.en.md](docs/flash-telenor-til-dtag.en.md), `50-…`, `51-…` |
| **6 Configuration** | local management, password, APN, remote management off | `61-…` + `90-…`, `60-zyxel-sett-admin-passord.sh`, `62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh` |
| **7 Verification** | config, login, mobile data, speed | `70-zyxel-verifiser-config-og-innlogging.sh`, `42-modem-vis-status.sh`, `71-pc-mal-hastighet-og-ping-via-zyxel.sh` |
| **8 Wrap-up** | PC back as it was | `80-pc-tilbakestill-nettverkskort.sh`, `81-pc-fjern-udev-regler.sh` |
| **9 Recovery** | restore config, zycast rescue | `90-zyxel-gjenopprett-config-fra-backup.sh`, `50-…` + `51-…` |

### Phase 1 – PC setup

```bash
sudo scripts/10-pc-installer-pakker.sh
sudo scripts/11-pc-sett-udev-regler.sh     # unplug and replug the USB cable afterwards
scripts/12-pc-sjekk-klar.sh
```

### Phase 2 – Downloads

```bash
scripts/20-pc-last-ned-telekom-firmware.sh   # opens the browser if telekom.de blocks scripts
scripts/21-pc-bygg-zycast.sh
```

Firmware and zycast are only needed for phase 5 and for rescue, but should be ready before you start.

### Phase 3 – Connect

Antenna → PoE injector → Ethernet cable to the PC, and USB-C from the antenna to the PC.

```bash
sudo scripts/30-pc-sett-nettverkskort-mot-zyxel.sh   # 192.168.2.4/24, the device is 192.168.2.1
scripts/32-zyxel-sjekk-tilkobling.sh
```

The Telenor firmware has its LAN on **192.168.2.1**, not 192.168.1.1. The PC gets no gateway,
so internet keeps going over WiFi.

#### Enable adb

On the Telenor unit the USB port only exposes the modem's AT port and RmNet. adb is enabled
with one AT command that only changes the adb flag in the USB configuration:

```bash
sudo scripts/lib/modem-at.py 'AT+QCFG="usbcfg"'
# Example reply:     +QCFG: "usbcfg",0x2C7C,0x0801,0,0,0,1,1,0,0
#   order:           VID, PID, diag, nmea, at, modem, rmnet, adb, uac
sudo scripts/lib/modem-at.py 'AT+QCFG="usbcfg",0x2C7C,0x0801,0,0,0,1,1,1,0'   # adb = 1, rest unchanged
```

Use the values from your own reply and only change the adb digit (second to last). Keep the
modem port, or you lose AT access. Restart the device (pull the PoE power), then check:

```bash
adb devices -l
adb shell id        # should show uid=0(root)
```

The setting survives reboots and firmware changes. Set the adb digit back to `0` to disable
it. **With Telekom firmware** USB is only available for about 30 s after boot; use
`33-zyxel-fang-adb-ved-oppstart.sh`.

### Phase 4 – Survey and backup

```bash
scripts/40-zyxel-ta-backup.sh
scripts/41-zyxel-vis-config.py backup/<time>/zcfg_config.ORIGINAL.json
scripts/42-modem-vis-status.sh
```

The backup takes every MTD partition except `efs2` (the modem's own file system – reading it
raw made the device reboot). **Copy `backup/` somewhere else.**

### Phase 5 – Flashing (optional)

Separate guide: **[docs/flash-telenor-til-dtag.en.md](docs/flash-telenor-til-dtag.en.md)**.
Do this *before* phase 6, since new firmware can reset the settings.

### Phase 6 – Configuration

Order matters: local management first (otherwise everything is reset on the next reboot).

```bash
# 6a: keep changes, DHCP, HTTPS/SSH on LAN, enable admin/supervisor (values from zyxel_nr7302.yml)
scripts/61-zyxel-lag-config-lokal-administrasjon.py backup/<time>/zcfg_config.ORIGINAL.json backup/<time>/zcfg_config.LOKAL.json
scripts/90-zyxel-gjenopprett-config-fra-backup.sh backup/<time>/zcfg_config.LOKAL.json

# 6b: known admin password (default: the serial number on the label), tested by logging in
scripts/60-zyxel-sett-admin-passord.sh            # or: ... 'OwnPassword' [--alle]

# 6c: your operator's APN and operator remote management off (insert the SIM first)
scripts/62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh ice.net      # Ice; Telia: telia
```

The scripts that write config to the device (`60`, `62`, `90`) put the new file next to the
old one, verify its md5 and swap it in with a single atomic `mv`, so a power loss midway cannot
leave a half-written config. They then reboot the device and wait until the config is complete
(uptime ≥ 150 s) before verifying.

Log in at `https://192.168.2.1` and change the password under Maintenance → User Account.
If the SIM card has a PIN, it must be entered in the web UI after every SIM change.

### Phase 7 – Verification

```bash
scripts/70-zyxel-verifiser-config-og-innlogging.sh   # config against zyxel_nr7302.yml, and web UI (via adb)
scripts/42-modem-vis-status.sh                       # SIM, operator, APN, IP, signal
scripts/71-pc-mal-hastighet-og-ping-via-zyxel.sh     # speed and ping under load
```

`71` needs the PC to get its address from the antenna (DHCP, `80-…`) and forces traffic out
through the wired interface, so WiFi does not affect the measurement. See
[docs/ytelse-og-operatorer.en.md](docs/ytelse-og-operatorer.en.md) for interpretation,
subscription limits and bufferbloat.

### Phase 8 – Wrap-up

```bash
sudo scripts/80-pc-tilbakestill-nettverkskort.sh
sudo scripts/81-pc-fjern-udev-regler.sh    # optional
```

## Technical findings

- `BootFromFactoryDefault=true` makes the configuration be rebuilt on every boot, and it is
  only complete **about 2 minutes** after boot. Do not read it before then.
- The device encrypts password fields itself at boot. A password can therefore be set by
  writing it into the configuration and rebooting; the existing one cannot be read back.
- The operator has three remote management channels: TR-069 (CWMP), TR-369/USP over MQTT
  (full access to the whole data model) and WAN-side management in passthrough (ports 200xx).
- Telenor's root SSH key is re-installed from the `factory` partition on every boot.
  Harmless as long as SSH is only open on the LAN and WAN management is off.
- Do not run the device's `zcmd` without arguments: it starts a second configuration daemon.
- The Telenor setup uses two APN profiles (management and customer traffic). Both get your
  operator's APN; typically the operator hands out an IP on one of them.
- A hung AT channel on the device (`atcmd` gets "COMMAND TIMEOUT") is fixed by rebooting.
- Telekom firmware: USB/adb only ~30 s after boot, "Enable Customized Settings" must be
  switched, APN profile 1 is set to *Auto* and must be set manually. Details in the
  [docs](docs/flash-telenor-til-dtag.en.md).
- **A flat speed cap that is the same both ways is almost always the subscription**, not the
  antenna. Ice's *Data Frihet* is limited to 25 Mbit/s; a Telia SIM in the same antenna gave
  ~230 Mbit/s. See [docs/ytelse-og-operatorer.en.md](docs/ytelse-og-operatorer.en.md).

## `zyxel_nr7302.yml`

Describes the desired setup and every setting found, marked *verifisert* (verified) or
*ikke testet* (not tested). All verified settings are read by the scripts:

| Keys | Used by |
|---|---|
| `pc.*` (interface, addresses) | `12`, `30`, `32`, `50`, `51`, `60`, `70`, `71`, `80` |
| `system`, `lan`, `administrasjon.https/ssh/ssh_passordinnlogging`, `kontoer` | `61` writes, `70` checks |
| `fjernstyring.*`, `administrasjon.wan_admin_i_passthrough` | `62` writes, `70` checks |
| `mobil.apn`, `mobil.apn_profiler` | `62` |
| `passord.admin` | `60` |

`null` means "leave unchanged" (and do not check). Arguments and environment variables take
precedence. Personal values go in `zyxel_nr7302.local.yml`, which is layered on top and
git-ignored. Every key is explained in English in [docs/konfigurasjon.en.md](docs/konfigurasjon.en.md).

```yaml
mobil:
  apn: ice.net
passord:
  admin: "MyOwnPassword"
```

## Privacy – what is not in this repo

Backups, logs, device configurations, firmware and locally built tools are kept out of git
(see [`.gitignore`](.gitignore)). They contain serial number, IMEI, eID, certificates and
passwords. Never share the contents of `backup/` or `logg/`. Screenshots of the web UI status
pages show IMEI, IMSI, ICCID and GPS position – do not publish them.

## Development and tests

The tests run without a device, against a made-up config in `tests/fixtures/` and a fake `adb`:

```bash
python3 -m unittest discover -s tests -v
shellcheck scripts/*.sh scripts/lib/*.sh
```

GitHub Actions runs both on every push and publishes the
[documentation site](https://egkristi.github.io/Zyxel_NR7302/en/) from `docs/` and the README
files (MkDocs Material, `mkdocs.yml`).

## License

MIT – see [LICENSE.md](LICENSE.md). zycast (GPL-2.0) is not included; it is downloaded and
built locally.

## Credits

- [davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302) – findings on the Telenor
  setup, cross-flashing, password retrieval and firmware format (the validation in
  `22-pc-sjekk-firmwarefil.py` builds on `rebuild_firmware.sh` from there).
- zycast from [OpenWrt firmware-utils](https://github.com/openwrt/firmware-utils) (GPL-2.0).
- Chris / xpla@lteforum.at for the zycast guide, and the users in the upstream issues
  (among other things the zycast timing window on Telenor units).

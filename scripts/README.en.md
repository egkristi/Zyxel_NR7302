# Scripts

[🇳🇴 Norsk](README.md) · 🇬🇧 English

The scripts are numbered by phase, and the name says **where** something happens and
**whether** anything is changed. Script names and messages are in Norwegian.

## Naming rule

```
<phase><step>-<target>-<action>[-<object>]
```

| Part | Meaning |
|---|---|
| **phase** (first digit) | 1 PC setup · 2 downloads · 3 connect · 4 survey/backup · 5 flashing (optional) · 6 configuration · 7 verification · 8 wrap-up · 9 recovery |
| **target** | `pc` = the Linux machine · `zyxel` = the router part of the NR7302 (config, web UI, adb) · `modem` = the Quectel modem inside (AT commands) |
| **action** | `sjekk` (check), `vis` (show), `ta-backup` (take backup), `lag` (create), `fang` (catch), `mal` (measure), `last-ned` (download), `bygg` (build) **change nothing on the device**. `sett` (set), `aktiver` (enable), `flash`, `gjenopprett` (restore), `tilbakestill` (reset), `fjern` (remove) **make changes** |

Scripts that must be run with `sudo` say so themselves. Everything fetched from the device
ends up in `backup/` and `logg/` (logs), which never go into git.

## Overview

| Phase | Script | Target | Changes? | What |
|---|---|---|---|---|
| 1 | `10-pc-installer-pakker.sh` | PC | yes (sudo) | apt packages the scripts need |
| 1 | `11-pc-sett-udev-regler.sh` | PC | yes (sudo) | udev rules for adb without sudo, ModemManager exception for the modem |
| 1 | `12-pc-sjekk-klar.sh` | PC | no | checks packages, udev, zycast, network interface, firmware files |
| 2 | `20-pc-last-ned-telekom-firmware.sh` | PC | no* | fetches NR7302 firmware from Telekom (browser if blocked), unpacks and validates |
| 2 | `21-pc-bygg-zycast.sh` | PC | no* | downloads and compiles zycast into `tools/` |
| 2 | `22-pc-sjekk-firmwarefil.py` | PC | no | validates a firmware .bin (ZIP, MD5 in fotaconfig.xml, model ID 0x7302) |
| 3 | `30-pc-sett-nettverkskort-mot-zyxel.sh` | PC | yes (sudo) | static IP towards the device's LAN, no gateway |
| 3 | `32-zyxel-sjekk-tilkobling.sh` | zyxel | no | USB, adb/root, ping, web, SSH |
| 3 | `33-zyxel-fang-adb-ved-oppstart.sh` | zyxel | no | waits for the adb window at boot (Telekom firmware) and fetches config + modem status |
| 4 | `40-zyxel-ta-backup.sh` | zyxel | no | raw flash backup of all partitions (except `efs2`) and `/xdata` |
| 4 | `41-zyxel-vis-config.py` | zyxel | no | shows relevant fields from a `zcfg_config.json` |
| 4 | `42-modem-vis-status.sh` | modem | no | SIM, operator, registration, APN, IP, serving cell (via adb) |
| 5 | `50-pc-sett-nettverkskort-for-zycast.sh` | PC | yes (sudo) | network setup for zycast, turns WiFi off |
| 5 | `51-zyxel-flash-firmware-via-zycast.sh` | zyxel | **yes** (sudo) | flashes a .bin with zycast, waits for the right time window |
| 6 | `60-zyxel-sett-admin-passord.sh` | zyxel | **yes** | sets a known admin password (default: the serial number) and tests logging in |
| 6 | `61-zyxel-lag-config-lokal-administrasjon.py` | zyxel | no** | creates a config with local management (values from `zyxel_nr7302.yml`) |
| 6 | `62-zyxel-sett-apn-og-slaa-av-fjernstyring.sh` | zyxel | **yes** | APN (argument or `mobil.apn` in yml) + operator remote management per `fjernstyring.*` in yml, verifies after reboot |
| 7 | `70-zyxel-verifiser-config-og-innlogging.sh` | zyxel | no | checks the device config against `zyxel_nr7302.yml`, and the web UI |
| 7 | `71-pc-mal-hastighet-og-ping-via-zyxel.sh` | PC | no | speed and ping under load, forced out through the wired interface |
| 8 | `80-pc-tilbakestill-nettverkskort.sh` | PC | yes (sudo) | interface back to NetworkManager/DHCP, WiFi back on |
| 8 | `81-pc-fjern-udev-regler.sh` | PC | yes (sudo) | removes the udev rules from phase 1 (packages are kept) |
| 9 | `90-zyxel-gjenopprett-config-fra-backup.sh` | zyxel | **yes** | writes a `zcfg_config.json` to the device (atomic, md5-checked), reboots and waits until it is ready |

\* Only writes files locally on the PC.
\*\* `61` only writes a file locally. It is put on the device with `90-…`. Can be run
repeatedly; values that are already correct are skipped.

### `lib/` – helpers (run by other scripts or by hand)

| File | What |
|---|---|
| `lib/felles.sh` | shared functions: atomic config write (`adb_skriv_config`), reboot and wait (`adb_omstart_og_vent`), private backup folders, interface selection, values from yml |
| `lib/oppsett.py` | desired setup from `zyxel_nr7302.yml` + `.local.yml`: what 61/62 write and 70 checks |
| `lib/config-verdi.py` | prints one value from yml (used by the shell scripts) |
| `lib/sjekk-oppsett.py` | checks a `zcfg_config.json` against yml (used by 70) |
| `lib/zcfg.py` | Python helpers for `zcfg_config.json`: lookup by name, comparison |
| `lib/pc-nettverkskort.sh` | `admin` / `zycast` / `down` / `status` for the PC's wired interface. Used by 30, 50 and 80 |
| `lib/modem-at.py` | sends AT commands to the modem over USB (`/dev/ttyUSB*`), logs to `logg/`. Used to enable adb |
| `lib/lag-apn-og-fjernstyring-config.py` | creates the config for 62 (locally only) |

## Without a script of its own

| What | How |
|---|---|
| Enable adb (Telenor firmware) | "Enable adb" in the [main README](../README.en.md#enable-adb) |
| Flashing via the web UI (Telenor → Telekom) | [docs/flash-telenor-til-dtag.en.md](../docs/flash-telenor-til-dtag.en.md) |

## Network interface and addresses

The scripts use the first wired interface NetworkManager knows about. Pick another with
`IFACE=`, for example `sudo IFACE=enx00e04c680001 ./30-pc-sett-nettverkskort-mot-zyxel.sh`,
or permanently with `pc.nettverkskort` in `zyxel_nr7302.local.yml`. The addresses
(`pc.admin_adresse`, `pc.enhet_adresse`, `pc.zycast_adresse`) are also taken from there.

## Tests

```bash
python3 -m unittest discover -s tests -v     # the Python scripts and lib/felles.sh (with a fake adb)
shellcheck scripts/*.sh scripts/lib/*.sh
```

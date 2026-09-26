---
kilde: zyxel_nr7302.yml
---
# Configuration file

[🇳🇴 Norsk](konfigurasjon.md) · 🇬🇧 English

`zyxel_nr7302.yml` in the root of the repo describes the desired setup and every setting
found, marked *verifisert* (verified on a device) or *ikke testet* (not tested). The key
names and comments in the file are in Norwegian; this page explains every key in English.

Each key marked **[brukes av skript: …]** ("used by script") is read by those scripts:

| Keys | Used by |
|---|---|
| `pc.*` (interface, addresses) | `12`, `30`, `32`, `50`, `51`, `60`, `70`, `71`, `80` |
| `system`, `lan`, `administrasjon.https/ssh/ssh_passordinnlogging`, `kontoer` | `61` writes, `70` checks |
| `fjernstyring.*`, `administrasjon.wan_admin_i_passthrough` | `62` writes, `70` checks |
| `mobil.apn`, `mobil.apn_profiler` | `62` |
| `passord.admin` | `60` |

`null` means "leave unchanged" and "do not check". For `fjernstyring.tr069_cwmp` and
`tr369_usp_mqtt`, `true` also means "leave unchanged": the scripts never turn operator remote
management back on. Keys marked *[ikke testet]* are documentation only for now.
Arguments and environment variables (`IFACE`, `ENHET`, `ADMIN_ADDR` …) take precedence over
the values in the file.

Personal values go in `zyxel_nr7302.local.yml` next to it, which is layered on top and is
git-ignored:

```yaml
# zyxel_nr7302.local.yml
mobil:
  apn: ice.net
passord:
  admin: "MyOwnPassword"
administrasjon:
  ssh_passordinnlogging: false   # key-only SSH
```

Check a config against the setup (the same check `70-…` runs against the device):

```bash
scripts/lib/sjekk-oppsett.py backup/<time>/zcfg_config.ORIGINAL.json
```

Read a value the way the scripts do:

```bash
scripts/lib/config-verdi.py mobil.apn
```

## Key reference

| Key | Default | Meaning | Device config path | Status |
|---|---|---|---|---|
| `pc.nettverkskort` | `auto` | PC's wired interface towards the antenna; `auto` = first Ethernet interface | – | used |
| `pc.admin_adresse` | `192.168.2.4/24` | PC's address towards the device's LAN (same network as `enhet_adresse`) | – | used |
| `pc.enhet_adresse` | `192.168.2.1` | Device's LAN address. Telenor firmware: 192.168.2.1; Telekom after factory reset: probably 192.168.1.1 | – | used |
| `pc.zycast_adresse` | `192.168.1.4/24` | PC's address when flashing with zycast (the bootloader uses 192.168.1.0/24) | – | used |
| `system.boot_fra_fabrikkoppsett` | `false` | Boot from factory defaults. `true` = all changes are wiped on reboot (Telenor) | `X_ZYXEL_EXT.BootFromFactoryDefault` | verified |
| `lan.dhcp_server` | `true` | DHCP server on the LAN | `DHCPv4.Server.Enable` | verified |
| `administrasjon.https` | `{aktiv: true, modus: LAN_ONLY}` | Web UI on/off and where it is reachable (`LAN_ONLY`, `WAN_ONLY`, `LAN_WAN`) | `X_ZYXEL_RemoteManagement.Service` HTTPS | verified |
| `administrasjon.ssh` | `{aktiv: true, modus: LAN_ONLY}` | SSH (port 22022) on/off and where it is reachable | `X_ZYXEL_RemoteManagement.Service` SSH | verified |
| `administrasjon.ssh_passordinnlogging` | `true` | SSH password login; `false` = keys only | `…Service` SSH `DisableSshPasswordLogin` (inverted) | verified |
| `administrasjon.http/telnet/ftp/ping` | `null` | The other management services | `X_ZYXEL_RemoteManagement.Service` | not tested |
| `administrasjon.wan_admin_i_passthrough` | `false` | Management from WAN in IP passthrough (ports 200xx) | `X_ZYXEL_RemoteManagement_IP_PassThrough.Service` | verified |
| `kontoer.admin.aktiv` | `true` | admin account enabled | `X_ZYXEL_LoginCfg` admin `Enabled` | verified |
| `kontoer.supervisor.aktiv` | `true` | supervisor account enabled (needed for ROM-D backup and cross-flash) | `X_ZYXEL_LoginCfg` supervisor `Enabled` | verified |
| `passord.admin` | `""` | Admin password for `60`; empty = the device's serial number. Set only in `.local.yml` | `X_ZYXEL_LoginCfg` admin `Password` | verified |
| `mobil.apn` | `null` | Your operator's APN, e.g. `ice.net` (Ice) or `telia` (Telia). Set in `.local.yml` or pass to `62` | `Cellular.AccessPoint[n].APN` | verified (`ice.net`) |
| `mobil.apn_profiler` | `[0, 1]` | Which APN profiles get the APN; the Telenor setup uses two | `Cellular.AccessPoint[n]` | verified |
| `mobil.apn_autentisering` | `null` | `None`, `PAP` or `CHAP` | `Cellular.AccessPoint.X_ZYXEL_AuthenticationType` | not tested |
| `mobil.apn_brukernavn` / `apn_passord` | `null` | APN username / password (password only in `.local.yml`) | `Cellular.AccessPoint.Username` / `Password` | not tested |
| `mobil.ip_passthrough` | `null` | `true` = the Ethernet client gets the operator's IP directly | `Cellular.Interface.X_ZYXEL_IP_PassThrough.Enable` | not tested |
| `mobil.foretrukket_teknologi` | `null` | Preferred access technology (default Auto) | `Cellular.Interface.PreferredAccessTechnology` | not tested |
| `mobil.gnss_posisjon` | `null` | `false` = turn off GPS position (privacy) | `Cellular.X_ZYXEL_GNSS_Location.Enable` | not tested |
| `mobil.plmn` | `null` | Operator locked manually, e.g. `24214` (Ice). No config path on Telenor firmware: set in the web UI (Broadband → Cellular PLMN) or with `AT+COPS` | – | not tested |
| `mobil.data_roaming` | `null` | `false` = no national/international roaming (see [performance](ytelse-og-operatorer.en.md)) | `Cellular.RoamingEnabled` | not tested |
| `mobil.tilpassede_innstillinger` | `null` | Telekom firmware: "Enable Customized Settings" (Individual) | – | verified in web UI |
| `fjernstyring.tr069_cwmp` | `false` | `false` = TR-069 off, ACS URL cleared, periodic inform off | `ManagementServer` | verified |
| `fjernstyring.tr369_usp_mqtt` | `false` | `false` = USP controllers, MTPs and MQTT clients off | `LocalAgent`, `MQTT.Client` | verified |
| `fjernstyring.fjern_operator_ssh_nokkel` | `true` | Remove the operator's root SSH key (re-added from factory on boot on Telenor units) | `X_ZYXEL_LoginCfg` `SshKeyBaseAuthPublicKey` | verified |
| `tid.ntp_server` | `null` | NTP server; Telenor uses `ntp.online.no` | `Time.NTPServer1` | not tested |
| `wifi.aktiv` | `null` | The device's built-in 2.4 GHz setup network | `WiFi.Radio` / `WiFi.SSID` `Enable` | not tested |

The defaults are checked by the test suite: applied to the original Telenor config, they
produce exactly the configuration verified on the device.

## The whole file

# Telenor → Telekom (DTAG) firmware on the NR7302

[🇳🇴 Norsk](flash-telenor-til-dtag.md) · 🇬🇧 English

Telenor firmware is only updated while the device is on the Telenor network. With another
operator's SIM you are stuck on the version you have. Telekom (DTAG) publishes its NR7302
firmware as a file, so after switching over you can update manually.

**Done and verified** on one Telenor unit:

| | Before | After |
|---|---|---|
| Firmware | `1.00(ACHA.1)b3_E0` (2023) | `1.00(ACHA.5)b1_F0` (2025) |
| Modem firmware | `RG520FEBDER03A01M8G_OCPU_ZYXEL_BETA_20230614A` | `RG520FEBDER03A01M8G_OCPU_ZYXEL` |

> [!WARNING]
> There is **no way back** to Telenor firmware (it is not available as a file).
> Upstream calls the process "WIP". Read the whole document before you start.

## Pros and cons

| Pros | Cons |
|---|---|
| Can be updated manually from Telekom | No way back to Telenor firmware |
| Newer software and security fixes | USB/adb only available for about 30 s after boot (see below) |
| Newer modem firmware | APN and "Enable Customized Settings" must be set again |
| Telenor's factory setup disappears (if ROM-D is cleared) | eSIM support probably disappears |

Do not expect higher speed by itself. See [ytelse-og-operatorer.en.md](ytelse-og-operatorer.en.md).

## Preparation

1. **Full backup** (phase 4): `scripts/40-zyxel-ta-backup.sh`. Also takes a raw copy of `rom-d` (eID).
2. **Known supervisor password:** `scripts/60-zyxel-sett-admin-passord.sh '<password>' --alle`.
3. **Config backup in the web UI:** Maintenance → Backup/Restore → Backup.
4. **Firmware downloaded and validated:** `scripts/20-pc-last-ned-telekom-firmware.sh`
   (must show `RESULTAT: OK`).
5. **Rescue ready:** `scripts/21-pc-bygg-zycast.sh`, a switch, and a file in `firmware/`.
6. **USB connected** throughout the process.

## The upstream recipe

From [davidohne/Zyxel_NR7302](https://github.com/davidohne/Zyxel_NR7302#cross-flashing):

1. Log in as **supervisor**.
2. Maintenance → Backup/Restore → **ROM-D: Backup** (contains the eID).
3. **Clear ROM-D**.
4. Maintenance → Firmware Upgrade → tick **"Restore Default Settings After Firmware Upgrade"**
   → upload the `.bin` (not Safari).
5. Wait. Do not cut the power while the LEDs are blinking.

## How it went in practice

We uploaded the firmware **without** "Restore Default Settings" and **without** Clear ROM-D.
It worked, but needed a couple of extra steps:

| Time | Observation |
|---|---|
| 0–2 min | Upload. The page goes blank (the web UI stops). Normal. |
| ~2 min | USB disappears. Link on the Ethernet cable is up. |
| ~10 min | **Both LEDs solid green** = flashing done. The device answers ARP, but no services (web, SSH) are up. |
| ~15 min | No progress. **Power pulled for 10 s and plugged back in** (safe once the LEDs have been solid green for a while). |
| +1 min | New firmware running. **Config was kept**: LAN still `192.168.2.1`, passwords and management settings as before. |
| afterwards | **WAN down.** See "After flashing" below. |

## After flashing

1. **LAN address.** With config kept: same as before (Telenor: `192.168.2.1`).
   With "Restore Default Settings" the DTAG default is expected, probably `192.168.1.1` (not verified).
   The PC can have an address in both networks at the same time:
   `sudo ip addr add 192.168.1.4/24 dev <interface>`.
2. **"Enable Customized Settings"** (front page): is in Telekom mode, which uses Telekom's
   predefined setup. Must be switched to use other operators.
   Upstream [issue #4](https://github.com/davidohne/Zyxel_NR7302/issues/4) describes a
   unit that went into a boot loop after this change. It went fine for us, but have the
   zycast rescue ready.
3. **APN.** Broadband → Cellular APN: profile 1 (Cellular WAN 1, default gateway) was set to
   **Auto** with no APN. Set **Manual**, your operator's APN (e.g. `ice.net`), Auth None, IPv4.
4. **SIM PIN** must be entered again after every SIM change.
5. **Remote management.** Check that everything is off (the config from the Telenor firmware was kept):
   - Maintenance → TR-069 Client: CWMP Active off, Inform off, ACS URL empty.
   - TR-369 Local Agent: MQTT clients `false`, Agent MTP `false`, Controller `false`.
     (Telenor's MQTT entries remain, disabled, and can be deleted.)
   - Remote Management → MGMT Services for IP Passthrough: all PT services off.
6. **ROM-D** is still Telenor's if it was not cleared. Only matters for a later factory reset.

### USB/adb with DTAG firmware

USB (and therefore adb) is only available for **about 30 seconds** after boot; after that
the firmware turns USB off completely. The adb setting (`usbcfg`) survived the flash, but
the window is short. Use:

```bash
scripts/33-zyxel-fang-adb-ved-oppstart.sh     # start it, then power-cycle the antenna
```

## Recovery

| Situation | Action |
|---|---|
| Solid green but no services after 10–15 min | Pull the power for 10 s and plug it back in |
| Boot loop, web UI not answering | Hold the reset button while the status LED is solid red (upstream issue #4) |
| Nothing helps | Re-flash with zycast: `sudo scripts/50-pc-sett-nettverkskort-for-zycast.sh` and `sudo scripts/51-zyxel-flash-firmware-via-zycast.sh firmware/<file>.bin`. Telenor units accept packets in a window about 50–85 s after power-on (the script waits 50 s by default; try 55, 60 …) |

## Updating later

Download a new file from Telekom (`scripts/20-…`), validate it (`22-…`) and upload it in
Maintenance → Firmware Upgrade. Without "Restore Default Settings" the settings are kept;
still check APN, PLMN and remote management afterwards.

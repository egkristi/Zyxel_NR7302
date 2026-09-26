#!/usr/bin/env python3
"""Sjekk en zcfg_config.json mot ønsket oppsett i zyxel_nr7302.yml (+ .local.yml).

  ./sjekk-oppsett.py <zcfg_config.json>

Sjekker lokal administrasjon (det 61 skriver) og operatørens fjernstyring (det 62 skriver).
Verdier som er null i yml sjekkes ikke. Avslutter med 1 hvis noe avviker. Brukes av 70.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oppsett  # noqa: E402
import zcfg  # noqa: E402

fail = 0


def chk(label, cond, info=False):
    global fail
    tag = "OK" if cond else ("INFO" if info else "FEIL")
    print(f"  [{tag:<4}] {label}")
    if not cond and not info:
        fail = 1


def main(path):
    d = zcfg.load(path)
    cfg = oppsett.load()
    try:
        lokal = oppsett.lokal_administrasjon(cfg)
        fs = oppsett.fjernstyring(cfg)
    except ValueError as e:
        sys.exit(f"FEIL i zyxel_nr7302(.local).yml: {e}")
    flat = dict(zcfg.flat(d))

    for e in lokal:
        kind = e["objekt"][0]
        try:
            base = {"ext": "X_ZYXEL_EXT", "dhcp": "DHCPv4.Server"}.get(kind) \
                or (zcfg.service_path(d, e["objekt"][1]) if kind == "tjeneste"
                    else zcfg.account_path(d, e["objekt"][1]))
        except KeyError as err:
            chk(f"{e['tekst']}: {err.args[0]}", False)
            continue
        have = flat.get(f"{base}.{e['felt']}")
        chk(f"{e['tekst']}: {oppsett.fmt(e['yml'])}  ({e['nøkkel']})"
            + ("" if have == e["verdi"] else f" – enheten har {e['felt']}={have!r}"), have == e["verdi"])

    if fs["tr069_off"]:
        ms = d.get("ManagementServer", {})
        chk("TR-069/CWMP av, ingen ACS-URL", not ms.get("EnableCWMP") and not ms.get("URL"))
    if fs["usp_mqtt_off"]:
        chk("TR-369/USP-kontroller av", not any(c.get("Enable") for c in d.get("LocalAgent", {}).get("Controller", [])))
        chk("MQTT-klienter av", not any(c.get("Enable") for c in d.get("MQTT", {}).get("Client", [])))
    if fs["wan_admin"] is not None:
        pt = d.get("X_ZYXEL_RemoteManagement_IP_PassThrough", {}).get("Service", [])
        chk(f"WAN-administrasjon i passthrough {'på' if fs['wan_admin'] else 'av'}",
            all(bool(s.get("Enable")) == fs["wan_admin"] for s in pt))
    if any(a.get("SshKeyBaseAuthPublicKey") for g in d["X_ZYXEL_LoginCfg"]["LogGp"] for a in g["Account"]):
        # Legges inn på nytt fra factory ved hver oppstart på Telenor-enheter. Uskadelig så
        # lenge SSH bare er åpen på LAN og WAN-administrasjon er av.
        print("  [INFO] Operatørens SSH-nøkkel for root er lagt inn fra factory")
    apns = [a.get("APN") for a in d.get("Cellular", {}).get("AccessPoint", []) if a.get("Enable")]
    print(f"  [INFO] Aktive APN: {', '.join(apns) or '(ingen)'}")
    return fail


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))

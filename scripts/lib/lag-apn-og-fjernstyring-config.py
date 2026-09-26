#!/usr/bin/env python3
"""Lag config for operatør-fri drift: ny APN og all Telenor-fjernstyring av (kun lokalt).

  ./lag-apn-og-fjernstyring-config.py <inn.json> <ut.json> [--apn ice.net]

Endringer:
  Cellular.AccessPoint[0,1].APN          -> <apn>   (begge APN-profilene; topologi uendret)
  ManagementServer (TR-069/CWMP)         -> EnableCWMP=false, URL="", PeriodicInformEnable=false
  LocalAgent (TR-369/USP)                -> Controller/MTP Enable=false
  MQTT.Client[*]                         -> Enable=false  (Telenor swarm-broker)
  root/supervisor/admin SSH-nøkkel       -> fjernet (Telenors vendor-nøkkel)
  RemoteManagement_IP_PassThrough.Service -> Enable=false (WAN-administrasjon i passthrough)
Skriver en liste over alle endrede verdier.
"""
import argparse
import json


def flat(o, p=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from flat(v, f"{p}.{k}" if p else k)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from flat(v, f"{p}[{i}]")
    else:
        yield p, o


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inn")
    ap.add_argument("ut")
    ap.add_argument("--apn", default="ice.net")
    a = ap.parse_args()

    d = json.load(open(a.inn, encoding="utf-8"))
    before = dict(flat(d))

    for i in (0, 1):
        d["Cellular"]["AccessPoint"][i]["APN"] = a.apn
        d["Cellular"]["AccessPoint"][i]["Enable"] = True

    ms = d["ManagementServer"]
    ms["EnableCWMP"] = False
    ms["URL"] = ""
    ms["PeriodicInformEnable"] = False

    la = d.get("LocalAgent", {})
    for c in la.get("Controller", []):
        c["Enable"] = False
        for m in c.get("MTP", []):
            m["Enable"] = False
    for m in la.get("MTP", []):
        m["Enable"] = False

    for c in d.get("MQTT", {}).get("Client", []):
        c["Enable"] = False

    for g in d["X_ZYXEL_LoginCfg"]["LogGp"]:
        for acc in g["Account"]:
            if acc.get("SshKeyBaseAuthPublicKey"):
                acc["SshKeyBaseAuthPublicKey"] = ""

    for s in d.get("X_ZYXEL_RemoteManagement_IP_PassThrough", {}).get("Service", []):
        s["Enable"] = False

    json.dump(d, open(a.ut, "w", encoding="utf-8"), separators=(",", ":"), ensure_ascii=False)
    after = dict(flat(json.load(open(a.ut, encoding="utf-8"))))
    assert set(before) == set(after), "nøkler endret – avbryter"
    changed = [k for k in before if before[k] != after[k]]
    print(f"{len(changed)} verdier endret:")
    for k in changed:
        b, n = str(before[k]), str(after[k])
        print(f"  {k}: {b[:60]!r} -> {n[:60]!r}")


if __name__ == "__main__":
    main()

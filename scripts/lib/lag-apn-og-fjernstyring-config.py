#!/usr/bin/env python3
"""Lag config for operatør-fri drift: ny APN og all operatør-fjernstyring av (kun lokalt).

  ./lag-apn-og-fjernstyring-config.py <inn.json> <ut.json> --apn <apn> [--profiler 0,1]

Endringer (styres av zyxel_nr7302.yml med .local.yml lagt oppå; null = ikke endre):
  Cellular.AccessPoint[<profiler>].APN    -> <apn>   (Telenor-oppsettet bruker profil 0 og 1)
  fjernstyring.tr069_cwmp: false          -> ManagementServer EnableCWMP=false, URL="", PeriodicInformEnable=false
  fjernstyring.tr369_usp_mqtt: false      -> LocalAgent Controller/MTP og MQTT.Client Enable=false
  fjernstyring.fjern_operator_ssh_nokkel: true -> operatørens SSH-nøkkel fjernet fra kontoene
  administrasjon.wan_admin_i_passthrough  -> RemoteManagement_IP_PassThrough.Service Enable=<verdi>
tr069_cwmp/tr369_usp_mqtt: true betyr «ikke endre» (operatørens fjernstyring slås ikke på igjen).
Skriver en liste over alle endrede verdier.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oppsett  # noqa: E402
import zcfg  # noqa: E402


def profiles(s):
    try:
        return [int(x) for x in s.split(",") if x.strip()]
    except ValueError:
        raise argparse.ArgumentTypeError(f"ugyldig profilliste {s!r} (f.eks. 0,1)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inn")
    ap.add_argument("ut")
    ap.add_argument("--apn", required=True)
    ap.add_argument("--profiler", type=profiles, default=[0, 1])
    a = ap.parse_args()
    if not a.apn.strip():
        sys.exit("FEIL: tom APN")

    try:
        fs = oppsett.fjernstyring(oppsett.load())
    except ValueError as e:
        sys.exit(f"FEIL i zyxel_nr7302(.local).yml: {e}")

    d = zcfg.load(a.inn)
    before = json.loads(json.dumps(d))

    aps = d.get("Cellular", {}).get("AccessPoint", [])
    for i in a.profiler:
        if not 0 <= i < len(aps):
            sys.exit(f"FEIL: APN-profil {i} finnes ikke (enheten har {len(aps)} profiler: 0–{len(aps) - 1})")
        aps[i]["APN"] = a.apn
        aps[i]["Enable"] = True

    if fs["tr069_off"]:
        ms = d.get("ManagementServer", {})
        for k, v in (("EnableCWMP", False), ("URL", ""), ("PeriodicInformEnable", False)):
            if k in ms:
                ms[k] = v

    if fs["usp_mqtt_off"]:
        la = d.get("LocalAgent", {})
        for c in la.get("Controller", []):
            c["Enable"] = False
            for m in c.get("MTP", []):
                m["Enable"] = False
        for m in la.get("MTP", []):
            m["Enable"] = False
        for c in d.get("MQTT", {}).get("Client", []):
            c["Enable"] = False

    if fs["fjern_ssh_nokkel"]:
        for g in d.get("X_ZYXEL_LoginCfg", {}).get("LogGp", []):
            for acc in g["Account"]:
                if acc.get("SshKeyBaseAuthPublicKey"):
                    acc["SshKeyBaseAuthPublicKey"] = ""

    if fs["wan_admin"] is not None:
        for s in d.get("X_ZYXEL_RemoteManagement_IP_PassThrough", {}).get("Service", []):
            s["Enable"] = fs["wan_admin"]

    try:
        changed = zcfg.changes(before, d)
    except ValueError as e:
        sys.exit(f"FEIL: {e} – avbryter")
    with open(a.ut, "w", encoding="utf-8") as f:
        json.dump(d, f, separators=(",", ":"), ensure_ascii=False)
    print(f"{len(changed)} verdier endret:")
    for k, b, n in changed:
        print(f"  {k}: {str(b)[:60]!r} -> {str(n)[:60]!r}")


if __name__ == "__main__":
    main()

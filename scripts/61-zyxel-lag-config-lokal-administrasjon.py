#!/usr/bin/env python3
"""Lag en redigert zcfg_config.json for Telenor-NR7302 (kun lokalt, skriver ikke til enheten).

  ./61-zyxel-lag-config-lokal-administrasjon.py <original.json> <ny.json>

Kirurgisk tekstendring: originalfilen beholdes byte for byte, bare disse verdiene byttes
(stier verifisert mot enhetens egen fil 2026-09-26):
  X_ZYXEL_EXT.BootFromFactoryDefault            true  -> false
  DHCPv4.Server.Enable                          false -> true   (LAN = bridge0, 192.168.2.0/24)
  X_ZYXEL_RemoteManagement.Service HTTPS        WAN_ONLY -> LAN_ONLY
  X_ZYXEL_RemoteManagement.Service SSH          WAN_ONLY -> LAN_ONLY, passordinnlogging på
  X_ZYXEL_LoginCfg supervisor + admin           Enabled false -> true
Etterpå sammenlignes original og ny som JSON: nøyaktig disse 7 verdiene skal differ,
ellers skrives ingen fil.
"""
import json
import sys


def flat(o, p=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from flat(v, f"{p}.{k}" if p else k)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from flat(v, f"{p}[{i}]")
    else:
        yield p, o


def replace_after(text, anchors, old, new, end_marker=None):
    """Finn ankrene i rekkefølge, og bytt første forekomst av `old` etter siste anker
    (før `end_marker`, hvis gitt)."""
    pos = 0
    for a in anchors:
        i = text.find(a, pos)
        if i < 0:
            sys.exit(f"FEIL: fant ikke anker {a!r}")
        pos = i + len(a)
    j = text.find(old, pos)
    if j < 0 or (end_marker and text.find(end_marker, pos) < j):
        sys.exit(f"FEIL: fant ikke {old!r} etter {anchors[-1]!r}")
    return text[:j] + new + text[j + len(old):]


def replace_before(text, anchor, old, new):
    """Bytt nærmeste forekomst av `old` foran `anchor` (felt som står før i samme objekt)."""
    i = text.find(anchor)
    if i < 0 or text.find(anchor, i + 1) >= 0:
        sys.exit(f"FEIL: anker {anchor!r} finnes ikke eller er ikke unikt")
    j = text.rfind(old, 0, i)
    if j < 0 or "{" in text[j:i]:
        sys.exit(f"FEIL: fant ikke {old!r} i samme objekt som {anchor!r}")
    return text[:j] + new + text[j + len(old):]


def main(src, dst):
    orig = open(src, encoding="utf-8").read()
    t = orig
    t = replace_after(t, ['"X_ZYXEL_EXT":{'], '"BootFromFactoryDefault":true', '"BootFromFactoryDefault":false')
    t = replace_after(t, ['"DHCPv4":{', '"Server":{'], '"Enable":false', '"Enable":true', end_marker='"Pool"')
    rm = '"X_ZYXEL_RemoteManagement":{'
    t = replace_after(t, [rm, '"Name":"HTTPS"'], '"Mode":"WAN_ONLY"', '"Mode":"LAN_ONLY"', end_marker="}")
    t = replace_after(t, [rm, '"Name":"SSH"'], '"Mode":"WAN_ONLY"', '"Mode":"LAN_ONLY"', end_marker="}")
    t = replace_after(t, [rm, '"Name":"SSH"'], '"DisableSshPasswordLogin":true',
                      '"DisableSshPasswordLogin":false', end_marker="}")
    t = replace_before(t, '"Username":"supervisor"', '"Enabled":false', '"Enabled":true')
    t = replace_before(t, '"Username":"admin"', '"Enabled":false', '"Enabled":true')

    a, b = dict(flat(json.loads(orig))), dict(flat(json.loads(t)))
    if set(a) != set(b):
        sys.exit("FEIL: nøkler endret – avbryter")
    diff = sorted(k for k in a if a[k] != b[k])
    expected = {
        "X_ZYXEL_EXT.BootFromFactoryDefault", "DHCPv4.Server.Enable",
        "X_ZYXEL_RemoteManagement.Service[1].Mode", "X_ZYXEL_RemoteManagement.Service[4].Mode",
        "X_ZYXEL_RemoteManagement.Service[4].DisableSshPasswordLogin",
        "X_ZYXEL_LoginCfg.LogGp[0].Account[1].Enabled", "X_ZYXEL_LoginCfg.LogGp[1].Account[0].Enabled",
    }
    if set(diff) != expected:
        sys.exit("FEIL: uventede endringer: " + ", ".join(sorted(set(diff) ^ expected)))
    with open(dst, "w", encoding="utf-8") as f:
        f.write(t)
    print("Endringer (verifisert som JSON):")
    for k in diff:
        print(f"  {k}: {json.dumps(a[k])} -> {json.dumps(b[k])}")
    print(f"Skrevet: {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])

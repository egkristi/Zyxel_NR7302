#!/usr/bin/env python3
"""Lag en redigert zcfg_config.json for Telenor-NR7302 (kun lokalt, skriver ikke til enheten).

  ./61-zyxel-lag-config-lokal-administrasjon.py <original.json> <ny.json>

Kirurgisk tekstendring: originalfilen beholdes byte for byte, bare disse verdiene byttes
(verifisert mot enhetens egen fil 2026-09-26):
  X_ZYXEL_EXT.BootFromFactoryDefault            true  -> false
  DHCPv4.Server.Enable                          false -> true   (LAN = bridge0, 192.168.2.0/24)
  X_ZYXEL_RemoteManagement.Service HTTPS        WAN_ONLY -> LAN_ONLY
  X_ZYXEL_RemoteManagement.Service SSH          WAN_ONLY -> LAN_ONLY, passordinnlogging på
  X_ZYXEL_LoginCfg supervisor + admin           Enabled false -> true
Tjenester og kontoer finnes på navn, ikke posisjon. Verdier som allerede er riktige hoppes
over, så skriptet kan kjøres flere ganger. Etterpå sammenlignes original og ny som JSON:
nøyaktig de forventede verdiene skal være endret, ellers skrives ingen fil.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import zcfg  # noqa: E402


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


def js(v):
    return json.dumps(v, separators=(",", ":"))


def main(src, dst):
    orig = open(src, encoding="utf-8").read()
    d = json.loads(orig)
    rm = '"X_ZYXEL_RemoteManagement":{'
    https, ssh = zcfg.service_path(d, "HTTPS"), zcfg.service_path(d, "SSH")

    # (sti, ny verdi, funksjon som gjør tekstendringen)
    edits = [
        ("X_ZYXEL_EXT.BootFromFactoryDefault", False,
         lambda t, o, n: replace_after(t, ['"X_ZYXEL_EXT":{'], o, n)),
        ("DHCPv4.Server.Enable", True,
         lambda t, o, n: replace_after(t, ['"DHCPv4":{', '"Server":{'], o, n, end_marker='"Pool"')),
        (f"{https}.Mode", "LAN_ONLY",
         lambda t, o, n: replace_after(t, [rm, '"Name":"HTTPS"'], o, n, end_marker="}")),
        (f"{ssh}.Mode", "LAN_ONLY",
         lambda t, o, n: replace_after(t, [rm, '"Name":"SSH"'], o, n, end_marker="}")),
        (f"{ssh}.DisableSshPasswordLogin", False,
         lambda t, o, n: replace_after(t, [rm, '"Name":"SSH"'], o, n, end_marker="}")),
    ]
    for user in ("supervisor", "admin"):
        edits.append((f"{zcfg.account_path(d, user)}.Enabled", True,
                      lambda t, o, n, u=user: replace_before(t, f'"Username":"{u}"', o, n)))

    current = dict(zcfg.flat(d))
    t, expected = orig, set()
    for path, new, apply in edits:
        if path not in current:
            sys.exit(f"FEIL: {path} finnes ikke i {src}")
        old = current[path]
        if old == new:
            print(f"  {path}: allerede {js(new)}")
            continue
        key = path.rsplit(".", 1)[1]
        t = apply(t, f'"{key}":{js(old)}', f'"{key}":{js(new)}')
        expected.add(path)

    try:
        diff = zcfg.changes(d, json.loads(t))
    except ValueError as e:
        sys.exit(f"FEIL: {e} – avbryter")
    got = {k for k, _, _ in diff}
    if got != expected:
        sys.exit("FEIL: uventede endringer: " + ", ".join(sorted(got ^ expected)))
    with open(dst, "w", encoding="utf-8") as f:
        f.write(t)
    print("Endringer (verifisert som JSON):" if diff else "Ingen endringer trengs.")
    for k, a, b in diff:
        print(f"  {k}: {js(a)} -> {js(b)}")
    print(f"Skrevet: {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])

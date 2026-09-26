#!/usr/bin/env python3
"""Lag en redigert zcfg_config.json for NR7302 (kun lokalt, skriver ikke til enheten).

  ./61-zyxel-lag-config-lokal-administrasjon.py <original.json> <ny.json>

Verdiene hentes fra zyxel_nr7302.yml med zyxel_nr7302.local.yml lagt oppå (null = ikke endre):
  system.boot_fra_fabrikkoppsett       X_ZYXEL_EXT.BootFromFactoryDefault      (standard false)
  lan.dhcp_server                      DHCPv4.Server.Enable                    (standard true)
  administrasjon.https.aktiv/.modus    RemoteManagement HTTPS Enable/Mode      (standard LAN_ONLY)
  administrasjon.ssh.aktiv/.modus      RemoteManagement SSH Enable/Mode        (standard LAN_ONLY)
  administrasjon.ssh_passordinnlogging SSH DisableSshPasswordLogin (motsatt)   (standard på)
  kontoer.admin/supervisor.aktiv       LoginCfg Enabled                        (standard true)

Kirurgisk tekstendring: originalfilen beholdes byte for byte, bare verdiene over byttes.
Tjenester og kontoer finnes på navn, ikke posisjon. Verdier som allerede er riktige hoppes
over, så skriptet kan kjøres flere ganger. Etterpå sammenlignes original og ny som JSON:
nøyaktig de forventede verdiene skal være endret, ellers skrives ingen fil.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import oppsett  # noqa: E402
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


def edit_for(d, objekt, felt):
    """(sti i configen, funksjon som gjør tekstendringen) for et felt i et objekt."""
    rm = '"X_ZYXEL_RemoteManagement":{'
    kind = objekt[0]
    if kind == "ext":
        return f"X_ZYXEL_EXT.{felt}", lambda t, o, n: replace_after(t, ['"X_ZYXEL_EXT":{'], o, n)
    if kind == "dhcp":
        return (f"DHCPv4.Server.{felt}",
                lambda t, o, n: replace_after(t, ['"DHCPv4":{', '"Server":{'], o, n, end_marker='"Pool"'))
    if kind == "tjeneste":
        navn = objekt[1]
        return (f"{zcfg.service_path(d, navn)}.{felt}",
                lambda t, o, n: replace_after(t, [rm, f'"Name":"{navn}"'], o, n, end_marker="}"))
    if kind == "konto":
        bruker = objekt[1]
        return (f"{zcfg.account_path(d, bruker)}.{felt}",
                lambda t, o, n: replace_before(t, f'"Username":"{bruker}"', o, n))
    raise ValueError(objekt)


def main(src, dst):
    orig = open(src, encoding="utf-8").read()
    d = json.loads(orig)
    try:
        ønsket = oppsett.lokal_administrasjon(oppsett.load())
    except ValueError as e:
        sys.exit(f"FEIL i zyxel_nr7302(.local).yml: {e}")

    current = dict(zcfg.flat(d))
    t, expected = orig, set()
    for e in ønsket:
        new = e["verdi"]
        try:
            path, apply = edit_for(d, e["objekt"], e["felt"])
        except KeyError as err:
            sys.exit(f"FEIL: {err.args[0]}")
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

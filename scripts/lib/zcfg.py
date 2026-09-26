"""Felles hjelpefunksjoner for zcfg_config.json (NR7302-config). Importeres av skriptene.

Oppslag skjer på navn (tjenestenavn, brukernavn), ikke på posisjon, fordi rekkefølgen i
listene kan variere mellom firmwareversjoner.
"""
import json


def flat(o, p=""):
    """Gi (sti, verdi) for alle blader, f.eks. ("DHCPv4.Server.Enable", True)."""
    if isinstance(o, dict):
        for k, v in o.items():
            yield from flat(v, f"{p}.{k}" if p else k)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from flat(v, f"{p}[{i}]")
    else:
        yield p, o


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def service_path(d, name, group="X_ZYXEL_RemoteManagement"):
    """Sti til tjenesten med Name == name, f.eks. "X_ZYXEL_RemoteManagement.Service[4]"."""
    for i, s in enumerate(d[group]["Service"]):
        if s.get("Name") == name:
            return f"{group}.Service[{i}]"
    raise KeyError(f"fant ikke tjenesten {name!r} i {group}")


def account_path(d, username):
    """Sti til kontoen med Username == username, f.eks. "X_ZYXEL_LoginCfg.LogGp[1].Account[0]"."""
    for g, gp in enumerate(d["X_ZYXEL_LoginCfg"]["LogGp"]):
        for a, acc in enumerate(gp["Account"]):
            if acc.get("Username") == username:
                return f"X_ZYXEL_LoginCfg.LogGp[{g}].Account[{a}]"
    raise KeyError(f"fant ikke kontoen {username!r}")


def changes(before, after):
    """Liste over (sti, før, etter) for verdier som er endret. Feiler hvis nøkler er endret."""
    a, b = dict(flat(before)), dict(flat(after))
    if set(a) != set(b):
        raise ValueError("nøkler er lagt til eller fjernet")
    return [(k, a[k], b[k]) for k in a if a[k] != b[k]]

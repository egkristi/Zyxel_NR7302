"""Ønsket oppsett fra zyxel_nr7302.yml, med zyxel_nr7302.local.yml lagt oppå.

Brukes av 61 (lokal administrasjon), lib/lag-apn-og-fjernstyring-config.py (62) og 70
(verifisering), så det som skrives og det som sjekkes kommer fra samme sted. null eller
manglende verdi betyr «ikke endre / ikke sjekk».

Mappen med yml-filene er repoets rot, eller ZYXEL_NR7302_KONFIG_DIR hvis den er satt.
"""
import os

import yaml

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODUS = ("LAN_ONLY", "WAN_ONLY", "LAN_WAN")


def merge(a, b):
    """Legg b oppå a (rekursivt for dict)."""
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = merge(a.get(k), v) if k in a else v
        return out
    return b


def load(base=None):
    base = base or os.environ.get("ZYXEL_NR7302_KONFIG_DIR") or BASE
    cfg = {}
    for name in ("zyxel_nr7302.yml", "zyxel_nr7302.local.yml"):
        path = os.path.join(base, name)
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                cfg = merge(cfg, yaml.safe_load(f) or {})
    return cfg


def get(cfg, key):
    node = cfg
    for part in key.split("."):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    return node


def fmt(v):
    if v is None:
        return ""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, list):
        return ",".join(fmt(x) for x in v)
    return str(v)


def _bool(cfg, key):
    v = get(cfg, key)
    if v is not None and not isinstance(v, bool):
        raise ValueError(f"{key} må være true, false eller null (er {v!r})")
    return v


def _modus(cfg, key):
    v = get(cfg, key)
    if v is not None and v not in MODUS:
        raise ValueError(f"{key} må være {', '.join(MODUS)} eller null (er {v!r})")
    return v


def lokal_administrasjon(cfg):
    """Innstillingene 61 skriver og 70 sjekker, som liste av dict:
    nøkkel (i yml), yml (verdien der), tekst, objekt, felt, verdi (i configen). objekt er ("ext",), ("dhcp",),
    ("tjeneste", navn) eller ("konto", brukernavn). Bare verdier som ikke er null tas med."""
    ut = []

    def add(key, tekst, objekt, felt, verdi):
        if verdi is not None:
            ut.append(dict(nøkkel=key, yml=get(cfg, key), tekst=tekst, objekt=objekt, felt=felt, verdi=verdi))

    k = "system.boot_fra_fabrikkoppsett"
    add(k, "Boot fra fabrikkoppsett", ("ext",), "BootFromFactoryDefault", _bool(cfg, k))
    k = "lan.dhcp_server"
    add(k, "DHCP-server på LAN", ("dhcp",), "Enable", _bool(cfg, k))
    for navn, tjeneste in (("https", "HTTPS"), ("ssh", "SSH")):
        k = f"administrasjon.{navn}"
        add(f"{k}.aktiv", f"{tjeneste} aktiv", ("tjeneste", tjeneste), "Enable", _bool(cfg, f"{k}.aktiv"))
        add(f"{k}.modus", f"{tjeneste} modus", ("tjeneste", tjeneste), "Mode", _modus(cfg, f"{k}.modus"))
    k = "administrasjon.ssh_passordinnlogging"
    v = _bool(cfg, k)
    add(k, "SSH passordinnlogging", ("tjeneste", "SSH"), "DisableSshPasswordLogin", None if v is None else not v)
    for bruker in ("admin", "supervisor"):
        k = f"kontoer.{bruker}.aktiv"
        add(k, f"{bruker}-konto aktiv", ("konto", bruker), "Enabled", _bool(cfg, k))
    return ut


def fjernstyring(cfg):
    """Hva 62 skal gjøre med operatørens fjernstyring. None = ikke endre.
      tr069_off / usp_mqtt_off / fjern_ssh_nokkel: True = slå av / fjern
      wan_admin: True/False = WAN-administrasjon i passthrough på/av"""
    tr069 = _bool(cfg, "fjernstyring.tr069_cwmp")
    usp = _bool(cfg, "fjernstyring.tr369_usp_mqtt")
    return dict(
        tr069_off=True if tr069 is False else None,
        usp_mqtt_off=True if usp is False else None,
        fjern_ssh_nokkel=True if _bool(cfg, "fjernstyring.fjern_operator_ssh_nokkel") else None,
        wan_admin=_bool(cfg, "administrasjon.wan_admin_i_passthrough"),
    )

#!/usr/bin/env python3
"""Skriv ut én verdi fra zyxel_nr7302.yml, med zyxel_nr7302.local.yml lagt oppå.

  ./config-verdi.py mobil.apn              -> ice.net
  ./config-verdi.py mobil.apn_profiler     -> 0,1

null eller manglende nøkkel gir tom utskrift. Lister skrives kommaseparert, bool som
true/false. Brukes av lib/felles.sh (config_verdi).
"""
import os
import sys

import yaml

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def merge(a, b):
    """Legg b oppå a (rekursivt for dict)."""
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = merge(a.get(k), v) if k in a else v
        return out
    return b


def load(base=BASE):
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


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(fmt(get(load(), sys.argv[1])))

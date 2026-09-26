#!/usr/bin/env python3
"""Vis feltene i zcfg_config.json som er relevante for Telenor-opplåsingen. Endrer ingenting.

  ./41-zyxel-vis-config.py ../backup/<dato>/zcfg_config.ORIGINAL.json

Skriver JSON-sti og verdi, slik at vi kan lage nøyaktige endringer mot din faktiske fil
(strukturen varierer mellom firmwareversjoner, så vi gjetter ikke på stier).
"""
import json
import re
import sys

KEY_PAT = re.compile(
    r"^(BootFromFactoryDefault|EnableCWMP|URL|PeriodicInformEnable|"
    r"DisableSshPasswordLogin|Mode|Username|Enabled?|Password|DefaultPassword|APN|"
    r"X_ZYXEL_.*Customiz.*)$", re.I)
PATH_PAT = re.compile(r"DHCPv4\.Server|RemoteMgmt|RemoteManagement|Service|LoginCfg|"
                      r"ManagementServer|Cellular|APN|BootFromFactoryDefault|Customiz", re.I)


def walk(node, path):
    if isinstance(node, dict):
        # Tjenesteoppføringer (HTTPS/SSH/...) vises samlet
        if "Name" in node and "Mode" in node:
            keep = {k: node[k] for k in ("Name", "Enable", "Port", "Mode", "DisableSshPasswordLogin") if k in node}
            print(f"{path}: {json.dumps(keep, ensure_ascii=False)}")
            return
        for k, v in node.items():
            walk(v, f"{path}.{k}" if path else k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, f"{path}[{i}]")
    else:
        key = path.rsplit(".", 1)[-1]
        if KEY_PAT.match(key) and PATH_PAT.search(path):
            val = node
            if isinstance(val, str) and val.startswith("_encrypt_"):
                val = "_encrypt_… (kryptert)"
            print(f"{path} = {json.dumps(val, ensure_ascii=False)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as f:
        walk(json.load(f), "")

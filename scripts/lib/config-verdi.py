#!/usr/bin/env python3
"""Skriv ut én verdi fra zyxel_nr7302.yml, med zyxel_nr7302.local.yml lagt oppå.

  ./config-verdi.py mobil.apn              -> ice.net
  ./config-verdi.py mobil.apn_profiler     -> 0,1

null eller manglende nøkkel gir tom utskrift. Lister skrives kommaseparert, bool som
true/false. Brukes av lib/felles.sh (config_verdi).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from oppsett import fmt, get, load  # noqa: E402,F401

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(fmt(get(load(), sys.argv[1])))

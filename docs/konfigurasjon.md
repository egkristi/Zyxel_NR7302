---
kilde: zyxel_nr7302.yml
---
# Konfigurasjonsfil

`zyxel_nr7302.yml` i roten av repoet beskriver ønsket oppsett og alle innstillingene som er
funnet, merket *verifisert* eller *ikke testet*.

Hver nøkkel merket **[brukes av skript: …]** leses av de skriptene:

| Nøkler | Brukes av |
|---|---|
| `pc.*` (nettverkskort, adresser) | `12`, `30`, `32`, `50`, `51`, `60`, `70`, `71`, `80` |
| `system`, `lan`, `administrasjon.https/ssh/ssh_passordinnlogging`, `kontoer` | `61` skriver, `70` sjekker |
| `fjernstyring.*`, `administrasjon.wan_admin_i_passthrough` | `62` skriver, `70` sjekker |
| `mobil.apn`, `mobil.apn_profiler` | `62` |
| `passord.admin` | `60` |

`null` betyr «ikke endre» og «ikke sjekk». For `fjernstyring.tr069_cwmp` og
`tr369_usp_mqtt` betyr også `true` «ikke endre»: skriptene slår aldri operatørens
fjernstyring på igjen. Nøkler merket *[ikke testet]* er foreløpig bare dokumentasjon.
Argumenter og miljøvariabler (`IFACE`, `ENHET`, `ADMIN_ADDR` …) går foran verdiene i filen.

Personlige verdier legges i `zyxel_nr7302.local.yml` ved siden av, som legges oppå og er
git-ignorert:

```yaml
# zyxel_nr7302.local.yml
mobil:
  apn: ice.net
passord:
  admin: "MittEgetPassord"
administrasjon:
  ssh_passordinnlogging: false   # bare nøkkel
```

Sjekk en config mot oppsettet (samme sjekk som `70-…` gjør mot enheten):

```bash
scripts/lib/sjekk-oppsett.py backup/<tid>/zcfg_config.ORIGINAL.json
```

Les en verdi slik skriptene gjør:

```bash
scripts/lib/config-verdi.py mobil.apn
```

## Hele filen

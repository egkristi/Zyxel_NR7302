---
kilde: zyxel_nr7302.yml
---
# Konfigurasjonsfil

`zyxel_nr7302.yml` i roten av repoet beskriver ønsket oppsett og alle innstillingene som er
funnet, merket *verifisert* eller *ikke testet*.

Verdiene merket **[brukes av skript]** leses av skriptene: nettverkskortet og adressene på
PC-siden, APN og APN-profiler (`62-…`) og admin-passordet (`60-…`). Argumenter og
miljøvariabler (`IFACE`, `ENHET`, `ADMIN_ADDR` …) går foran verdiene i filen.

Personlige verdier legges i `zyxel_nr7302.local.yml` ved siden av, som legges oppå og er
git-ignorert:

```yaml
# zyxel_nr7302.local.yml
mobil:
  apn: ice.net
passord:
  admin: "MittEgetPassord"
```

Les en verdi slik skriptene gjør:

```bash
scripts/lib/config-verdi.py mobil.apn
```

## Hele filen

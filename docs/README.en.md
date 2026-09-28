# Documentation

[🇳🇴 Norsk](README.md) · 🇬🇧 English

| Document | Contents |
|---|---|
| [flash-telenor-til-dtag.en.md](flash-telenor-til-dtag.en.md) | Switching from Telenor to Telekom (DTAG) firmware: preparation, practice, follow-up, rescue |
| [ytelse-og-operatorer.en.md](ytelse-og-operatorer.en.md) | Speed and ping, measuring correctly, subscription limits, bufferbloat, operator locking |
| [konfigurasjon.en.md](konfigurasjon.en.md) | `zyxel_nr7302.yml` and `.local.yml`: every key, and which values the scripts read |

Every document also exists in Norwegian (`*.md` without `.en`).

Published as a website: <https://egkristi.github.io/Zyxel_NR7302/en/> (built from this folder
and the README files with MkDocs, see `mkdocs.yml`). `index`, `veiledning`, `tekniske-funn`,
`om`, `skript` and `konfigurasjon` (`.md` and `.en.md`) take their text from the README files
and the yml file through markers such as `<!-- kilde: The phases | innhold -->` (see
`.mkdocs/hooks.py`), so edit the text there.

Overview of the phases and all scripts: [main README](../README.en.md) and [scripts/README.en.md](../scripts/README.en.md).

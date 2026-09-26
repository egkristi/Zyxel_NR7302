# backup/

[🇳🇴 Norsk](README.md) · 🇬🇧 English

`scripts/40-zyxel-ta-backup.sh` and the phase 6 scripts put backups from the device here, one
folder per run. The folders are created so that only you can read them (`700`).

**The contents are personal and never go into git** (see `.gitignore`): raw flash dumps with
eID/ROM-D, factory data, certificates and keys, and configuration files with encrypted passwords.

Copy the whole folder somewhere else (USB stick, cloud) after the first backup.
Without it you cannot go back if something goes wrong.

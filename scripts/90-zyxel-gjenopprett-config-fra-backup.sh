#!/usr/bin/env bash
# Skriver en tidligere config-backup tilbake til enheten over adb og starter på nytt.
#   ./90-zyxel-gjenopprett-config-fra-backup.sh <sti-til-zcfg_config.json>
set -euo pipefail
F="${1:-}"
[[ -f "$F" ]] || { echo "Bruk: $0 <backup zcfg_config.json>" >&2; exit 1; }
python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$F" || { echo "Ugyldig JSON – avbryter." >&2; exit 1; }
adb wait-for-device
adb push "$F" /tmp/zcfg_restore.json >/dev/null
adb shell 'cat /tmp/zcfg_restore.json > /xdata/zcfg_config.json && sync; reboot' >/dev/null || true
echo "Gjenopprettet fra $F. Enheten starter på nytt."

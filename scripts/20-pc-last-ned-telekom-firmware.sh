#!/usr/bin/env bash
# Fase 2: Henter NR7302-firmware og dokumentasjon fra Telekom (DTAG), pakker ut .bin til
# firmware/ og validerer den med 22-pc-sjekk-firmwarefil.py.
#
#   ./20-pc-last-ned-telekom-firmware.sh              prøv nedlasting, ellers nettleser
#   ./20-pc-last-ned-telekom-firmware.sh --fra <zip>  bruk en ZIP du allerede har lastet ned
#
# telekom.de stopper ofte nedlasting fra skript (HTTP 202 uten innhold). Da åpnes lenkene i
# nettleseren din, og skriptet venter på filen i Nedlastinger-mappen.
# Kjør som vanlig bruker (ikke sudo).
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$BASE/firmware/telekom"
PAGE="https://www.telekom.de/hilfe/geraete/router/weitere/zyxel"
DL="https://www.telekom.de/hilfe/downloads"
FW="firmware-5g-outdoor-router-nr7302"
DOCS=(firmware-aenderungen-5g-outdoor-router-nr7302
      schnellstartanleitung-5g-outdoor-router-nr7302
      bedienungsanleitung-5g-outdoor-router-nr7302-nr7303-englisch)
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"
mkdir -p "$DEST"

[[ $EUID -eq 0 ]] && { echo "Kjør som vanlig bruker, ikke med sudo." >&2; exit 1; }

zip_ok() { [[ -s "$1" ]] && unzip -tq "$1" >/dev/null 2>&1; }

fetch() {  # fetch <navn> <utfil>  -> 0 hvis en ekte fil kom ned
  curl -fsSL -A "$UA" --max-time 300 -o "$2.part" "$DL/$1" 2>/dev/null || true
  if [[ -s "$2.part" ]] && ! file "$2.part" | grep -qi 'html'; then mv "$2.part" "$2"; return 0; fi
  rm -f "$2.part"; return 1
}

ZIP=""
if [[ "${1:-}" == "--fra" ]]; then
  ZIP="${2:?Bruk: --fra <sti-til-zip>}"
else
  echo "== Prøver direkte nedlasting fra telekom.de"
  if fetch "$FW" "$DEST/$FW.zip" && zip_ok "$DEST/$FW.zip"; then
    ZIP="$DEST/$FW.zip"
    for d in "${DOCS[@]}"; do fetch "$d" "$DEST/$d.pdf" && echo "  hentet $d.pdf" || true; done
  else
    DLDIR="$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")"
    echo "   telekom.de stoppet nedlastingen (bot-beskyttelse)."
    echo "== Åpner lenkene i nettleseren. Lagre filene i: $DLDIR"
    START=$(date +%s)
    xdg-open "$DL/$FW" >/dev/null 2>&1 || echo "   Åpne selv: $DL/$FW"
    for d in "${DOCS[@]}"; do xdg-open "$DL/$d" >/dev/null 2>&1 || true; sleep 1; done
    echo "   (Oversiktsside: $PAGE)"
    echo "== Venter på $FW*.zip i $DLDIR (maks 10 min, Ctrl+C for å avbryte)"
    for _ in $(seq 1 300); do
      c=$(find "$DLDIR" -maxdepth 1 -name "$FW*.zip" -newermt "@$START" 2>/dev/null | head -1)
      if [[ -n "$c" ]] && zip_ok "$c"; then ZIP="$c"; break; fi
      sleep 2
    done
    [[ -n "$ZIP" ]] || { echo "Fant ingen komplett ZIP. Kjør på nytt med --fra <zip>." >&2; exit 1; }
    cp -n "$ZIP" "$DEST/" || true
    for d in "${DOCS[@]}"; do
      f=$(find "$DLDIR" -maxdepth 1 -name "$d*.pdf" -newermt "@$START" 2>/dev/null | head -1)
      [[ -n "$f" ]] && cp -n "$f" "$DEST/" && echo "  kopierte $(basename "$f")"
    done
  fi
fi

zip_ok "$ZIP" || { echo "Ugyldig eller ufullstendig ZIP: $ZIP" >&2; exit 1; }
echo "== Innhold i $(basename "$ZIP")"
unzip -l "$ZIP" | sed -n '4,$p' | grep -v -- '----' | head -10
echo "== Pakker ut .bin til firmware/"
unzip -o -j -q "$ZIP" '*.bin' -d "$BASE/firmware/"
echo "== Validerer"
"$BASE/scripts/22-pc-sjekk-firmwarefil.py" "$BASE"/firmware/*.bin

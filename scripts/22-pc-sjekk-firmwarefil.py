#!/usr/bin/env python3
"""Sjekk at en NR7302-firmwarefil (.bin) er hel og ser riktig ut før flashing.

  ./22-pc-sjekk-firmwarefil.py ../firmware/*.bin

Kontrollerer (samme logikk som repoets rebuild_firmware.sh):
  - at filen er en gyldig ZIP og at ZIP-CRC for alle filer stemmer
  - at de forventede partisjonsfilene finnes
  - at MD5-summene i fotaconfig.xml stemmer med innholdet
  - HDR1-header i .img/.bin-filer: magic, modell-ID 0x7302 og CRC-er
"""
import binascii
import hashlib
import struct
import sys
import zipfile
from xml.etree import ElementTree as ET

EXPECTED = ["oemapp.ubi", "sdxlemur-sysfs.ubi", "sdxlemur-boot.img",
            "NON-HLOS.ubi", "multifota.bin", "fotaconfig.xml"]
MODEL_ID = 0x7302


def crc_ok(data, stored):
    c = binascii.crc32(data) & 0xFFFFFFFF
    return stored in (c, c ^ 0xFFFFFFFF)


def check_hdr1(name, data):
    errs = []
    if len(data) < 0x17C or struct.unpack_from("<I", data, 0)[0] != 0x31524448:
        print(f"    {name}: ingen HDR1-header (ok for denne filtypen)")
        return errs
    b = data[0x11C:0x120]
    model = (b[0] << 12) | (b[1] << 8) | (b[2] << 4) | b[3]
    print(f"    {name}: HDR1, modell-ID 0x{model:X}")
    if model != MODEL_ID:
        errs.append(f"{name}: modell-ID 0x{model:X} er ikke 0x{MODEL_ID:X} (NR7302)")
    hdr = bytearray(data[:0x17C])
    stored_hdr = struct.unpack_from("<I", hdr, 0x174)[0]
    hdr[0x174:0x178] = b"\0" * 4
    stored_img = struct.unpack_from("<I", data, 0x0C)[0]
    if not crc_ok(bytes(hdr), stored_hdr):
        errs.append(f"{name}: header-CRC stemmer ikke (normalt bare for modifisert firmware)")
    if not crc_ok(data[0x17C:], stored_img):
        errs.append(f"{name}: image-CRC stemmer ikke (normalt bare for modifisert firmware)")
    return errs


def check(path):
    print(f"== {path}")
    if not zipfile.is_zipfile(path):
        print("  FEIL: ikke en ZIP-fil. NR7302-firmware er en ZIP med .bin-endelse.")
        return False
    errs = []
    with zipfile.ZipFile(path) as z:
        bad = z.testzip()
        if bad:
            errs.append(f"ZIP-CRC feil i {bad} (ødelagt nedlasting)")
        names = z.namelist()
        print("  Innhold: " + ", ".join(names))
        errs += [f"mangler {n}" for n in EXPECTED if n not in names]
        if "fotaconfig.xml" in names:
            root = ET.fromstring(z.read("fotaconfig.xml"))
            for p in root.findall("partition"):
                img, md5 = p.findtext("image"), p.findtext("newmd5")
                if img and md5 and img in names:
                    ok = hashlib.md5(z.read(img)).hexdigest() == md5.strip().lower()
                    print(f"    MD5 {img}: {'ok' if ok else 'FEIL'}")
                    if not ok:
                        errs.append(f"MD5 for {img} stemmer ikke med fotaconfig.xml")
            ver = [e.text for e in root.iter() if e.tag.lower() in ("version", "fwversion", "swversion") and e.text]
            if ver:
                print(f"  Versjon i fotaconfig.xml: {', '.join(ver)}")
        for n in names:
            if n.endswith((".img", ".bin")):
                errs += check_hdr1(n, z.read(n))
    with open(path, "rb") as f:
        print(f"  sha256: {hashlib.sha256(f.read()).hexdigest()}")
    for e in errs:
        print(f"  FEIL: {e}")
    print("  RESULTAT: " + ("OK" if not errs else "IKKE OK – ikke flash denne"))
    return not errs


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    results = [check(p) for p in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)
